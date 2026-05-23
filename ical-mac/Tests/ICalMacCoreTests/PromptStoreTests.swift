import Foundation
import Testing
@testable import ICalMacCore

struct PromptStoreTests {
    @Test func systemPromptUsesNativeMacAppInstructions() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(
            memory: "",
            snapshot: nil,
            now: makeDate(year: 2026, month: 5, day: 18, hour: 10),
            timeZone: TimeZone(identifier: "Australia/Melbourne")!
        )

        #expect(prompt.contains("native ical-mac app"))
        #expect(prompt.contains("provided Apple Calendar tools"))
        #expect(prompt.contains("write the full YAML memory file"))
        #expect(prompt.contains("Today is 2026-05-18. Timezone: Australia/Melbourne."))
    }

    @Test func systemPromptDoesNotIncludeCliSkillWorkflow() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(memory: "", snapshot: nil)

        #expect(!prompt.contains("ical events"))
        #expect(!prompt.contains("ical add"))
        #expect(!prompt.contains("scripts/ical-memory"))
        #expect(!prompt.contains("Always call the `ical` CLI"))
        #expect(!prompt.contains("Calendar Rules Reference"))
    }
}
