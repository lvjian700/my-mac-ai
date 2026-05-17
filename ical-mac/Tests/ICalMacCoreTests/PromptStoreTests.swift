import Foundation
import Testing
@testable import ICalMacCore

struct PromptStoreTests {
    @Test func promptLoaderStripsFrontmatterAndCommands() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let references = root.appendingPathComponent("references", isDirectory: true)
        try FileManager.default.createDirectory(at: references, withIntermediateDirectories: true)
        try """
        ---
        name: ical
        ---
        # Cali

        Keep it short.

        ## Commands
        ical events --format json

        ## Memory
        Use rules.
        """.write(to: root.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "Calendar rules here.".write(to: references.appendingPathComponent("calendar_rules.md"), atomically: true, encoding: .utf8)
        let store = PromptStore(skillDirectory: root)

        let prompt = store.loadSkillPrompt()

        #expect(prompt.contains("Keep it short."))
        #expect(!prompt.contains("ical events --format json"))
        #expect(prompt.contains("## Memory"))
    }
}
