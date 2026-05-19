import AgentWakeCore

enum ClosedLidUserFacingCopy {
    static func safetyNotice(settings: SafetySettings) -> String {
        "AgentWake will turn off Lid-Closed Awake automatically if battery is at or below \(settings.batteryFloorPercent)%, direct sensor temperature returns a usable sample at or above \(settings.temperatureCutoffCelsius) C, the temperature provider cannot return a usable sample, or macOS reports critical thermal pressure. Plug into AC for long overnight runs."
    }
}
