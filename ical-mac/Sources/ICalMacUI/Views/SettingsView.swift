import SwiftUI

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(AppModel.preview())
        .frame(width: 400)
}
#endif

public struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hasLoadedAPIKey = false

    public init() {}

    public var body: some View {
        Form {
            Section("OpenAI") {
                if model.isUsingEnvAPIKey {
                    LabeledContent("API Key") {
                        Label("Using OPENAI_API_KEY", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    SecureField("API key", text: $model.apiKeyDraft)
                }
                TextField("Model", text: $model.modelName)
                    .help("e.g. gpt-4.5-mini, gpt-4o, o3")
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
        .onAppear {
            guard !hasLoadedAPIKey else { return }
            hasLoadedAPIKey = true
            model.loadAPIKeyDraft()
        }
    }
}
