import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Anthropic") {
                SecureField("API key", text: $model.apiKeyDraft)
                TextField("Model", text: $model.modelName)
                Button("Save Settings") {
                    model.saveSettings()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }

            Section("Calendar") {
                Picker("Default calendar", selection: $model.defaultCalendarTitle) {
                    Text("System Default").tag("")
                    ForEach(model.calendars.filter(\.allowsContentModifications)) { calendar in
                        Text("\(calendar.title) (\(calendar.accountName))").tag(calendar.title)
                    }
                }
                Text(model.statusText)
                    .foregroundStyle(.secondary)
                Button("Refresh Calendar") {
                    Task { await model.refreshCalendar() }
                }
            }
        }
        .padding()
    }
}
