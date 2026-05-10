import Foundation

public enum MenuBarItemKind: Equatable, Sendable {
    case status
    case placeholderState(ClawShellState)
    case settings
    case quit
}

public struct MenuBarItem: Equatable, Sendable {
    public let title: String
    public let detail: String?
    public let isEnabled: Bool
    public let kind: MenuBarItemKind

    public init(
        title: String,
        detail: String? = nil,
        isEnabled: Bool,
        kind: MenuBarItemKind
    ) {
        self.title = title
        self.detail = detail
        self.isEnabled = isEnabled
        self.kind = kind
    }
}

public struct MenuBarSnapshot: Equatable, Sendable {
    public let currentState: ClawShellState
    public let statusItemTitle: String
    public let items: [MenuBarItem]

    public init(
        currentState: ClawShellState,
        statusItemTitle: String,
        items: [MenuBarItem]
    ) {
        self.currentState = currentState
        self.statusItemTitle = statusItemTitle
        self.items = items
    }
}

public enum MenuBarModel {
    public static func snapshot(currentState: ClawShellState) -> MenuBarSnapshot {
        let stateItems = ClawShellState.allCases.map { state in
            MenuBarItem(
                title: state.menuTitle,
                detail: state.placeholderDetail,
                isEnabled: false,
                kind: .placeholderState(state)
            )
        }

        let items = [
            MenuBarItem(
                title: "Current: \(currentState.menuTitle)",
                detail: currentState.placeholderDetail,
                isEnabled: false,
                kind: .status
            )
        ] + stateItems + [
            MenuBarItem(
                title: "Settings...",
                isEnabled: true,
                kind: .settings
            ),
            MenuBarItem(
                title: "Quit ClawShell",
                isEnabled: true,
                kind: .quit
            )
        ]

        return MenuBarSnapshot(
            currentState: currentState,
            statusItemTitle: currentState.statusItemTitle,
            items: items
        )
    }
}
