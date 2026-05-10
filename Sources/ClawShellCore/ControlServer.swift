import Foundation

public enum ControlServerError: Error, Equatable {
    case unauthenticated
    case replayedEvent
    case rateLimited
    case unsupportedSchemaVersion(Int)
    case invalidRequest(String)
    case notRunning
}

public enum ControlCommand: Equatable, Sendable {
    case status
    case pause(duration: TimeInterval)
    case releaseNow
    case list
    case add(binary: String)
    case integrationsList
    case integrationsStatus
    case integrationsRemove(agentID: String)
    case integrationsEnableAuto(agentID: String)
    case helperStatus
    case helperRepair
    case uninstall(removeHelper: Bool, removeIntegrations: Bool)
}

public struct ControlRequest: Equatable, Sendable {
    public var schemaVersion: Int
    public var token: String
    public var eventID: String
    public var processID: Int32?
    public var clientTimestamp: Date?
    public var command: ControlCommand

    public init(
        schemaVersion: Int = 1,
        token: String,
        eventID: String = UUID().uuidString,
        processID: Int32? = nil,
        clientTimestamp: Date? = nil,
        command: ControlCommand
    ) {
        self.schemaVersion = schemaVersion
        self.token = token
        self.eventID = eventID
        self.processID = processID
        self.clientTimestamp = clientTimestamp
        self.command = command
    }
}

public struct ControlResponse: Equatable, Sendable {
    public var accepted: Bool
    public var receiptTimestamp: Date
    public var message: String

    public init(accepted: Bool, receiptTimestamp: Date, message: String) {
        self.accepted = accepted
        self.receiptTimestamp = receiptTimestamp
        self.message = message
    }
}

public protocol ControlCommandRouting {
    func route(_ command: ControlCommand, receivedAt: Date) throws -> ControlResponse
}

public final class ControlServer {
    public let token: String
    public let maxEventsPerWindow: Int
    public let rateLimitWindow: TimeInterval

    private let router: ControlCommandRouting
    private let now: () -> Date
    private var replayedEventIDs = Set<String>()
    private var rateBuckets: [RateLimitKey: [Date]] = [:]

    public init(
        token: String,
        router: ControlCommandRouting,
        maxEventsPerWindow: Int = 30,
        rateLimitWindow: TimeInterval = 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.token = token
        self.router = router
        self.maxEventsPerWindow = maxEventsPerWindow
        self.rateLimitWindow = rateLimitWindow
        self.now = now
    }

    public func handle(_ request: ControlRequest) throws -> ControlResponse {
        let receiptTime = now()

        guard request.schemaVersion == 1 else {
            throw ControlServerError.unsupportedSchemaVersion(request.schemaVersion)
        }

        guard request.token == token else {
            throw ControlServerError.unauthenticated
        }

        guard replayedEventIDs.insert(request.eventID).inserted else {
            throw ControlServerError.replayedEvent
        }

        try enforceRateLimit(for: request, at: receiptTime)
        return try router.route(request.command, receivedAt: receiptTime)
    }

    private func enforceRateLimit(for request: ControlRequest, at receiptTime: Date) throws {
        let key = RateLimitKey(tokenHash: StablePathHash.sha256(request.token), processID: request.processID)
        let cutoff = receiptTime.addingTimeInterval(-rateLimitWindow)
        let retained = (rateBuckets[key] ?? []).filter { $0 >= cutoff }

        guard retained.count < maxEventsPerWindow else {
            rateBuckets[key] = retained
            throw ControlServerError.rateLimited
        }

        rateBuckets[key] = retained + [receiptTime]
    }
}

public struct DefaultControlCommandRouter: ControlCommandRouting {
    public var statusProvider: () -> String

    public init(statusProvider: @escaping () -> String = { "ClawShell status unavailable" }) {
        self.statusProvider = statusProvider
    }

    public func route(_ command: ControlCommand, receivedAt: Date) throws -> ControlResponse {
        switch command {
        case .status:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: statusProvider())
        case .pause(let duration):
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Pause requested for \(Int(duration)) seconds")
        case .releaseNow:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Release requested")
        case .list:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "No sessions reported")
        case .add(let binary):
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Custom binary support is post-v1: \(binary)")
        case .integrationsList:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Integrations: claude-code, codex-cli")
        case .integrationsStatus:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Integration setup pending")
        case .integrationsRemove(let agentID):
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Remove integration requested: \(agentID)")
        case .integrationsEnableAuto(let agentID):
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Auto-integration enabled: \(agentID)")
        case .helperStatus:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Helper not installed")
        case .helperRepair:
            ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "Helper repair is unavailable in this build")
        case .uninstall(let removeHelper, let removeIntegrations):
            ControlResponse(
                accepted: true,
                receiptTimestamp: receivedAt,
                message: "Uninstall requested removeHelper=\(removeHelper) removeIntegrations=\(removeIntegrations)"
            )
        }
    }
}

private struct RateLimitKey: Hashable {
    var tokenHash: String
    var processID: Int32?
}
