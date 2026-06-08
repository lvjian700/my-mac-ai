import Foundation
import Testing
@testable import ICalMac

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

    @Test func systemPromptUsesConversationalNonMarkdownResponseStyle() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(memory: "", snapshot: nil)

        #expect(prompt.contains("Write like a human assistant"))
        #expect(prompt.contains("Do not use Markdown formatting"))
        #expect(prompt.contains("Mention times plainly in natural sentences"))
        #expect(!prompt.contains("Highlight times with markdown bold text"))
    }

    @Test func systemPromptTakesClearCalendarActionsWithoutExtraConfirmation() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(memory: "", snapshot: nil)

        #expect(prompt.contains("Default to taking action when the user's intent and required details are clear"))
        #expect(prompt.contains("Do not ask for an extra confirmation just to be polite"))
        #expect(prompt.contains("Ask one concise clarifying question only when a required detail is missing"))
        #expect(prompt.contains("If a conflict check shows no meaningful conflict"))
        #expect(prompt.contains("still create or update the event"))
        #expect(prompt.contains("say it needs their attention"))
        #expect(!prompt.contains("ask before scheduling over it"))
    }

    @Test func systemPromptIncludesCreateEventDurationShorthand() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(memory: "", snapshot: nil)

        #expect(prompt.contains("short: 15 mins"))
        #expect(prompt.contains("normal: 30 mins"))
        #expect(prompt.contains("long: 1 hour"))
        #expect(prompt.contains("If the user gives a start time but no duration or end time"))
        #expect(prompt.contains("use normal as the default duration"))
    }

    @Test func systemPromptIncludesDeleteEventGuidance() throws {
        let store = PromptStore()

        let prompt = store.buildSystemPrompt(memory: "", snapshot: nil)

        #expect(prompt.contains("Delete events with delete_event only when the target event is unambiguous"))
        #expect(prompt.contains("If multiple events could match"))
        #expect(prompt.contains("ask one concise question before deleting"))
    }
}
