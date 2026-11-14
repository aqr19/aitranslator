// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core.Tests;

public class ContinuationTranslatorTests
{
    /// <summary>Kendisine gelen metni kaydeder ve başına "tr:" koyarak döndürür.</summary>
    private sealed class Recorder : ITextTranslator
    {
        public List<string> Seen { get; } = [];

        public Task<string> TranslateAsync(string text, CancellationToken cancellationToken = default)
        {
            lock (Seen) Seen.Add(text);
            return Task.FromResult("tr:" + text);
        }
    }

    /// <summary>Satırları sırayla çevirir; (çevirmene giden metinler, dönen çeviriler).</summary>
    private static async Task<(List<string> Sent, List<string> Shown)> Feed(params (string Text, long At)[] lines)
    {
        long time = 0;
        var recorder = new Recorder();
        var translator = new ContinuationTranslator(recorder, () => time);
        var shown = new List<string>();
        foreach (var (text, at) in lines)
        {
            time = at;
            shown.Add(await translator.TranslateAsync(text));
        }
        return (recorder.Seen, shown);
    }

    /// Ad çevirmene verilmez; çevirmen onu sıradan sözcük sanıp çeviriyordu ("ANNA" → "ANNE").
    [Fact]
    public async Task SpeakerNameIsKeptAsItIsAndOnlyTheSpeechIsTranslated()
    {
        var (sent, shown) = await Feed(("ANNA: Are you all right?", 0), ("Careful now.", 5000));
        Assert.Equal(["Are you all right?", "Careful now."], sent);
        Assert.Equal(["ANNA: tr:Are you all right?", "tr:Careful now."], shown);
    }

    /// Satır değişirken ad iki kez okunabiliyor; ikinci ad söze katılmaz. Seslenme ("Sam, wait!") sözdür.
    [Theory]
    [InlineData("Faye: Faye: This way.", "This way.")]
    [InlineData("Kratos: Kratos. The tracks stop here.", "The tracks stop here.")]
    [InlineData("Jesse: \"Jesse: Sounds exciting.", "Sounds exciting.")]
    [InlineData("Kratos: (Kratos: They should not be this close.", "They should not be this close.")]
    [InlineData("Lae'zel: Lae'ze: It cannot be helped. Come.", "It cannot be helped. Come.")]
    [InlineData("Varl: Varl• So the storms.", "So the storms.")]
    [InlineData("Woman's Voice: Woman's Voice The Zero Dawn system.", "The Zero Dawn system.")]
    [InlineData("Aloy: \" —Aloy: We'll need to cut through.", "We'll need to cut through.")]
    [InlineData("Sam: Sam, wait for me!", "Sam, wait for me!")]
    [InlineData("Sam: Samuel is gone.", "Samuel is gone.")]
    public async Task SpeakerNameReadTwiceIsNotPartOfTheSpeech(string line, string speech)
    {
        var (sent, _) = await Feed((line, 0));
        Assert.Equal([speech], sent);
    }

    /// İki nokta üst üstesi harf okunmuş ad ("Stintsy") bilinen adla etiket olur; ad sözün içindeyse dokunulmaz.
    [Fact]
    public async Task SpeakerNameWithMisreadColonBecomesALabel()
    {
        var lines = Enumerable.Range(0, 4).Select(i => ($"Stints: Line number {i} it is.", (long)i * 20000)).ToList();
        lines.Add(("Stintsy Fuck, he's here.", 100000));
        lines.Add(("Jockie Hey, pal.", 120000));
        lines.Add(("Stints is a cop.", 140000));
        var (sent, shown) = await Feed([.. lines]);
        Assert.Equal("Stints: tr:Fuck, he's here.", shown[4]);
        Assert.Equal("tr:Jockie Hey, pal.", shown[5]);
        Assert.Equal("tr:Stints is a cop.", shown[6]);
    }

    /// Oyunda sık geçen adın bozuk okuması doğrusuyla gösterilir.
    [Fact]
    public async Task MisreadSpeakerNameIsShownAsTheNameSeenOften()
    {
        var lines = Enumerable.Range(0, 4).Select(i => ($"Mimir: Line number {i} it is.", (long)i * 20000)).ToList();
        lines.Add(("Minnir: He never came back.", 100000));
        var (_, shown) = await Feed([.. lines]);
        Assert.Equal("Mimir: tr:He never came back.", shown[^1]);
    }

    [Fact]
    public async Task SeveralSpeakersAreTranslatedSeparatelyWithTheirNames()
    {
        var (sent, shown) = await Feed(("DUKE: I cannot believe my eyes!\nYou gave us a scare, brother.\nDAMIR: Move, Duke!", 0));
        Assert.Equal(["I cannot believe my eyes! You gave us a scare, brother.", "Move, Duke!"], sent.Order().ToList());
        Assert.Equal("DUKE: tr:I cannot believe my eyes! You gave us a scare, brother.\nDAMIR: tr:Move, Duke!", shown[0]);
    }

    /// Önceki konuşmanın ekranda kalan sonu ile yeni konuşmacının satırı birlikte okunursa ad yine çevrilmez.
    [Fact]
    public async Task TailOfThePreviousLineFollowedByASpeakerIsSplitToo()
    {
        var (sent, shown) = await Feed(("all gone now.\nGUARD: Watch the gate closely,\nand call out if you see anyone!", 0));
        Assert.Equal(["Watch the gate closely, and call out if you see anyone!", "all gone now."], sent.Order(StringComparer.Ordinal).ToList());
        Assert.Equal("tr:all gone now.\nGUARD: tr:Watch the gate closely, and call out if you see anyone!", shown[0]);
    }

    [Fact]
    public async Task SentenceSplitOverSeveralSubtitlesIsTranslatedWhole()
    {
        var (sent, shown) = await Feed(
            ("Marko: You are the ones", 0),
            ("Marko: who are going to need help...", 2000),
            ("Marko: when they come for you.", 5000),
            ("Elena: Come for us?", 9000));
        Assert.Equal([
            "You are the ones",
            "You are the ones who are going to need help...",
            "You are the ones who are going to need help... when they come for you.",
            "Come for us?"], sent);
        Assert.Equal("Marko: tr:You are the ones who are going to need help... when they come for you.", shown[2]);
        Assert.Equal("Elena: tr:Come for us?", shown[3]);
    }

    [Fact]
    public async Task ContinuationWithoutSpeakerLabelKeepsTheSpeaker()
    {
        var (sent, shown) = await Feed(("Kraven: You grow slow in your old age,", 0), ("old friend.", 2500));
        Assert.Equal("You grow slow in your old age, old friend.", sent[1]);
        Assert.Equal("Kraven: tr:You grow slow in your old age, old friend.", shown[1]);
    }

    [Fact]
    public async Task FinishedSentencesAnotherSpeakerAndLateLinesStaySeparate()
    {
        var (sent, _) = await Feed(
            ("Sandman: Leave me alone!", 0),
            ("Sandman: I just wanted a regular life!", 2000),
            ("Sandman: You care about them--", 4000),
            ("Elena: Of course I do.", 6000),
            ("Rio: I am heading downtown to", 8000),
            ("Rio: help coordinate supplies.", 8000 + ContinuationTranslator.WithinMs + 1));
        Assert.Equal([
            "Leave me alone!", "I just wanted a regular life!", "You care about them--", "Of course I do.",
            "I am heading downtown to", "help coordinate supplies."], sent);
    }

    [Fact]
    public async Task InterruptedLineJoinsOnlyALowercaseContinuation()
    {
        var (sent, _) = await Feed(("Sandman: You care about them--", 0), ("Sandman: but not me.", 2000));
        Assert.Equal("You care about them-- but not me.", sent[1]);
    }

    /// Üç noktayla biten sözden sonra gelen büyük harfli satır yeni cümledir; yarım okunmuş satır da birleşmez.
    [Fact]
    public async Task NewSentenceAfterAnEllipsisOrAPartialReadIsNotJoined()
    {
        var (sent, _) = await Feed(
            ("ANNA: At least it held...", 0),
            ("ANNA: Well, I would say we are out of the woods.", 3000),
            ("ANNA: Got another", 9000),
            ("ANNA: We sure gave them a fight!", 11000),
            ("PRESS X TO CONTINUE", 20000),
            ("LEVEL 2", 22000));
        Assert.Equal("Well, I would say we are out of the woods.", sent[1]);
        Assert.Equal("We sure gave them a fight!", sent[3]);
        Assert.Equal("LEVEL 2", sent[5]);
    }

    /// Söz bağlayıcı bir sözcükle ya da virgülle yarıda kaldıysa devamı büyük harfle (özel adla) başlasa da birleşir.
    [Fact]
    public async Task OpenSentenceJoinsACapitalizedContinuation()
    {
        var (sent, _) = await Feed(
            ("Priestess: The carvings say the spear was hidden in\nthe caves beneath", 0),
            ("Priestess: Kephallonia when the temple was built!", 3000));
        Assert.Equal("The carvings say the spear was hidden in the caves beneath Kephallonia when the temple was built!", sent[1]);
    }

    [Fact]
    public async Task MisreadSpeakerNameIsNotPartOfTheSentence()
    {
        var (sent, shown) = await Feed(("Marta: Okay,", 0), ("arta: the gate is open now!", 1500));
        Assert.Equal("Okay, the gate is open now!", sent[1]);
        Assert.Equal("Marta: tr:Okay, the gate is open now!", shown[1]);
    }

    [Fact]
    public async Task RereadOfTheSameLineIsNotJoinedWithItself()
    {
        var (sent, _) = await Feed(
            ("Marko: I havent been okay", 0),
            ("Marko: I haven't been okay", 500),
            ("Marko: for a long time--", 2500));
        Assert.Equal("I haven't been okay", sent[1]);
        Assert.Equal("I havent been okay for a long time--", sent[2]);
    }

    [Fact]
    public void RepeatedLinesInOneReadingCollapse()
    {
        Assert.Equal("Kraven: A fate you will not share.",
            ContinuationTranslator.WithoutRepeatedLines("Kraven: A fate yowwill not share.\nKraven: A fate you will not share."));
        Assert.Equal("Where are you going?\n- Home.", ContinuationTranslator.WithoutRepeatedLines("Where are you going?\n- Home."));
        Assert.Equal("One line.", ContinuationTranslator.WithoutRepeatedLines(" One line. "));
        Assert.Equal("Tomas: Northern Supply Depot Entrance?",
            ContinuationTranslator.WithoutRepeatedLines("Tomas: Northern Supply Depot Entrance?\nrn Suply Depot Entrance?"));
        Assert.Equal("Take the north road.\nThen the south road.",
            ContinuationTranslator.WithoutRepeatedLines("Take the north road.\nThen the south road."));
    }
}
