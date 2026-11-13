// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core.Tests;

public class ContinuationTranslatorTests
{
    private sealed class Recorder : ITextTranslator
    {
        public List<string> Seen { get; } = [];

        public Task<string> TranslateAsync(string text, CancellationToken cancellationToken = default)
        {
            Seen.Add(text);
            return Task.FromResult("tr:" + text);
        }
    }

    private static async Task<List<string>> Feed(params (string Text, long At)[] lines)
    {
        long time = 0;
        var recorder = new Recorder();
        var translator = new ContinuationTranslator(recorder, () => time);
        foreach (var (text, at) in lines)
        {
            time = at;
            await translator.TranslateAsync(text);
        }
        return recorder.Seen;
    }

    [Fact]
    public async Task SentenceSplitOverSeveralSubtitlesIsTranslatedWhole()
    {
        var seen = await Feed(
            ("Flint Marko: You're the ones", 0),
            ("Flint Marko: who are gonna need help...", 2000),
            ("Flint Marko: when they come for you.", 5000),
            ("Spider-Man: Come for us?", 9000));
        Assert.Equal([
            "Flint Marko: You're the ones",
            "Flint Marko: You're the ones who are gonna need help...",
            "Flint Marko: You're the ones who are gonna need help... when they come for you.",
            "Spider-Man: Come for us?"], seen);
    }

    [Fact]
    public async Task ContinuationWithoutSpeakerLabelKeepsTheSpeaker()
    {
        var seen = await Feed(("Kraven: You grow slow in your old age,", 0), ("old friend.", 2500));
        Assert.Equal("Kraven: You grow slow in your old age, old friend.", seen[1]);
    }

    [Fact]
    public async Task FinishedSentencesAnotherSpeakerAndLateLinesStaySeparate()
    {
        var seen = await Feed(
            ("Sandman: Leave me alone!", 0),
            ("Sandman: I just wanted a regular life!", 2000),
            ("Sandman: You care about them--", 4000),
            ("Spider-Man: Of course I do.", 6000),
            ("Rio: I'm heading downtown to", 8000),
            ("Rio: help coordinate supplies.", 8000 + ContinuationTranslator.WithinMs + 1));
        Assert.Equal([
            "Sandman: Leave me alone!",
            "Sandman: I just wanted a regular life!",
            "Sandman: You care about them--",
            "Spider-Man: Of course I do.",
            "Rio: I'm heading downtown to",
            "Rio: help coordinate supplies."], seen);
    }

    [Fact]
    public async Task InterruptedLineJoinsOnlyALowercaseContinuation()
    {
        var seen = await Feed(("Sandman: You care about them--", 0), ("Sandman: but not me.", 2000));
        Assert.Equal("Sandman: You care about them-- but not me.", seen[1]);
    }

    [Fact]
    public async Task ScreenTextAndInterruptedLinesAreNotJoined()
    {
        var seen = await Feed(
            ("PRESS X TO CONTINUE", 0),
            ("LEVEL 2", 2000),
            ("Criminal: Stop, drop, and- wait--'", 4000),
            ("Criminal: I'll never make it out of these webs!", 6000),
            ("Spider-Man: Oh man -", 9000),
            ("Spider-Man: you think he's mad at me?", 10000));
        Assert.Equal("LEVEL 2", seen[1]);
        Assert.Equal("Criminal: I'll never make it out of these webs!", seen[3]);
        Assert.Equal("Spider-Man: Oh man - you think he's mad at me?", seen[5]);
    }

    /// Aynı konuşmacının açık kalan sözü, devamı büyük harfle (özel adla) başlasa da birleşir; sarılmış satırlar da.
    [Fact]
    public async Task SameSpeakerOpenSentenceJoinsEvenWithACapitalAndWrappedLines()
    {
        var seen = await Feed(
            ("Priestess: The carvings say the spear was hidden in\nthe caves beneath", 0),
            ("Priestess: Kephallonia when the temple was built!", 3000),
            ("Elena: I thought you were...", 9000),
            ("Elena: Never mind what I thought.", 11000),
            ("Elena: We leave at dawn.", 14000));
        Assert.Equal("Priestess: The carvings say the spear was hidden in the caves beneath Kephallonia when the temple was built!", seen[1]);
        Assert.Equal("Elena: I thought you were... Never mind what I thought.", seen[3]);
        // Biten cümleden sonra gelen yeni cümle birleşmez.
        Assert.Equal("Elena: We leave at dawn.", seen[4]);
    }

    [Fact]
    public async Task MisreadSpeakerNameIsNotPartOfTheSentence()
    {
        var seen = await Feed(("Marta: Okay,", 0), ("arta: the gate is open now!", 1500));
        Assert.Equal("Marta: Okay, the gate is open now!", seen[1]);
    }

    [Fact]
    public void GarbledCopyOfTheLineEndCollapses()
    {
        Assert.Equal("Tomas: Northern Supply Depot Entrance?",
            ContinuationTranslator.WithoutRepeatedLines("Tomas: Northern Supply Depot Entrance?\nrn Suply Depot Entrance?"));
        Assert.Equal("Take the north road.\nThen the south road.",
            ContinuationTranslator.WithoutRepeatedLines("Take the north road.\nThen the south road."));
    }

    [Fact]
    public async Task RereadOfTheSameLineIsNotJoinedWithItself()
    {
        var seen = await Feed(
            ("Flint Marko: I havent been okay", 0),
            ("Flint Marko: I haven't been okay", 500),
            ("Flint Marko: for a long time--", 2500));
        Assert.Equal("Flint Marko: I haven't been okay", seen[1]);
        Assert.Equal("Flint Marko: I havent been okay for a long time--", seen[2]);
    }

    [Fact]
    public void RepeatedLinesInOneReadingCollapse()
    {
        Assert.Equal("Kraven: A fate you will not share.",
            ContinuationTranslator.WithoutRepeatedLines("Kraven: A fate yowwill not share.\nKraven: A fate you will not share."));
        Assert.Equal("Where are you going?\n- Home.", ContinuationTranslator.WithoutRepeatedLines("Where are you going?\n- Home."));
        Assert.Equal("One line.", ContinuationTranslator.WithoutRepeatedLines(" One line. "));
    }
}
