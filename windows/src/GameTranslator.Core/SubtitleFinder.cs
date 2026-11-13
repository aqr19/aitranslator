// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core;

/// <summary>
/// Altyazıyı ekranın tamamından, kullanıcı alan seçmeden bulur. Yazının yerine değil davranışına bakar: altyazı
/// ortalıdır, cümle gibidir, birkaç saniyede bir değişir ve hep aynı şeritte çıkar; arayüz yazısı (görev hedefi,
/// gösterge) uzun süre aynı yerde aynı kalır, menü kısa ve noktalamasız satırlardır, kumanda ipucu düğme adı taşır.
/// İlk birkaç altyazıdan oyunun altyazı şeridi öğrenilir; sonra şerit dışındaki cümleler (ekran ortasındaki eğitim
/// ipucu, bildirim) altyazı sayılmaz. Şerit uzun süre boş kalır ve başka yerde altyazıya benzer satırlar birikirse
/// yeniden öğrenilir (oyun ya da sahne değişti).
/// Kutular karenin tamamına oranladır (0–1). Durum tutar; tek iş parçacığından çağrılır.
/// </summary>
public sealed class SubtitleFinder
{
    public enum Verdict { Subtitle, Prompt, Menu, Static, OffCenter, NotSentence, OutsideBand }

    public sealed record Finding(TextLine Line, Verdict Verdict);

    /// <summary>Öğrenilen altyazı şeridi (karenin yüksekliğine oranla); henüz öğrenilmediyse null.</summary>
    public (double Top, double Bottom)? Band { get; private set; }

    /// <summary>Şeridi öğrenmek için gereken farklı altyazı sayısı.</summary>
    public const int LinesToLearn = 3;
    /// <summary>Aynı yerde aynı yazı bu kadar süre kalırsa arayüzdür.</summary>
    public const int StaticAfterMs = 9000;
    /// <summary>Şerit bu kadar süre boşken başka yerde altyazıya benzer satırlar birikirse şerit yeniden öğrenilir.</summary>
    public const int RelearnAfterMs = 10000;
    /// <summary>Satırın ortası ekranın ortasından en çok bu kadar uzak olabilir.</summary>
    public const double CenterTolerance = 0.12;

    private sealed record Seen(long First, long Last);

    private readonly Dictionary<string, Seen> seen = [];
    private readonly List<(double Middle, double Height, string Text)> votes = [];
    private readonly List<(double Middle, double Height, string Text, long At)> strays = [];
    private long lastInBand;

    /// <summary>Karenin tamamının okumasını sınıflar. <paramref name="now"/> milisaniyedir (tekdüze artan saat).</summary>
    public IReadOnlyList<Finding> Classify(Reading reading, long now)
    {
        Forget(now);
        var menu = MenuLines(reading);
        var findings = new List<Finding>();
        foreach (var line in reading.Lines)
        {
            if (line.Box is not { } box || line.Text.Trim().Length == 0) continue;
            var key = Key(line.Text, box);
            var first = seen.TryGetValue(key, out var earlier) ? earlier.First : now;
            seen[key] = new Seen(first, now);

            Verdict verdict;
            if (ButtonPrompts.IsPrompt(line.Text)) verdict = Verdict.Prompt;
            else if (menu.Contains(line)) verdict = Verdict.Menu;
            else if (now - first >= StaticAfterMs) verdict = Verdict.Static;
            else if (Math.Abs(((box.Left + box.Right) / 2) - 0.5) > CenterTolerance) verdict = Verdict.OffCenter;
            else if (!LooksSpoken(line.Text)) verdict = Verdict.NotSentence;
            else verdict = InBand(box) ? Verdict.Subtitle : Verdict.OutsideBand;

            // Şeridi yalnız açıkça konuşma olan satırlar belirler; "Spider Barrage" gibi kısa yazılar belirlemez.
            if (verdict == Verdict.Subtitle)
            {
                lastInBand = now;
                if (IsClearlySpoken(line.Text)) Vote(line.Text, box, now);
            }
            else if (verdict == Verdict.OutsideBand && IsClearlySpoken(line.Text)) Stray(line.Text, box, now);
            findings.Add(new Finding(line, verdict));
        }
        return findings;
    }

    /// <summary>Altyazı sayılan satırlar, yukarıdan aşağı.</summary>
    public Reading Subtitles(Reading reading, long now) =>
        new(Classify(reading, now).Where(f => f.Verdict == Verdict.Subtitle).Select(f => f.Line));

    private bool InBand(TextBox box)
    {
        if (Band is not { } band) return true;
        var middle = (box.Top + box.Bottom) / 2;
        return middle >= band.Top && middle <= band.Bottom;
    }

    /// <summary>Şerit öğrenilene kadar oylar birikir; öğrenildikten sonra şeritteki satırlar şeridi ince ayarlar.</summary>
    private void Vote(string text, TextBox box, long now)
    {
        var normal = TextMatch.Normalize(text);
        if (votes.Any(vote => vote.Text == normal)) return;
        votes.Add(((box.Top + box.Bottom) / 2, box.Bottom - box.Top, normal));
        if (votes.Count > 12) votes.RemoveAt(0);
        if (votes.Count >= LinesToLearn) Band = BandOf(votes.Select(vote => (vote.Middle, vote.Height)).ToList());
    }

    /// <summary>Şerit dışındaki altyazıya benzer satırlar: şerit uzun süredir boşsa ve bunlar bir yerde toplanıyorsa yeni şerittir.</summary>
    private void Stray(string text, TextBox box, long now)
    {
        var normal = TextMatch.Normalize(text);
        if (strays.Any(stray => stray.Text == normal)) return;
        strays.Add(((box.Top + box.Bottom) / 2, box.Bottom - box.Top, normal, now));
        strays.RemoveAll(stray => now - stray.At > RelearnAfterMs * 2);
        if (now - lastInBand < RelearnAfterMs || strays.Count < LinesToLearn) return;
        var candidate = BandOf(strays.Select(stray => (stray.Middle, stray.Height)).ToList());
        if (strays.Count(stray => stray.Middle >= candidate.Top && stray.Middle <= candidate.Bottom) < LinesToLearn) return;
        Band = candidate;
        votes.Clear();
        votes.AddRange(strays.Select(stray => (stray.Middle, stray.Height, stray.Text)));
        strays.Clear();
        lastInBand = now;
    }

    /// <summary>
    /// Satır ortalarının ortancası çevresinde şerit: iki satırlı altyazı ve küçük kaymalar için yukarı ve aşağı
    /// iki buçuk satır yüksekliği pay bırakılır. Aykırı tek satır (ortancadan uzak) şeridi genişletmez.
    /// </summary>
    private static (double Top, double Bottom) BandOf(List<(double Middle, double Height)> lines)
    {
        var middle = Median(lines.Select(line => line.Middle));
        var height = Math.Max(0.015, Median(lines.Select(line => line.Height)));
        return (Math.Max(0, middle - (height * 2.5)), Math.Min(1, middle + (height * 2.5)));
    }

    private static double Median(IEnumerable<double> values)
    {
        var sorted = values.Order().ToList();
        return sorted.Count % 2 == 1 ? sorted[sorted.Count / 2] : (sorted[(sorted.Count / 2) - 1] + sorted[sorted.Count / 2]) / 2;
    }

    /// <summary>
    /// Konuşma satırı gibi mi: en az iki sözcük ya da noktalamayla biten tek sözcük ("Run!"), harflerinin çoğu küçük
    /// harf ya da cümle sonu işaretiyle biter (tümü büyük harfli kısa yazılar çoğunlukla başlık ve göstergedir).
    /// </summary>
    internal static bool LooksSpoken(string text)
    {
        var words = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Where(word => word.Any(char.IsLetter)).ToList();
        if (words.Count == 0) return false;
        var ends = SubtitleStabilizer.EndsSentence(text);
        if (words.Count <= 2 && !ends) return false;
        var letters = text.Where(char.IsLetter).ToList();
        if (letters.Count < 3) return false;
        var lower = letters.Count(char.IsLower);
        return lower * 2 >= letters.Count || (ends && words.Count >= 2);
    }

    /// <summary>
    /// Şeridi öğretecek kadar açık konuşma: en az üç sözcük ve ya cümle sonu işaretiyle biter ya da "Ad:" ile başlar.
    /// Dövüş sırasında ekranın ortasında çıkan beceri adları ve ipuçları şeridi yanlış yere çekiyordu.
    /// </summary>
    internal static bool IsClearlySpoken(string text)
    {
        var words = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Count(word => word.Any(char.IsLetter));
        if (words < 3 || !LooksSpoken(text)) return false;
        var colon = text.IndexOf(':');
        var labelled = colon is > 1 and <= 30 && char.IsUpper(text[0]) && colon < text.Length - 2;
        return labelled || SubtitleStabilizer.EndsSentence(text);
    }

    /// <summary>Alt alta dizilmiş, sola hizalı ya da aynı ortalı, kısa ve noktalamasız üç ve daha çok satır menüdür.</summary>
    private static HashSet<TextLine> MenuLines(Reading reading)
    {
        var result = new HashSet<TextLine>();
        var shorts = reading.Lines
            .Where(line => line.Box is not null && WordCount(line.Text) <= 3 && !SubtitleStabilizer.EndsSentence(line.Text))
            .OrderBy(line => line.Box!.Value.Top).ToList();
        foreach (var line in shorts)
        {
            var box = line.Box!.Value;
            var column = shorts.Where(other =>
            {
                var o = other.Box!.Value;
                return Math.Abs(o.Left - box.Left) <= 0.02 || Math.Abs(((o.Left + o.Right) / 2) - ((box.Left + box.Right) / 2)) <= 0.02;
            }).ToList();
            if (column.Count >= 3) foreach (var member in column) result.Add(member);
        }
        return result;
    }

    private static int WordCount(string text) => text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length;

    /// <summary>Aynı yerdeki aynı yazı: yer yüzde ikilik ızgaraya yuvarlanır (yazı tanıma kutuları kare kare oynar).</summary>
    private static string Key(string text, TextBox box) =>
        $"{Math.Round((box.Left + box.Right) / 2 / 0.02)}:{Math.Round((box.Top + box.Bottom) / 2 / 0.02)}:{TextMatch.Normalize(text)}";

    /// <summary>Bir süredir görülmeyen yazılar unutulur (aynı altyazı sonra yeniden gelirse sabit sayılmasın).</summary>
    private void Forget(long now)
    {
        foreach (var key in seen.Where(pair => now - pair.Value.Last > 4000).Select(pair => pair.Key).ToList())
            seen.Remove(key);
    }
}
