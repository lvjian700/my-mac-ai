import Foundation

// MARK: - Stdout capture helper

/// Redirects stdout to a pipe, runs `body`, then restores stdout and returns the captured string.
@MainActor
func captureStdout(_ body: @MainActor () -> Void) -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    body()

    // Flush Swift's buffered output
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

// MARK: - Date helper

/// Build a fixed Date from components (local time zone).
func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    return Calendar.current.date(from: comps)!
}

// MARK: - JSON parse helper

/// Parse JSON output into an array of dictionaries.
func parseJSONOutput(_ output: String) throws -> [[String: Any]] {
    let data = output.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data)
    guard let array = parsed as? [[String: Any]] else {
        throw NSError(domain: "Test", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Expected JSON array"])
    }
    return array
}
