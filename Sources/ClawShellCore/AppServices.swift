import Foundation

public final class AgentMonitor: StubLifecycleComponent {
    public init() {
        super.init(componentName: "AgentMonitor")
    }
}

public final class AssertionManager: StubLifecycleComponent {
    public init() {
        super.init(componentName: "AssertionManager")
    }
}

public final class IntegrationManager: StubLifecycleComponent {
    public init() {
        super.init(componentName: "IntegrationManager")
    }
}

public struct ClawShellSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var normalSleepProtectionEnabled: Bool

    public init(
        launchAtLogin: Bool = false,
        normalSleepProtectionEnabled: Bool = true
    ) {
        self.launchAtLogin = launchAtLogin
        self.normalSleepProtectionEnabled = normalSleepProtectionEnabled
    }
}

public final class SettingsStore: StubLifecycleComponent {
    public private(set) var settings: ClawShellSettings

    public init(settings: ClawShellSettings = ClawShellSettings()) {
        self.settings = settings
        super.init(componentName: "SettingsStore")
    }
}

public enum LogEvent: Equatable, Sendable {
    case appStarted
    case appStopped
    case stateChanged(ClawShellState)
}

public final class LogStore: StubLifecycleComponent {
    public private(set) var events: [LogEvent]

    public init(events: [LogEvent] = []) {
        self.events = events
        super.init(componentName: "LogStore")
    }

    public func append(_ event: LogEvent) {
        events.append(event)
    }
}

public final class ClawShellServices {
    public let agentMonitor: AgentMonitor
    public let assertionManager: AssertionManager
    public let integrationManager: IntegrationManager
    public let settingsStore: SettingsStore
    public let logStore: LogStore

    public init(
        agentMonitor: AgentMonitor = AgentMonitor(),
        assertionManager: AssertionManager = AssertionManager(),
        integrationManager: IntegrationManager = IntegrationManager(),
        settingsStore: SettingsStore = SettingsStore(),
        logStore: LogStore = LogStore()
    ) {
        self.agentMonitor = agentMonitor
        self.assertionManager = assertionManager
        self.integrationManager = integrationManager
        self.settingsStore = settingsStore
        self.logStore = logStore
    }

    public var lifecycleComponents: [any AppLifecycleComponent] {
        [
            agentMonitor,
            assertionManager,
            integrationManager,
            settingsStore,
            logStore
        ]
    }

    public func startAll() {
        lifecycleComponents.forEach { $0.start() }
        logStore.append(.appStarted)
    }

    public func stopAll() {
        logStore.append(.appStopped)
        lifecycleComponents.reversed().forEach { $0.stop() }
    }
}
