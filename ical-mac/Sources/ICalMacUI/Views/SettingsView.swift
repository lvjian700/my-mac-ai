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
    @State private var apiKeySaveTask: Task<Void, Never>?

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
                        .onSubmit {
                            saveAPIKeyNow()
                        }
                }
                Picker("Model", selection: $model.modelName) {
                    ForEach(AppModel.supportedModelOptions) { option in
                        Text(option.label).tag(option.modelID)
                    }
                }
                .pickerStyle(.menu)
                .help("Select the OpenAI model used for calendar assistant replies.")
                .onChange(of: model.modelName) { _, _ in
                    model.saveModelSetting()
                }
            }

            Section("Calendar") {
                Picker("Default calendar", selection: $model.defaultCalendarTitle) {
                    Text("System Default").tag("")
                    ForEach(model.calendars.filter(\.allowsContentModifications)) { calendar in
                        Text("\(calendar.title) (\(calendar.accountName))").tag(calendar.title)
                    }
                }
                .onChange(of: model.defaultCalendarTitle) { _, _ in
                    model.saveDefaultCalendarSetting()
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
        .onChange(of: model.apiKeyDraft) { _, _ in
            scheduleAPIKeySave()
        }
        .onDisappear {
            saveAPIKeyNow()
        }
    }

    private func scheduleAPIKeySave() {
        guard hasLoadedAPIKey, !model.isUsingEnvAPIKey else { return }
        apiKeySaveTask?.cancel()
        apiKeySaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            model.saveAPIKeySetting()
        }
    }

    private func saveAPIKeyNow() {
        guard hasLoadedAPIKey, !model.isUsingEnvAPIKey else { return }
        apiKeySaveTask?.cancel()
        apiKeySaveTask = nil
        model.saveAPIKeySetting()
    }
}
