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
        #expect(prompt.contains("provided calendar tools"))
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

    @Test func systemPromptIncludesEventCategoryTitleRules() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(memory: "", snapshot: nil)

        #expect(prompt.contains("When creating events, choose the title prefix"))
        #expect(prompt.contains("Focus - ..."))
        #expect(prompt.contains("Focus time - ..."))
        #expect(prompt.contains("Catchup - ..."))
        #expect(prompt.contains("Sync - ..."))
        #expect(prompt.contains("Tech Huddle - ..."))
        #expect(prompt.contains("Support - ..."))
        #expect(prompt.contains("Cop - ..."))
        #expect(prompt.contains("Oncall - ..."))
        #expect(prompt.contains("Lunch - ..."))
        #expect(prompt.contains("Personal - ..."))
        #expect(prompt.contains("Break - ..."))
        #expect(prompt.contains("Offscreen - ..."))
        #expect(prompt.contains("Out of office - ..."))
        #expect(!prompt.contains("Force - ..."))
    }
}
