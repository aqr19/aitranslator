// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core;

/// <summary>
/// Okumanın yazım denetimine göre ne kadar bozuk olduğu. Yazı tanıma hareketli sahnede harf düşürür ya da sözcükleri
/// yapıştırır ("Igot it", "gonnatry workaroun", "equ Sts"); bunlar gerçek sözcük değildir ama simge içermediği için
/// <see cref="OcrNoise"/> yakalamaz ve satır bozuk hâliyle çevrilip gösterilir, düzgünü bir iki saniye sonra gelir.
/// Sözcüğün gerçek olup olmadığını uygulamanın verdiği denetçi söyler (Windows'un yazım denetimi).
/// Özel adlar yanlış sayılmasın diye büyük harfle başlayan düzgün yazılmış sözcükler ("Kraven", "Ganke") sayılmaz;
/// büyük-küçük harfi karışık olanlar ("IVe", "IEot") sayılır.
/// </summary>
public sealed class Misspelling(Func<string, bool> isWord)
{
    /// <summary>Bozuk sayılan sözcüklerin harf sayısı ve satırdaki toplam harf sayısı.</summary>
    public (int Bad, int All) Measure(string text)
    {
        int bad = 0, all = 0;
        foreach (var token in text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries))
        {
            // Baştaki ve sondaki noktalama atılır; sözcük içindeki kesme ve tire kalır ("you're", "Spider-Man").
            var start = 0;
            var end = token.Length;
            while (start < end && !char.IsLetter(token[start])) start++;
            while (end > start && !char.IsLetter(token[end - 1])) end--;
            var word = token[start..end];
            var letters = word.Count(char.IsLetter);
            if (letters == 0) continue;
            all += letters;
            // Tek harf ve kısaltmalar denetlenmez; tire ve kesme içeren sözcükler parça parça değil bütün sorulur.
            if (letters < 2 || word.All(c => !char.IsLetter(c) || char.IsUpper(c))) continue;
            var proper = char.IsUpper(word[0]) && word.Skip(1).Where(char.IsLetter).All(char.IsLower);
            if (proper)
            {
                // "I" sonraki sözcüğe yapışmış ("Igot it", "Iknow"): ad değil, bozuk okumadır.
                if (word[0] == 'I' && letters >= 3 && !isWord(word) && isWord(word[1..])) bad += letters;
                continue;
            }
            if (!isWord(word) && !IsContraction(word)) bad += letters;
        }
        return (bad, all);
    }

    /// <summary>
    /// Yazı tanıma kesme işaretini sık sık görmez ("dont", "cant", "theyre", "youve") ve bunu her karede aynı yapar;
    /// beklemek düzeltmez, yalnız gecikme ekler. Kesme işareti eklenince gerçek sözcük olan biçimler doğru sayılır.
    /// Konuşma dilindeki kısaltmalar da ("'em", "c'mon") öyle.
    /// </summary>
    private bool IsContraction(string word)
    {
        var lower = word.ToLowerInvariant();
        if (lower is "em" or "cmon" or "ya" or "til" or "cause") return true;
        if (word.Contains('\'') || word.Contains('’') || word.Length < 3) return false;
        foreach (var tail in new[] { 1, 2 })
        {
            if (word.Length <= tail) continue;
            if (isWord(word[..^tail] + "'" + word[^tail..])) return true;
        }
        return false;
    }

    /// <summary>Satırda gerçek olmayan sözcük var mı (daha iyi bir okuma beklemeye değer mi).</summary>
    public bool LooksMisread(string text) => Measure(text).Bad > 0;

    /// <summary>Okuma puanı: <see cref="OcrNoise.Score"/> eksi bozuk sözcüklerin harflerinin üç katı.</summary>
    public int Score(string text) => OcrNoise.Score(text) - (3 * Measure(text).Bad);
}
