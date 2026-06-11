import SwiftUI

#if DEBUG
#Preview("No API key") {
    SettingsView()
        .environmentObject(AppModel.preview(apiKeyStatus: .unknown, apiKeyDraft: ""))
        .frame(width: 550, height: 380)
}

#Preview("Test button") {
    SettingsView()
        .environmentObject(AppModel.preview(apiKeyStatus: .unknown))
        .frame(width: 550, height: 380)
}

#Preview("Testing…") {
    SettingsView()
        .environmentObject(AppModel.preview(apiKeyStatus: .testing))
        .frame(width: 550, height: 380)
}

#Preview("Connected") {
    SettingsView()
        .environmentObject(AppModel.preview(apiKeyStatus: .connected))
        .frame(width: 550, height: 380)
}

#Preview("Failed") {
    SettingsView()
        .environmentObject(AppModel.preview(apiKeyStatus: .failed("Invalid API key — check your key and try again.")))
        .frame(width: 550, height: 380)
}

#Preview("Show weekends on") {
    SettingsView()
        .environmentObject(AppModel.preview(apiKeyStatus: .connected, showWeekends: true))
        .frame(width: 550, height: 380)
}
#endif

public struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hasLoadedAPIKey = false
    @State private var apiKeySaveTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        Form {
            Section("OpenAI Config") {
                LabeledContent {
                    HStack(spacing: 8) {
                        if model.isUsingEnvAPIKey {
                            Text("Loaded from environment")
                                .foregroundStyle(.secondary)
                        } else {
                            SecureField("", text: $model.apiKeyDraft)
                                
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { saveAPIKeyNow() }
                        }
                        connectivityControl
                    }
                    
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                } label: {
                    Label("API Key", systemImage: "sparkles")
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                }.padding(.top, 5)

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
                    Toggle("", isOn: $model.showWeekends)
                        .labelsHidden()
                        .onChange(of: model.showWeekends) { _, _ in
                            model.saveShowWeekendsSetting()
                        }
                } label: {
                    Label("Show weekends", systemImage: "calendar.badge.plus")
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
