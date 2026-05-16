import Foundation

public enum PowerSource: String, Equatable, Sendable {
    case ac
    case battery
    case unknown
}

public enum PowerSourceReader {
    public static func current() -> PowerSource {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .unknown
        }

        guard process.terminationStatus == 0 else {
            return .unknown
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parse(pmsetBatteryOutput: output)
    }

    public static func parse(pmsetBatteryOutput output: String) -> PowerSource {
        if output.localizedCaseInsensitiveContains("Battery Power") {
            return .battery
        }

        if output.localizedCaseInsensitiveContains("AC Power") {
            return .ac
        }

        return .unknown
    }
}
