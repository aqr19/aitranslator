// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core.Tests;

public class SpeakerLineTests
{
    private static Reading Read(params string[] lines) =>
        new(lines.Select((text, row) => new TextLine(text, new TextBox(0.3, 0.1 * row, 0.7, (0.1 * row) + 0.05))));

    [Fact]
    public void NameOnItsOwnLineJoinsTheSpeech()
    {
        Assert.Equal("ELENA: We have no choice but to try!", Read("ELENA", "We have no choice but to try!").WithSpeakerLine().Text);
        Assert.Equal("YOUNG TOMAS: I can tell from the look on your face\nthat you were paid.",
            Read("YOUNG TOMAS", "I can tell from the look on your face", "that you were paid.").WithSpeakerLine().Text);
        // Kutu adı da kapsar (TV'de çeviri adın üstünü de örtsün).
        Assert.Equal(0.0, Read("ELENA", "Run!").WithSpeakerLine().Lines[0].Box!.Value.Top);
    }

    [Fact]
    public void OrdinaryLinesAreLeftAlone()
    {
        Assert.Equal("Elena: Run!\nNow!", Read("Elena: Run!", "Now!").WithSpeakerLine().Text);
        Assert.Equal("WAIT!\nNot yet.", Read("WAIT!", "Not yet.").WithSpeakerLine().Text);
        Assert.Equal("ELENA", Read("ELENA").WithSpeakerLine().Text);
        Assert.Equal("SORT BY\nCATEGORY", Read("SORT BY", "CATEGORY").WithSpeakerLine().Text);
    }

    [Theory]
    [InlineData("Engraving Challenges", true)]
    [InlineData("Honoring the Dead", true)]
    [InlineData("SORT BY: CATEGORY", true)]
    [InlineData("LEVEL 2", true)]
    [InlineData("ACHAIA", true)]
    [InlineData("Thank you", false)]
    [InlineData("Hold the gate", false)]
    [InlineData("Run!", false)]
    [InlineData("ELENA: We have no choice but to try!", false)]
    [InlineData("I can tell from the look on your face", false)]
    [InlineData("Yeah", false)]
    public void HeadingsAreRecognized(string text, bool heading) => Assert.Equal(heading, Reading.IsHeading(text));

    [Fact]
    public void ReadingMadeOnlyOfHeadingsIsDropped()
    {
        Assert.Equal("", Read("TIES &", "ACTS (0)").WithoutHeadings().Text);
        Assert.Equal("", Read("Secondary Interact").WithoutHeadings().Text);
        Assert.Equal("ELENA: Run!", Read("ELENA", "Run!").WithSpeakerLine().WithoutHeadings().Text);
        Assert.Equal("Engraving Challenges\nYou have to see this.", Read("Engraving Challenges", "You have to see this.").WithoutHeadings().Text);
    }
}
