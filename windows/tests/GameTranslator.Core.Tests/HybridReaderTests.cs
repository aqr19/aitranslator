// SPDX-License-Identifier: AGPL-3.0-only

namespace GameTranslator.Core.Tests;

public class HybridReaderTests
{
    /// <summary>Sırayla verilen metinleri döndüren, kaç kez çağrıldığını sayan okuyucu.</summary>
    private sealed class Scripted(params string[] texts) : ITextReader
    {
        private int next;
        public int Calls { get; private set; }
        public bool Throws { get; set; }

        public string Read(Frame image)
        {
            Calls++;
            if (Throws) throw new InvalidOperationException("model yok");
            return texts[Math.Min(next++, texts.Length - 1)];
        }
    }

    private static readonly Frame Image = Frame.Blank(64, 64);

    private static HybridReader Hybrid(Scripted fast, Scripted strong, Func<long>? clock = null) =>
        new(fast, strong, clock) { LooksMisread = text => text.Contains("zz", StringComparison.Ordinal) };

    [Fact]
    public void CleanReadingNeverRunsTheStrongReader()
    {
        var (fast, strong) = (new Scripted("Hold the gate."), new Scripted("Hold the gate."));
        var reader = Hybrid(fast, strong);
        for (var i = 0; i < 5; i++) Assert.Equal("Hold the gate.", reader.ReadLines(Image, deep: true).Text);
        Assert.Equal(0, strong.Calls);
        Assert.Equal(0, reader.StrongRuns);
    }

    [Fact]
    public void MisreadLineIsRescuedByTheStrongReader()
    {
        var log = new List<string>();
        var reader = Hybrid(new Scripted("Hozzd the gzzte."), new Scripted("Hold the gate."));
        reader.Log = log.Add;
        Assert.Equal("Hold the gate.", reader.ReadLines(Image, deep: true).Text);
        Assert.Equal(1, reader.StrongWins);
        Assert.Contains(log, line => line.StartsWith("güçlü okuyucu: \"Hozzd the gzzte.\" → \"Hold the gate.\"", StringComparison.Ordinal));
    }

    /// Güçlü okuyucu temiz ama satırın küçük bir parçasını okuduysa hızlı okumanın yerine geçmez.
    [Fact]
    public void CleanFragmentDoesNotReplaceAMostlyRightLine()
    {
        var reader = Hybrid(new Scripted("We leave at dawn, so get some rezzt."), new Scripted("the"));
        Assert.Equal("We leave at dawn, so get some rezzt.", reader.ReadLines(Image, deep: true).Text);
        Assert.Equal(0, reader.StrongWins);
    }

    [Fact]
    public void FastReadingStaysWhenTheStrongOneIsNotBetter()
    {
        // Güçlü okuyucu daha kötü ya da boş okursa hızlı okuma kalır; eşitlikte de.
        Assert.Equal("Hold the gzzte now.", Hybrid(new Scripted("Hold the gzzte now."), new Scripted("H0$d")).ReadLines(Image, true).Text);
        Assert.Equal("Hold the gzzte now.", Hybrid(new Scripted("Hold the gzzte now."), new Scripted("")).ReadLines(Image, true).Text);
        var reader = Hybrid(new Scripted("Hold the gzzte."), new Scripted("Hold the gzzte."));
        Assert.Equal("Hold the gzzte.", reader.ReadLines(Image, true).Text);
        Assert.Equal(0, reader.StrongWins);
        Assert.Equal(1, reader.StrongRuns);
    }

    /// Hızlı okuyucu boş dönünce güçlü okuyucu her karede değil, aralıklı denenir.
    [Fact]
    public void EmptyFramesProbeTheStrongReaderOnlyNowAndThen()
    {
        long time = 0;
        var (fast, strong) = (new Scripted(""), new Scripted(""));
        var reader = Hybrid(fast, strong, () => time);
        for (var i = 0; i < 20; i++)
        {
            Assert.Equal("", reader.ReadLines(Image, deep: true).Text);
            time += 100;
        }
        // 2 saniyede en çok dört deneme (600 ms'de bir).
        Assert.InRange(strong.Calls, 3, 4);
    }

    [Fact]
    public void TextTheFastReaderCannotSeeIsFoundByTheProbe()
    {
        long time = 0;
        var reader = Hybrid(new Scripted(""), new Scripted("We leave at dawn."), () => time);
        Assert.Equal("We leave at dawn.", reader.ReadLines(Image, deep: true).Text);
        // Aralık dolmadan yeniden denenmez; hızlı okuyucunun boş okuması döner.
        time += 100;
        Assert.Equal("", reader.ReadLines(Image, deep: true).Text);
        time += HybridReader.ProbeEveryMs;
        Assert.Equal("We leave at dawn.", reader.ReadLines(Image, deep: true).Text);
    }

    [Fact]
    public void FailingStrongReaderDoesNotBreakReading()
    {
        var reader = Hybrid(new Scripted("Hold the gzzte."), new Scripted("x") { Throws = true });
        Assert.Equal("Hold the gzzte.", reader.ReadLines(Image, deep: true).Text);
    }
}
