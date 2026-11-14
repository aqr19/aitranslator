// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core.Tests;

public class OcrConfusionsTests
{
    private static readonly HashSet<string> Words = new(StringComparer.OrdinalIgnoreCase)
    {
        "crouch", "to", "make", "your", "steps", "quiet", "knives", "do", "not", "vanish", "they", "are", "used", "for",
        "attack", "and", "defense", "the", "noise", "of", "moving", "after", "alter", "tor", "lake", "take", "it", "is",
        "modern", "moment", "are", "you", "ok", "hold", "on", "weapon", "from", "form",
    };

    private static string Repair(string line) => OcrConfusions.Repair(line, Words.Contains);

    [Theory]
    [InlineData("Crouch Io make your steps quiet.", "Crouch to make your steps quiet.")]
    [InlineData("Knives do nol vanish.", "Knives do not vanish.")]
    [InlineData("They are used lor attack and defense.", "They are used for attack and defense.")]
    [InlineData("The noise 01 moving", "The noise of moving")]
    [InlineData("Take it aller the attack.", "Take it after the attack.")]
    [InlineData("Are you 0K?", "Are you OK?")]
    [InlineData("A rnodern weapon", "A modern weapon")]
    [InlineData("Io make it quiet", "To make it quiet")]
    public void ConfusedLettersAreRepaired(string line, string expected) => Assert.Equal(expected, Repair(line));

    [Theory]
    // Gerçek sözcüğe dokunulmaz, yanlış okunmuş olsa bile ("lake" aslında "take" olabilir; bilinemez).
    [InlineData("Io lake the weapon")]
    [InlineData("They alter the form.")]
    // Özel adlar ve bilinmeyen sözcükler.
    [InlineData("Artyom, hold on!")]
    [InlineData("Kephallonia is not Zorvald.")]
    // Aday yoksa ya da birden çok eşit aday varsa değişmez.
    [InlineData("They are xqlz.")]
    public void RealWordsNamesAndUnknownsAreLeftAlone(string line)
    {
        var expected = line.StartsWith("Io ", StringComparison.Ordinal) ? "To" + line[2..] : line;
        Assert.Equal(expected, Repair(line));
    }

    [Fact]
    public void WithoutAWordCheckNothingChanges() => Assert.Equal("Knives do nol vanish.", OcrConfusions.Repair("Knives do nol vanish.", null));
}
