import Foundation
import ServiceManagement

enum LaunchAtLoginController {
    enum DisplayState {
        case off
        case on
        case needsApproval
        case requiresInstalledApp
        case unknown
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var displayState: DisplayState {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .needsApproval
        case .notRegistered:
            return .off
        case .notFound:
            return .requiresInstalledApp
        @unknown default:
            return .unknown
        }
    }

    static var statusText: String {
        switch displayState {
        case .on:
            return "On"
        case .needsApproval:
            return "Needs approval in Login Items"
        case .requiresInstalledApp:
            return "Install in Applications to enable"
        case .unknown:
            return "Unknown"
        case .off:
            return ""
        }
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
