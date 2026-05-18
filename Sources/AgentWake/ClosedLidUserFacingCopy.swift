import AgentWakeCore

enum ClosedLidUserFacingCopy {
    static func safetyNotice(settings: SafetySettings) -> String {
        "AgentWake will turn off Lid-Closed Awake automatically if battery is at or below \(settings.batteryFloorPercent)% or macOS reports critical thermal pressure. Direct sensor temperature is saved at \(settings.temperatureCutoffCelsius) C, but that provider isn't wired yet, so plug into AC for long overnight runs."
    }
}
