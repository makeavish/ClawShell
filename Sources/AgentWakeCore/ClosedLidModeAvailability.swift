import Foundation

public enum ClosedLidModeGate: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case helperLifecycle
    case temperatureProvider
    case primitiveMatrix
    case packagingConsent

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .helperLifecycle:
            "Helper lifecycle"
        case .temperatureProvider:
            "Temperature provider"
        case .primitiveMatrix:
            "Closed-lid lifecycle matrix"
        case .packagingConsent:
            "Install and consent flow"
        }
    }

    public var detail: String {
        switch self {
        case .helperLifecycle:
            "install, enable, disable, repair, update, and cleanup still need final validation"
        case .temperatureProvider:
            "direct sensor sampling is wired, but scale, coverage, and timeout validation still need final app evidence"
        case .primitiveMatrix:
            "AC power, display-topology, reboot, and app lifecycle cases still need final app evidence"
        case .packagingConsent:
            "release packaging must prove the helper is never activated before explicit user consent"
        }
    }

}

public struct ClosedLidModeStatus: Equatable, Sendable {
    public var pendingGates: [ClosedLidModeGate]

    public init(pendingGates: [ClosedLidModeGate] = ClosedLidModeGate.allCases) {
        self.pendingGates = pendingGates
    }

    public var isAvailable: Bool {
        pendingGates.isEmpty
    }

    public var title: String {
        isAvailable ? "Closed-Lid Mode available" : "Closed-Lid Mode unavailable"
    }

    public var summary: String {
        if isAvailable {
            return "Closed-Lid Mode is ready to enable."
        }

        return "Blocked by \(pendingGates.count) check\(pendingGates.count == 1 ? "" : "s")."
    }

    public var detail: String {
        if isAvailable {
            return "All helper, temperature, lifecycle, and install-consent checks are complete."
        }

        return pendingGates.map { "\($0.title): \($0.detail)" }.joined(separator: "\n")
    }

    public var settingsDetail: String {
        if isAvailable {
            return "Closed-Lid Mode is ready to enable after user consent."
        }

        return "Closed-Lid Mode is disabled until these checks pass: \(pendingGates.map(\.title).joined(separator: ", "))."
    }

    public func commandMessage(_ command: String) -> String {
        if isAvailable {
            return "Closed-Lid Mode \(command) ready: all required checks are complete."
        }

        let header: String
        if command == "status" {
            header = "\(title): \(summary)"
        } else {
            header = "Closed-Lid Mode \(command) unavailable: \(summary)"
        }

        return ([header, "Pending checks:"] + pendingGates.map { "- \($0.title): \($0.detail)" }).joined(separator: "\n")
    }
}

public enum ClosedLidModeAvailability {
    public static let currentStatus = ClosedLidModeStatus()

    public static var unavailableTitle: String {
        currentStatus.title
    }

    public static var unavailableDetail: String {
        currentStatus.detail
    }

    public static var settingsDetail: String {
        currentStatus.settingsDetail
    }

    public static func helperCommandMessage(_ command: String) -> String {
        currentStatus.commandMessage(command)
    }
}

@available(*, deprecated, renamed: "ClosedLidModeAvailability")
public typealias BagModeAvailability = ClosedLidModeAvailability
