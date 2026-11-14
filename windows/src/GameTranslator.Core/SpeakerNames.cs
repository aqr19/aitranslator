// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core;

/// <summary>
/// Konuşmacı adlarını oyundan öğrenir ve bozuk okunmuş adı doğrusuna çevirir. Adlar sözlükte olmadığı için yazım
/// denetimi "Minnir" ile "Mimir"i ayıramaz; ama oyun aynı adı onlarca kez gösterir, yazı tanıma çoğunda doğru okur.
/// Sık görülen ad bilinen addır; ilk kez (ya da ikinci kez) görülen ve bilinen bir ada çok benzeyen ad onun bozuk
/// okumasıdır ("Minnir", "Mimnir", "Mimire" → "Mimir"; "Kracos" → "Kratos"). Birbirine benzeyen iki gerçek ad
/// ("Maria", "Marie") ikisi de yeterince görülünce ayrı kalır. Durum tutar; tek iş parçacığından çağrılır.
/// </summary>
public sealed class SpeakerNames
{
    /// <summary>Bir ad bu kadar görülünce bilinen ad olur.</summary>
    public const int KnownAfter = 3;
    /// <summary>
    /// Bilinen ad, benzer addan en az bu kat sık görülmeliyse onun doğrusu sayılır. Yazı tanıma bir adı hep aynı biçimde
    /// bozabiliyor ("Mimir" her beş okumadan birinde "Minnir"), bu yüzden bozuk ad da defalarca görülür; iki gerçek ad
    /// ("Maria", "Marie") ise birbirine yakın sıklıkta geçer.
    /// </summary>
    public const int Ratio = 3;

    private readonly Dictionary<string, int> seen = new(StringComparer.Ordinal);

    /// <summary>Adı kaydeder ve doğrusunu döner (bilinen bir adın bozuk okumasıysa o ad, değilse kendisi).</summary>
    public string Canonical(string name)
    {
        seen[name] = seen.GetValueOrDefault(name) + 1;
        if (seen.Count > 300) Forget();
        if (name.Length < 4) return name;
        string? best = null;
        var bestCount = 0;
        foreach (var (known, count) in seen)
        {
            if (count < KnownAfter || count <= bestCount || known == name) continue;
            if (count < seen[name] * Ratio || !Alike(name, known)) continue;
            (best, bestCount) = (known, count);
        }
        return best ?? name;
    }

    /// <summary>
    /// Satır başındaki parça, iki nokta üst üstesi okunmamış bilinen bir ad mı: adın ardına bir iki harf yapışmış
    /// ("Stintsy Fuck", "Stintsi Suggestin'": ":" harf okunmuş) ya da ada çok benzeyen ve ardından büyük harfle başlayan
    /// söz gelen parça ("Jockte Hey..."). Öyleyse bilinen ad; değilse null. Adın kendisine (ad sözün içindeyse: "Jackie is
    /// here") dokunulmaz.
    /// </summary>
    public string? LabelIn(string first, string? next)
    {
        var token = first.TrimEnd('.', ',', ';', ':');
        if (token.Length < 4 || !char.IsUpper(token[0])) return null;
        foreach (var (known, count) in seen)
        {
            if (count < KnownAfter || known.Length < 4 || known.Contains(' ') || token == known) continue;
            var extra = token.Length - known.Length;
            if (token.StartsWith(known, StringComparison.Ordinal) && extra is 1 or 2 && token[known.Length..].All(char.IsLower)) return known;
            if (token.Length >= 5 && next is { Length: > 0 } && char.IsUpper(next[0]) && Alike(token, known)) return known;
        }
        return null;
    }

    /// <summary>Aynı sayıda sözcük ve harflerin çoğu aynı (uzunluk farkı en çok iki).</summary>
    private static bool Alike(string read, string known)
    {
        if (known.Length < 4 || Math.Abs(read.Length - known.Length) > 2) return false;
        if (read.Count(c => c == ' ') != known.Count(c => c == ' ')) return false;
        return TextMatch.IsSimilar(read.ToLowerInvariant(), known.ToLowerInvariant(), 0.6);
    }

    /// <summary>Bir kez görülmüş adlar (çoğu bozuk okuma) atılır.</summary>
    private void Forget()
    {
        foreach (var name in seen.Where(pair => pair.Value < 2).Select(pair => pair.Key).ToList()) seen.Remove(name);
    }
}
