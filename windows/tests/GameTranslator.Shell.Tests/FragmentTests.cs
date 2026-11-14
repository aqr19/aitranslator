// SPDX-License-Identifier: AGPL-3.0-only

using GameTranslator.Shell;
using Xunit;

namespace GameTranslator.Shell.Tests;

public class FragmentTests
{
    [Theory]
    [InlineData(",to me.", true)]
    [InlineData("pin Ito me.", true)]
    [InlineData("Yeah?", true)]
    [InlineData("Sit?", true)]
    [InlineData("who are gonna need help when they come", false)]
    [InlineData("V: Yeah?", false)]
    [InlineData("Get the car.", false)]
    [InlineData("Yeah?\nYours ain't to me.", false)]
    public void ShortMidSentencePiecesAreFragments(string text, bool fragment) =>
        Assert.Equal(fragment, AppController.LooksLikeFragment(text));
}
