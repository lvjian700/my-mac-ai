import AppKit
import Testing
@testable import ICalMac

struct ComposerReturnKeyActionTests {
    @Test func plainReturnSendsMessage() {
        #expect(ComposerReturnKeyAction.action(keyCode: 36, modifierFlags: []) == .send)
    }

    @Test func shiftReturnInsertsNewline() {
        #expect(ComposerReturnKeyAction.action(keyCode: 36, modifierFlags: [.shift]) == .insertNewline)
    }

    @Test func keypadEnterSendsMessage() {
        #expect(ComposerReturnKeyAction.action(keyCode: 76, modifierFlags: [.numericPad]) == .send)
    }

    @Test func modifiedReturnKeepsDefaultHandling() {
        #expect(ComposerReturnKeyAction.action(keyCode: 36, modifierFlags: [.command]) == .ignore)
        #expect(ComposerReturnKeyAction.action(keyCode: 36, modifierFlags: [.option]) == .ignore)
        #expect(ComposerReturnKeyAction.action(keyCode: 36, modifierFlags: [.control]) == .ignore)
    }

    @Test func nonReturnKeyIsIgnored() {
        #expect(ComposerReturnKeyAction.action(keyCode: 0, modifierFlags: []) == .ignore)
    }
}
