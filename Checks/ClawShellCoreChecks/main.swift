import ClawShellCore
import Foundation

@main
struct ClawShellCoreChecks {
    static func main() throws {
        try snapshotIncludesAllPlaceholderStates()
        try snapshotNamesTheCurrentState()
        try lifecycleComponentsCanStartAndStopTogether()

        print("ClawShellCoreChecks passed")
    }

    private static func snapshotIncludesAllPlaceholderStates() throws {
        let snapshot = MenuBarModel.snapshot(currentState: .idle)

        let placeholderStates = snapshot.items.compactMap { item -> ClawShellState? in
            guard case let .placeholderState(state) = item.kind else {
                return nil
            }

            return state
        }

        try check(
            placeholderStates == ClawShellState.allCases,
            "Expected all placeholder states in declaration order"
        )

        let placeholderTitles = snapshot.items.compactMap { item -> String? in
            guard case .placeholderState = item.kind else {
                return nil
            }

            return item.title
        }

        try check(
            placeholderTitles == ["Idle", "Active", "Bag Mode", "Paused"],
            "Expected menu placeholders for idle, active, Bag Mode, and paused"
        )
    }

    private static func snapshotNamesTheCurrentState() throws {
        let snapshot = MenuBarModel.snapshot(currentState: .bagMode)

        try check(snapshot.currentState == .bagMode, "Expected Bag Mode as current state")
        try check(snapshot.statusItemTitle == "ClawShell Bag", "Expected Bag Mode status item title")
        try check(snapshot.items.first?.title == "Current: Bag Mode", "Expected current-state menu row")
        try check(snapshot.items.first?.detail == "Closed-lid guarded mode", "Expected Bag Mode placeholder detail")
    }

    private static func lifecycleComponentsCanStartAndStopTogether() throws {
        let services = ClawShellServices()

        services.startAll()
        try check(
            services.lifecycleComponents.allSatisfy { $0.runState == .started },
            "Expected all lifecycle components to start"
        )
        try check(services.logStore.events == [.appStarted], "Expected appStarted log event")

        services.stopAll()
        try check(
            services.lifecycleComponents.allSatisfy { $0.runState == .stopped },
            "Expected all lifecycle components to stop"
        )
        try check(
            services.logStore.events == [.appStarted, .appStopped],
            "Expected appStarted and appStopped log events"
        )
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw CheckFailure(message)
        }
    }
}

struct CheckFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
