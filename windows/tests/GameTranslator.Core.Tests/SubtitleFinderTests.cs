// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core.Tests;

public class SubtitleFinderTests
{
    /// <summary>Ortası (<paramref name="x"/>, <paramref name="y"/>) olan, genişliği metne göre, yüksekliği %2,5 olan satır.</summary>
    private static TextLine Line(string text, double y, double x = 0.5)
    {
        var half = Math.Min(0.45, text.Length * 0.006);
        return new TextLine(text, new TextBox(x - half, y - 0.0125, x + half, y + 0.0125));
    }

    private static SubtitleFinder.Verdict Verdict(SubtitleFinder finder, long now, params TextLine[] lines) =>
        finder.Classify(new Reading(lines), now)[^1].Verdict;

    private static SubtitleFinder Learned(double y = 0.88)
    {
        var finder = new SubtitleFinder();
        finder.Classify(new Reading([Line("Where are you going?", y)]), 0);
        finder.Classify(new Reading([Line("We need to move, now.", y)]), 3000);
        finder.Classify(new Reading([Line("Stay close to me.", y)]), 6000);
        Assert.NotNull(finder.Band);
        return finder;
    }

    [Fact]
    public void LearnsTheBandFromTheFirstSubtitles()
    {
        var finder = new SubtitleFinder();
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, 0, Line("Where are you going?", 0.88)));
        Assert.Null(finder.Band);
        finder.Classify(new Reading([Line("We need to move, now.", 0.88)]), 3000);
        finder.Classify(new Reading([Line("Stay close to me.", 0.885)]), 6000);
        var band = Assert.NotNull(finder.Band);
        Assert.InRange(band.Top, 0.78, 0.86);
        Assert.InRange(band.Bottom, 0.90, 0.98);
    }

    /// Dövüşte ekranın ortasında çıkan beceri adları ve ipuçları şeridi yanlış yere çekiyordu.
    [Fact]
    public void ShortCombatTextDoesNotTeachTheBand()
    {
        var finder = new SubtitleFinder();
        finder.Classify(new Reading([Line("Spider Barrage", 0.75)]), 0);
        finder.Classify(new Reading([Line("Glide up", 0.75)]), 1000);
        finder.Classify(new Reading([Line("Web Wings ready", 0.75)]), 2000);
        finder.Classify(new Reading([Line("Hold to pull", 0.75)]), 3000);
        Assert.Null(finder.Band);
        Assert.Equal(SubtitleFinder.Verdict.NotSentence, Verdict(finder, 4000, Line("Spider Barrage", 0.75)));
    }

    [Fact]
    public void TwoLineSubtitleStaysInsideTheBand()
    {
        var finder = Learned();
        var findings = finder.Classify(new Reading([
            Line("MJ: According to witnesses, he was running", 0.865),
            Line("down Broadway, yelling nonsense.", 0.895)]), 9000);
        Assert.All(findings, finding => Assert.Equal(SubtitleFinder.Verdict.Subtitle, finding.Verdict));
    }

    [Fact]
    public void TutorialTipOutsideTheBandIsNotASubtitle()
    {
        var finder = Learned();
        Assert.Equal(SubtitleFinder.Verdict.OutsideBand,
            Verdict(finder, 9000, Line("You can sneak up on enemies to take them down quietly.", 0.45)));
        Assert.Equal(SubtitleFinder.Verdict.OutsideBand,
            Verdict(finder, 9500, Line("Are you sure you want to skip this cinematic?", 0.38)));
    }

    [Fact]
    public void ButtonPromptsCornerTextAndTitlesAreNotSubtitles()
    {
        var finder = Learned();
        Assert.Equal(SubtitleFinder.Verdict.Prompt, Verdict(finder, 9000, Line("R2 Swing", 0.88)));
        Assert.Equal(SubtitleFinder.Verdict.OffCenter, Verdict(finder, 9000, Line("Find the water tank on the roof.", 0.88, x: 0.15)));
        Assert.Equal(SubtitleFinder.Verdict.NotSentence, Verdict(finder, 9000, Line("RESET ALL TO DEFAULT", 0.88)));
        Assert.Equal(SubtitleFinder.Verdict.NotSentence, Verdict(finder, 9000, Line("Back", 0.88)));
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, 9000, Line("Run!", 0.88)));
    }

    [Fact]
    public void TextThatStaysPutIsInterface()
    {
        var finder = Learned();
        var objective = Line("Reach the water tank before Sandman does.", 0.88);
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, 10000, objective));
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, 13000, objective));
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, 16000, objective));
        Assert.Equal(SubtitleFinder.Verdict.Static, Verdict(finder, 10000 + SubtitleFinder.StaticAfterMs, objective));
        // Kaybolup sonra yeniden gelen aynı satır yeniden altyazıdır.
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, 40000, objective));
    }

    [Fact]
    public void MenuColumnIsNotASubtitle()
    {
        var finder = new SubtitleFinder();
        var findings = finder.Classify(new Reading([
            Line("Map", 0.40), Line("Settings", 0.44), Line("Photo Mode", 0.48), Line("Quit", 0.52)]), 0);
        Assert.All(findings, finding => Assert.Equal(SubtitleFinder.Verdict.Menu, finding.Verdict));
    }

    [Fact]
    public void RelearnsWhenSubtitlesMoveElsewhere()
    {
        var finder = Learned(0.88);
        var start = 6000 + SubtitleFinder.RelearnAfterMs;
        Assert.Equal(SubtitleFinder.Verdict.OutsideBand, Verdict(finder, start, Line("This game shows them at the top.", 0.10)));
        finder.Classify(new Reading([Line("Second line up here as well.", 0.10)]), start + 3000);
        finder.Classify(new Reading([Line("And a third one to be sure.", 0.10)]), start + 6000);
        Assert.Equal(SubtitleFinder.Verdict.Subtitle, Verdict(finder, start + 9000, Line("Now this is the subtitle band.", 0.10)));
        Assert.Equal(SubtitleFinder.Verdict.OutsideBand, Verdict(finder, start + 9500, Line("The old place is not, anymore.", 0.88)));
    }

    [Fact]
    public void SubtitlesReturnsOnlyTheSubtitleLines()
    {
        var finder = Learned();
        var reading = finder.Subtitles(new Reading([
            Line("Objective updated: find Marko.", 0.20, x: 0.2),
            Line("R2 Swing", 0.70),
            Line("Spider-Man: Only way is up.", 0.88)]), 9000);
        Assert.Equal("Spider-Man: Only way is up.", reading.Text);
    }
}
