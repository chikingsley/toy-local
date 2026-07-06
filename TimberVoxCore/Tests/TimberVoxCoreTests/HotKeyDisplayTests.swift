import Sauce
import Testing

@testable import TimberVoxCore

struct HotKeyDisplayTests {
  @Test func displaysGraveKeyAsBacktick() {
    #expect(Key.grave.toString == "`")
  }

  @Test func displaysCommonPunctuationKeys() {
    #expect(Key.minus.toString == "-")
    #expect(Key.equal.toString == "=")
    #expect(Key.leftBracket.toString == "[")
    #expect(Key.rightBracket.toString == "]")
    #expect(Key.semicolon.toString == ";")
    #expect(Key.quote.toString == "'")
  }

  @Test func displaysNavigationAndDeleteKeys() {
    #expect(Key.return.toString == "↩")
    #expect(Key.tab.toString == "⇥")
    #expect(Key.delete.toString == "⌫")
    #expect(Key.forwardDelete.toString == "⌦")
    #expect(Key.pageUp.toString == "⇞")
    #expect(Key.pageDown.toString == "⇟")
  }

  @Test func displaysKeypadKeysDistinctly() {
    #expect(Key.keypadZero.toString == "Num 0")
    #expect(Key.keypadPlus.toString == "Num +")
    #expect(Key.keypadEnter.toString == "Num ↩")
  }

  @Test func displaysLayoutSpecificKeys() {
    #expect(Key.yen.toString == "¥")
    #expect(Key.kana.toString == "かな")
    #expect(Key.eisu.toString == "英数")
    #expect(Key.section.toString == "§")
  }
}
