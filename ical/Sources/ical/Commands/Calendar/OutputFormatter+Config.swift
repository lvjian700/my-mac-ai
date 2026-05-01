import Foundation

extension OutputFormatter {
    // MARK: - Config

    static func printConfig(_ snapshot: IcalConfigSnapshot, format: OutputFormat) {
        switch format {
        case .text:
            printConfigText(snapshot)
        case .json:
            printConfigJSON(snapshot)
        }
    }

    static func printAddConfig(_ snapshot: IcalConfigSnapshot, format: OutputFormat) {
        switch format {
        case .text:
            printAddConfigText(level: .effective, config: snapshot.effectiveAdd, path: nil)
        case .json:
            printJSON(addConfigJSON(level: .effective, config: snapshot.effectiveAdd, path: nil))
        }
    }

    private static func printConfigText(_ snapshot: IcalConfigSnapshot) {
        print("user: \(displayPath(snapshot.userPath.path))")
        printAddConfigText(level: .user, config: snapshot.user.add, path: nil)
        if let localPath = snapshot.localPath {
            print("")
            print("local: \(displayPath(localPath.path))")
            printAddConfigText(level: .local, config: snapshot.local.add, path: nil)
        } else {
            print("")
            print("local: not configured")
        }
        print("")
        print("effective:")
        printAddConfigText(level: .effective, config: snapshot.effectiveAdd, path: nil)
    }

    private static func printAddConfigText(level: ConfigLevel, config: AddCommandConfig, path: String?) {
        if let path {
            print("\(level.rawValue): \(path)")
        }
        print("  add.account: \(config.account ?? "(unset)")")
        print("  add.calendar: \(config.calendar ?? "(unset)")")
    }

    private static func printConfigJSON(_ snapshot: IcalConfigSnapshot) {
        struct ConfigJSON: Encodable {
            let user: AddConfigJSON
            let local: AddConfigJSON
            let effective: AddConfigJSON
        }

        printJSON(ConfigJSON(
            user: addConfigJSON(level: .user, config: snapshot.user.add, path: snapshot.userPath.path),
            local: addConfigJSON(level: .local, config: snapshot.local.add, path: snapshot.localPath?.path),
            effective: addConfigJSON(level: .effective, config: snapshot.effectiveAdd, path: nil)
        ))
    }

    private static func displayPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    private struct AddConfigJSON: Encodable {
        let level: String
        let path: String?
        let add: AddConfigValuesJSON
    }

    private struct AddConfigValuesJSON: Encodable {
        let account: String?
        let calendar: String?
    }

    private static func addConfigJSON(level: ConfigLevel, config: AddCommandConfig, path: String?) -> AddConfigJSON {
        AddConfigJSON(
            level: level.rawValue,
            path: path,
            add: AddConfigValuesJSON(account: config.account, calendar: config.calendar)
        )
    }
}
