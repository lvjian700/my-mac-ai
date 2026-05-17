import Foundation

public enum MemoryStoreError: LocalizedError, Equatable {
    case cannotCreateDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory(let path):
            return "Cannot create memory directory at \(path)."
        }
    }
}

public struct MemoryStore {
    public var memoryURL: URL
    public var snapshotURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".my-mac-ai/ical", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.memoryURL = rootURL.appendingPathComponent("memory.yaml")
        self.snapshotURL = rootURL.appendingPathComponent("session-memory.json")
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func readMemory() -> String {
        (try? String(contentsOf: memoryURL, encoding: .utf8)) ?? ""
    }

    public func writeMemory(_ content: String) throws {
        try ensureDirectoryExists(for: memoryURL)
        try content.write(to: memoryURL, atomically: true, encoding: .utf8)
    }

    public func readSnapshot() -> SessionSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? decoder.decode(SessionSnapshot.self, from: data)
    }

    public func writeSnapshot(_ snapshot: SessionSnapshot) throws {
        try ensureDirectoryExists(for: snapshotURL)
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    private func ensureDirectoryExists(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw MemoryStoreError.cannotCreateDirectory(directory.path)
        }
    }
}
