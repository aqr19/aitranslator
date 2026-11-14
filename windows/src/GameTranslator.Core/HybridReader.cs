// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core;

/// <summary>
/// İki okuyucuyu birlikte kullanır: hızlı olan (Windows'un yazı tanıması) her karede çalışır; okuması bozuk görünürse
/// aynı görüntü güçlü ama yavaş olanla (PP-OCR) da okunur ve daha iyi puan alan seçilir. Düz zeminde hızlı okuyucu
/// kusursuzdur ve güçlü okuyucu hiç çalışmaz; hareketli, parlak zeminde ya da yazı belirirken hızlı okuyucunun
/// bozduğu satırı güçlü okuyucu kurtarır. Hızlı okuyucu hiç yazı bulamadığında güçlü okuyucu yalnız aralıklı
/// denenir (parlak zeminde hızlı okuyucu yazıyı hiç göremeyebilir), yoksa boş her karede boşa çalışırdı.
/// Okuyucuların sahibi değildir (güçlü okuyucu okuma hatları arasında paylaşılır); onları kuran kapatır.
/// Bir örnek tek iş parçacığından çağrılır.
/// </summary>
public sealed class HybridReader(ITextReader fast, ITextReader strong, Func<long>? clock = null) : ITextReader
{
    /// <summary>Hızlı okuyucu boş döndüğünde güçlü okuyucu en sık bu aralıkla denenir.</summary>
    public const int ProbeEveryMs = 600;

    private readonly Func<long> now = clock ?? (() => Environment.TickCount64);
    private long lastProbe = long.MinValue / 2;

    /// <summary>Okuma bozuk mu (yazım denetimi); verilmezse yalnız <see cref="OcrNoise.LooksGarbled"/>.</summary>
    public Func<string, bool>? LooksMisread { get; set; }
    /// <summary>Okumanın puanı (yüksek: daha çok gerçek sözcük); verilmezse <see cref="OcrNoise.Score"/>.</summary>
    public Func<string, int>? Score { get; set; }
    /// <summary>
    /// Satır onarımı (karışan harfler, boşluksuz okunmuş sözcükler: <see cref="OcrConfusions.Repair"/>). İki okuma
    /// karşılaştırılmadan önce ikisi de onarılır; onarılınca temizlenen hızlı okuma için güçlü okuyucu çalışmaz.
    /// </summary>
    public Func<string, string>? Repair { get; set; }
    /// <summary>Güçlü okuyucunun devreye girdiği her kare için bir satır (altyazı günlüğü).</summary>
    public Action<string>? Log { get; set; }

    /// <summary>Güçlü okuyucunun çalıştığı ve okuması seçilen kare sayıları (ölçüm için).</summary>
    public int StrongRuns { get; private set; }
    public int StrongWins { get; private set; }

    public string Read(Frame image) => ReadLines(image, deep: true).Text;

    public string Read(Frame image, bool deep) => ReadLines(image, deep).Text;

    public Reading ReadLines(Frame image, bool deep)
    {
        var quick = fast.ReadLines(image, deep);
        var text = quick.Text.Trim();
        if (text.Length == 0)
        {
            // Hızlı okuyucu boş: çoğu zaman ekranda altyazı yoktur. Güçlü okuyucu seyrek denenir.
            if (now() - lastProbe < ProbeEveryMs) return quick;
            lastProbe = now();
            var probed = Strong(image, deep);
            // Güçlü okuyucu boş sahnede de bir şeyler "okur" (dokudan "MEEEEEI", tek harfler, başka yazı sisteminden
            // harfler); yalnız gerçekten yazıya benzeyen okuma kabul edilir.
            if (!LooksLikeText(probed.Text) || Points(probed.Text) <= 0) return quick;
            StrongWins++;
            Log?.Invoke($"güçlü okuyucu: hızlı okuyucu boş döndü → {SubtitleLog.Excerpt(probed.Text)}");
            return probed;
        }
        if (!Misread(text)) return quick;
        // Onarılabilen okuma ("Tinne is running out, ny love.") güçlü okuyucuyu beklemeden düzelir.
        quick = Tidy(quick);
        text = quick.Text.Trim();
        if (!Misread(text)) return quick;

        var careful = Tidy(Strong(image, deep));
        var other = careful.Text.Trim();
        var (quickPoints, carefulPoints) = (Points(text), Points(other));
        // Hızlı okuma bozuk. Güçlü okuma bozuk görünmüyorsa kazanır (yalnız harf sayan puan bozuk okumayı
        // "daha uzun" diye üstün sayabiliyor); ama satırın küçük bir parçası olmamalı. İkisi de bozuksa puan
        // belirler; eşitlikte hızlı okuma kalır, hattın geri kalanı onun satır kutularına göre ayarlandı.
        // Sözcük sayısı da yakın olmalı: güçlü okuyucu bazen satırı boşluksuz okuyor ("Kirkitrustimlikeobrother.").
        var clean = other.Length > 0 && !Misread(other) && Letters(other) * 10 >= Letters(text) * 6 && Words(other) * 10 >= Words(text) * 6;
        if (other.Length == 0 || (!clean && carefulPoints <= quickPoints))
        {
            Log?.Invoke($"güçlü okuyucu: hızlı okuma kaldı ({quickPoints} ≥ {carefulPoints}) {SubtitleLog.Excerpt(text)}");
            return quick;
        }
        StrongWins++;
        Log?.Invoke($"güçlü okuyucu: {SubtitleLog.Excerpt(text)} → {SubtitleLog.Excerpt(other)}");
        return careful;
    }

    private Reading Strong(Frame image, bool deep)
    {
        StrongRuns++;
        try
        {
            return strong.ReadLines(image, deep);
        }
        catch
        {
            // Güçlü okuyucu çalışamazsa (model, bellek) hızlı okuma kullanılır; okuma hattı durmaz.
            return Reading.Empty;
        }
    }

    /// <summary>
    /// Hızlı okuyucunun göremediği yerde güçlü okuyucunun bulduğu yazı gerçek mi: en az iki sözcük ve sekiz harf,
    /// harflerin hepsi Latin yazısından ve yazım denetimine göre bozuk değil.
    /// </summary>
    private bool LooksLikeText(string text)
    {
        text = text.Trim();
        var letters = text.Where(char.IsLetter).ToList();
        if (letters.Count < 8 || letters.Any(letter => letter > 'ɏ')) return false;
        var words = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Count(word => word.Count(char.IsLetter) >= 2);
        return words >= 2 && !Misread(text);
    }

    /// <summary>
    /// Satırları onarır ve birden çok satırlı okumadan çöp satırları ("HIITIIE", "MKIceAng": zemindeki dokudan okunan
    /// harfler) çıkarır: bozuk ve hiç gerçek sözcüğü olmayan satır. Okumada en az bir satır kalır.
    /// </summary>
    private Reading Tidy(Reading reading)
    {
        if (reading.Lines.Count == 0) return reading;
        var lines = Repair is { } repair ? reading.Lines.Select(line => line with { Text = repair(line.Text) }).ToList() : [.. reading.Lines];
        if (lines.Count > 1)
        {
            var kept = lines.Where(line => !(Misread(line.Text) && Points(line.Text) <= 0)).ToList();
            if (kept.Count > 0) lines = kept;
        }
        return new Reading(lines);
    }

    private bool Misread(string text) => OcrNoise.LooksGarbled(text) || (LooksMisread?.Invoke(text) ?? false);

    private int Points(string text) => (Score ?? OcrNoise.Score)(text);

    private static int Letters(string text) => text.Count(char.IsLetter);

    private static int Words(string text) => text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Count(word => word.Any(char.IsLetter));
}
