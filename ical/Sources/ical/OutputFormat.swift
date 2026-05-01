import ArgumentParser

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case text, json
}
