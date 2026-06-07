import SwiftUI

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(AppModel.preview())
        .frame(height: 380)
        .frame(width: 550)
}
#endif

public struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hasLoadedAPIKey = false
    @State private var apiKeySaveTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        Form {
            Section("AI") {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OpenAI")
                            .font(.headline)
                        if model.isUsingEnvAPIKey {
                            Text("API key loaded from environment")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            SecureField("Paste API key…", text: $model.apiKeyDraft)
                                .onSubmit { saveAPIKeyNow() }
                        }
                    }
                    Spacer()
                    connectivityControl
                }

                LabeledContent {
                    Picker("", selection: $model.modelName) {
                        ForEach(AppModel.supportedModelOptions) { option in
                            Text(option.label).tag(option.modelID)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: model.modelName) { _, _ in
                        model.saveModelSetting()
                    }
                } label: {
                    Label("Model", systemImage: "cpu")
                }
            }

            Section("Calendar") {
                LabeledContent {
                    Picker("", selection: $model.defaultCalendarTitle) {
                        Text("System Default").tag("")
                        ForEach(model.calendars.filter(\.allowsContentModifications)) { calendar in
                            Text("\(calendar.title) (\(calendar.accountName))").tag(calendar.title)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: model.defaultCalendarTitle) { _, _ in
                        model.saveDefaultCalendarSetting()
                    }
                } label: {
                    Label("Default calendar", systemImage: "calendar")
                }

                LabeledContent {
                    Button {
                        Task { await model.refreshCalendar() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Label(model.statusText, systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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

    @ViewBuilder
    private var connectivityControl: some View {
        switch model.apiKeyStatus {
        case .unknown:
            Button("Test") { Task { await model.testAPIKeyConnectivity() } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .connected:
            statusBadge("Connected", color: .green)
        case .failed(let msg):
            statusBadge("Failed", color: .red)
                .help(msg)
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func scheduleAPIKeySave() {
        guard hasLoadedAPIKey, !model.isUsingEnvAPIKey else { return }
        apiKeySaveTask?.cancel()
        apiKeySaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            model.saveAPIKeySetting()
            await model.testAPIKeyConnectivity()
        }
    }

    private func saveAPIKeyNow() {
        guard hasLoadedAPIKey, !model.isUsingEnvAPIKey else { return }
        apiKeySaveTask?.cancel()
        apiKeySaveTask = nil
        model.saveAPIKeySetting()
        Task { await model.testAPIKeyConnectivity() }
    }
}
