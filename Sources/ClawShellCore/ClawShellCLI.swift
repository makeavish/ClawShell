import Foundation

public protocol ControlClient {
    func send(_ command: ControlCommand) throws -> ControlResponse
}

public struct ClawShellCLI {
    public var client: ControlClient

    public init(client: ControlClient) {
        self.client = client
    }

    public func run(arguments: [String]) throws -> String {
        let command = try parse(arguments: Array(arguments.dropFirst()))
        let response = try client.send(command)
        return response.message
    }

    public func parse(arguments: [String]) throws -> ControlCommand {
        guard let first = arguments.first else {
            throw ControlServerError.invalidRequest("missing command")
        }

        switch first {
        case "status":
            return .status
        case "pause":
            guard let duration = arguments.dropFirst().first.flatMap(parseDuration) else {
                throw ControlServerError.invalidRequest("pause requires a duration like 1h or 15m")
            }
            return .pause(duration: duration)
        case "release":
            guard arguments.dropFirst().first == "now" else {
                throw ControlServerError.invalidRequest("release requires `now`")
            }
            return .releaseNow
        case "list":
            return .list
        case "add":
            guard let binary = arguments.dropFirst().first else {
                throw ControlServerError.invalidRequest("add requires a binary path")
            }
            return .add(binary: binary)
        case "integrations":
            return try parseIntegrations(Array(arguments.dropFirst()))
        case "helper":
            return try parseHelper(Array(arguments.dropFirst()))
        case "uninstall":
            return .uninstall(
                removeHelper: arguments.contains("--remove-helper"),
                removeIntegrations: arguments.contains("--remove-integrations")
            )
        default:
            throw ControlServerError.invalidRequest("unknown command: \(first)")
        }
    }

    private func parseIntegrations(_ arguments: [String]) throws -> ControlCommand {
        guard let first = arguments.first else {
            throw ControlServerError.invalidRequest("integrations requires a subcommand")
        }

        switch first {
        case "list":
            return .integrationsList
        case "status":
            return .integrationsStatus
        case "remove":
            guard let agent = arguments.dropFirst().first else {
                throw ControlServerError.invalidRequest("integrations remove requires an agent")
            }
            return .integrationsRemove(agentID: agent)
        case "enable-auto":
            guard let agent = arguments.dropFirst().first else {
                throw ControlServerError.invalidRequest("integrations enable-auto requires an agent")
            }
            return .integrationsEnableAuto(agentID: agent)
        default:
            throw ControlServerError.invalidRequest("unknown integrations subcommand: \(first)")
        }
    }

    private func parseHelper(_ arguments: [String]) throws -> ControlCommand {
        guard let first = arguments.first else {
            throw ControlServerError.invalidRequest("helper requires a subcommand")
        }

        switch first {
        case "status":
            return .helperStatus
        case "repair":
            return .helperRepair
        default:
            throw ControlServerError.invalidRequest("unknown helper subcommand: \(first)")
        }
    }

    private func parseDuration(_ value: String) -> TimeInterval? {
        guard let suffix = value.last else {
            return nil
        }

        let numberPart = value.dropLast()
        guard let amount = Double(numberPart), amount > 0 else {
            return nil
        }

        switch suffix {
        case "m":
            return amount * 60
        case "h":
            return amount * 60 * 60
        case "d":
            return amount * 24 * 60 * 60
        default:
            return nil
        }
    }
}

public struct LocalControlClient: ControlClient {
    public let runtimeStore: ControlRuntimeStore

    public init(runtimeStore: ControlRuntimeStore = ControlRuntimeStore()) {
        self.runtimeStore = runtimeStore
    }

    public func send(_ command: ControlCommand) throws -> ControlResponse {
        guard runtimeStore.fileManager.fileExists(atPath: runtimeStore.paths.controlSocketURL.path) else {
            throw ControlServerError.notRunning
        }

        _ = try runtimeStore.loadToken()
        throw ControlServerError.notRunning
    }
}
