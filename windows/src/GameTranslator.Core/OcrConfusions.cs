// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core;

/// <summary>
/// Yazı tanımanın birbirine karıştırdığı harfleri onarır. İnce yazı tiplerinde "t" ve "f" sık sık "l", "o" sıfır,
/// "m" de "rn" okunur ("Io make", "do nol disappear", "used lor attack", "noise 01 your"); her karede aynı okunduğu
/// için beklemek düzeltmez. Gerçek sözcük olmayan parçada bu harfler değiştirilerek gerçek bir sözcük aranır; tek bir
/// aday çıkarsa (ya da adaylardan yalnız biri çok sık kullanılan bir sözcükse) parça onunla değiştirilir. Gerçek
/// sözcüğe ve özel ada dokunulmaz.
/// </summary>
public static class OcrConfusions
{
    /// <summary>Her zaman aynı biçimde bozulan çok kısa sözcükler (denetime gerek yok).</summary>
    private static readonly Dictionary<string, string> Fixed = new(StringComparer.Ordinal)
    {
        ["Io"] = "to", ["lo"] = "to", ["01"] = "of", ["0f"] = "of", ["0K"] = "OK", ["0k"] = "ok",
        ["lhe"] = "the", ["Ihe"] = "the", ["lt"] = "It", ["lf"] = "If", ["ls"] = "Is",
    };

    /// <summary>Birden çok aday çıktığında tercih edilen, çok sık kullanılan sözcükler.</summary>
    private static readonly HashSet<string> Common = new(StringComparer.OrdinalIgnoreCase)
    {
        "the", "to", "of", "for", "not", "that", "this", "with", "it", "at", "if", "off", "after", "often", "from", "first",
        "just", "last", "left", "let", "lot", "get", "got", "out", "but", "what", "there", "their", "they", "them", "then",
        "than", "time", "little", "better", "until", "still", "must", "most", "find", "fast", "soft", "take", "into",
        "want", "about", "attack", "fight", "right", "night", "light", "might", "enemy", "weapon", "from", "more", "come",
    };

    private static readonly (string From, string To)[] Swaps =
    [
        ("l", "t"), ("l", "f"), ("I", "l"), ("I", "t"), ("0", "o"), ("1", "l"), ("rn", "m"), ("vv", "w"), ("cl", "d"),
    ];

    public static string Repair(string line, Func<string, bool>? isWord)
    {
        if (isWord is null || line.Length == 0) return line;
        var tokens = line.Split(' ');
        var changed = false;
        for (var index = 0; index < tokens.Length; index++)
        {
            var token = tokens[index];
            var start = 0;
            var end = token.Length;
            while (start < end && !char.IsLetterOrDigit(token[start])) start++;
            while (end > start && !char.IsLetterOrDigit(token[end - 1])) end--;
            if (end - start < 2) continue;
            var core = token[start..end];
            var fixedWord = Fixed.GetValueOrDefault(core) ?? Candidate(core, isWord);
            if (fixedWord is null || fixedWord == core) continue;
            // Cümle başındaki sözcük büyük harfle başlar ("Io make" satır başındaysa "To make").
            if (index == 0 && char.IsUpper(core[0]) && char.IsLower(fixedWord[0])) fixedWord = char.ToUpperInvariant(fixedWord[0]) + fixedWord[1..];
            tokens[index] = token[..start] + fixedWord + token[end..];
            changed = true;
        }
        return changed ? string.Join(' ', tokens) : line;
    }

    /// <summary>Parça gerçek sözcük değilse, karışan harfler değiştirilerek bulunan tek (ya da tek yaygın) gerçek sözcük.</summary>
    private static string? Candidate(string core, Func<string, bool> isWord)
    {
        if (core.Length is < 3 or > 14 || !core.All(c => char.IsLetterOrDigit(c) || c is '\'' or '’')) return null;
        if (!core.Any(char.IsLetter) || isWord(core)) return null;
        // Özel ad gibi duran parça (baş harfi büyük, gerisi küçük, rakamsız) yalnız içinde karışan harf dizisi varsa denenir.
        var proper = char.IsUpper(core[0]) && core.Skip(1).All(char.IsLower);
        if (proper && !core.Contains("rn", StringComparison.Ordinal) && core[0] != 'I') return null;

        var found = new HashSet<string>(StringComparer.Ordinal);
        void Try(string text, int depth)
        {
            foreach (var (from, to) in Swaps)
            {
                for (var at = text.IndexOf(from, StringComparison.Ordinal); at >= 0; at = text.IndexOf(from, at + 1, StringComparison.Ordinal))
                {
                    var next = text[..at] + to + text[(at + from.Length)..];
                    if (isWord(next)) found.Add(next);
                    if (depth < 2 && found.Count < 12) Try(next, depth + 1);
                }
            }
        }
        Try(core, 1);
        if (found.Count == 0) return null;
        if (found.Count == 1) return found.First();
        var common = found.Where(Common.Contains).ToList();
        return common.Count == 1 ? common[0] : null;
    }
}
