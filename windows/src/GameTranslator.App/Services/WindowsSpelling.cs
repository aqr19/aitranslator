// SPDX-License-Identifier: AGPL-3.0-only

using System.Collections.Concurrent;
using System.Runtime.InteropServices;

namespace GameTranslator.App.Services;

/// <summary>
/// Windows'un yazım denetimi (ISpellChecker, Windows 8+): bir sözcük oyun dilinde gerçek mi. Dilin yazım sözlüğü
/// yüklü değilse <see cref="Create"/> null döner ve denetim yapılmaz. Sonuçlar bellekte tutulur (aynı sözcükler
/// sürekli sorulur). COM nesnesi iş parçacığı havuzunda oluşturulur ve bir kilitle kullanılır.
/// </summary>
public sealed class WindowsSpelling
{
    private readonly ISpellChecker checker;
    private readonly object gate = new();
    private readonly ConcurrentDictionary<string, bool> known = new(StringComparer.Ordinal);

    private WindowsSpelling(ISpellChecker checker) => this.checker = checker;

    public static WindowsSpelling? Create(string language)
    {
        try
        {
            return Task.Run(() =>
            {
                var factory = (ISpellCheckerFactory)new SpellCheckerFactoryClass();
                foreach (var tag in new[] { language, language == "en" ? "en-US" : language, language == "en" ? "en-GB" : language }.Distinct())
                    if (factory.IsSupported(tag)) return new WindowsSpelling(factory.CreateSpellChecker(tag));
                return null;
            }).GetAwaiter().GetResult();
        }
        catch
        {
            return null;
        }
    }

    public bool IsWord(string word)
    {
        if (known.TryGetValue(word, out var cached)) return cached;
        bool result;
        try
        {
            lock (gate)
            {
                var errors = checker.Check(word);
                result = errors.Next(out var error) != 0 || error is null;
            }
        }
        catch
        {
            // Denetim çalışmazsa sözcük doğru sayılır; satır her zamanki gibi çevrilir.
            result = true;
        }
        if (known.Count > 20000) known.Clear();
        known[word] = result;
        return result;
    }

    [ComImport, Guid("8E018A9D-2415-4677-BF08-794EA61F94BB"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellCheckerFactory
    {
        [return: MarshalAs(UnmanagedType.Interface)] object SupportedLanguages();
        [return: MarshalAs(UnmanagedType.Bool)] bool IsSupported([MarshalAs(UnmanagedType.LPWStr)] string languageTag);
        [return: MarshalAs(UnmanagedType.Interface)] ISpellChecker CreateSpellChecker([MarshalAs(UnmanagedType.LPWStr)] string languageTag);
    }

    [ComImport, Guid("B6FD0B71-E2BC-4653-8D05-F197E412770B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellChecker
    {
        [return: MarshalAs(UnmanagedType.LPWStr)] string LanguageTag();
        [return: MarshalAs(UnmanagedType.Interface)] IEnumSpellingError Check([MarshalAs(UnmanagedType.LPWStr)] string text);
    }

    [ComImport, Guid("803E3BD4-2828-4410-8290-418D1D73C762"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IEnumSpellingError
    {
        [PreserveSig] int Next([MarshalAs(UnmanagedType.Interface)] out object? value);
    }

    [ComImport, Guid("7AB36653-1796-484B-BDFA-E74F1DB7C1DC")]
    private class SpellCheckerFactoryClass;
}
