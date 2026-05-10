import Foundation

#if canImport(Testing)
import Testing
@testable import ClawShellCore

struct ControlServerTests {
    @Test func runtimeStoreCreatesPrivateDirectoryAndRotatingToken() throws {
        try runRuntimeStoreCreatesPrivateDirectoryAndRotatingToken()
    }

    @Test func controlServerRejectsAuthReplayAndRateLimitFailures() throws {
        try runControlServerRejectsAuthReplayAndRateLimitFailures()
    }

    @Test func serverUsesReceiptTimeInsteadOfClientTimestamp() throws {
        try runServerUsesReceiptTimeInsteadOfClientTimestamp()
    }

    @Test func cliParsesCommandsAndSendsThroughClient() throws {
        try runCLIParsesCommandsAndSendsThroughClient()
    }
}

#elseif canImport(XCTest)
import XCTest
@testable import ClawShellCore

final class ControlServerTests: XCTestCase {
    func testRuntimeStoreCreatesPrivateDirectoryAndRotatingToken() throws {
        try runRuntimeStoreCreatesPrivateDirectoryAndRotatingToken()
    }

    func testControlServerRejectsAuthReplayAndRateLimitFailures() throws {
        try runControlServerRejectsAuthReplayAndRateLimitFailures()
    }

    func testServerUsesReceiptTimeInsteadOfClientTimestamp() throws {
        try runServerUsesReceiptTimeInsteadOfClientTimestamp()
    }

    func testCLIParsesCommandsAndSendsThroughClient() throws {
        try runCLIParsesCommandsAndSendsThroughClient()
    }
}

#else
#error("This toolchain does not provide Testing or XCTest. Run `swift run ClawShellCoreChecks` for portable checks.")
#endif

#if canImport(Testing) || canImport(XCTest)
private func runRuntimeStoreCreatesPrivateDirectoryAndRotatingToken() throws {
    let paths = try makeTemporaryPaths()
    defer { try? FileManager.default.removeItem(at: paths.applicationSupportDirectory) }

    let store = ControlRuntimeStore(paths: paths)
    let firstToken = try store.rotateToken()
    let secondToken = try store.rotateToken()
    let persistedToken = try store.loadToken()
    let runtimeMode = try store.runtimeDirectoryMode()
    let tokenMode = try store.tokenFileMode()

    try check(firstToken != secondToken, "Expected hook token to rotate per launch")
    try check(persistedToken == secondToken, "Expected latest hook token to be persisted")
    try check(runtimeMode == 0o700, "Expected runtime directory mode 0700")
    try check(tokenMode == 0o600, "Expected hook token mode 0600")
    try check(paths.controlSocketURL.path.hasSuffix("run/clawshell.sock"), "Expected canonical socket path")
}

private func runControlServerRejectsAuthReplayAndRateLimitFailures() throws {
    let now = Date(timeIntervalSince1970: 5_000)
    let router = RecordingRouter()
    let server = ControlServer(
        token: "secret",
        router: router,
        maxEventsPerWindow: 2,
        rateLimitWindow: 60,
        now: { now }
    )

    try expectThrows(ControlServerError.unauthenticated) {
        _ = try server.handle(ControlRequest(token: "wrong", eventID: "bad", command: .releaseNow))
    }
    try check(router.commands.isEmpty, "Expected unauthenticated commands not to reach the router")

    _ = try server.handle(ControlRequest(token: "secret", eventID: "a", processID: 1, command: .status))
    try expectThrows(ControlServerError.replayedEvent) {
        _ = try server.handle(ControlRequest(token: "secret", eventID: "a", processID: 1, command: .status))
    }

    _ = try server.handle(ControlRequest(token: "secret", eventID: "b", processID: 1, command: .status))
    try expectThrows(ControlServerError.rateLimited) {
        _ = try server.handle(ControlRequest(token: "secret", eventID: "c", processID: 1, command: .status))
    }
}

private func runServerUsesReceiptTimeInsteadOfClientTimestamp() throws {
    let receiptTime = Date(timeIntervalSince1970: 6_000)
    let clientTime = Date(timeIntervalSince1970: 1)
    let router = RecordingRouter()
    let server = ControlServer(token: "secret", router: router, now: { receiptTime })

    let response = try server.handle(
        ControlRequest(
            token: "secret",
            eventID: "receipt",
            clientTimestamp: clientTime,
            command: .pause(duration: 3_600)
        )
    )

    try check(response.receiptTimestamp == receiptTime, "Expected response to use server receipt time")
    try check(router.receivedAt == [receiptTime], "Expected router to receive server receipt time")
}

private func runCLIParsesCommandsAndSendsThroughClient() throws {
    let client = RecordingClient()
    let cli = ClawShellCLI(client: client)

    let statusOutput = try cli.run(arguments: ["clawshell", "status"])
    try check(statusOutput == "ok", "Expected status output from client")
    try check(client.commands.last == .status, "Expected status command")
    _ = try cli.run(arguments: ["clawshell", "pause", "1h"])
    try check(client.commands.last == .pause(duration: 3_600), "Expected pause command")
    _ = try cli.run(arguments: ["clawshell", "release", "now"])
    try check(client.commands.last == .releaseNow, "Expected release now command")
    _ = try cli.run(arguments: ["clawshell", "list"])
    try check(client.commands.last == .list, "Expected list command")
    _ = try cli.run(arguments: ["clawshell", "add", "/usr/local/bin/agent"])
    try check(client.commands.last == .add(binary: "/usr/local/bin/agent"), "Expected add command")
    _ = try cli.run(arguments: ["clawshell", "integrations", "remove", "codex-cli"])
    try check(client.commands.last == .integrationsRemove(agentID: "codex-cli"), "Expected integrations remove command")
    _ = try cli.run(arguments: ["clawshell", "integrations", "enable-auto", "claude-code"])
    try check(client.commands.last == .integrationsEnableAuto(agentID: "claude-code"), "Expected integrations enable-auto command")
    _ = try cli.run(arguments: ["clawshell", "helper", "status"])
    try check(client.commands.last == .helperStatus, "Expected helper status command")
    _ = try cli.run(arguments: ["clawshell", "helper", "repair"])
    try check(client.commands.last == .helperRepair, "Expected helper repair command")
    _ = try cli.run(arguments: ["clawshell", "uninstall", "--remove-helper", "--remove-integrations"])
    try check(
        client.commands.last == .uninstall(removeHelper: true, removeIntegrations: true),
        "Expected uninstall flags"
    )
}

private final class RecordingRouter: ControlCommandRouting {
    var commands: [ControlCommand] = []
    var receivedAt: [Date] = []

    func route(_ command: ControlCommand, receivedAt: Date) throws -> ControlResponse {
        commands.append(command)
        self.receivedAt.append(receivedAt)
        return ControlResponse(accepted: true, receiptTimestamp: receivedAt, message: "ok")
    }
}

private final class RecordingClient: ControlClient {
    var commands: [ControlCommand] = []

    func send(_ command: ControlCommand) throws -> ControlResponse {
        commands.append(command)
        return ControlResponse(accepted: true, receiptTimestamp: Date(timeIntervalSince1970: 1), message: "ok")
    }
}

private func makeTemporaryPaths() throws -> ClawShellPaths {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClawShellControlTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return ClawShellPaths(applicationSupportDirectory: url)
}

private func expectThrows<E: Error & Equatable>(_ expected: E, operation: () throws -> Void) throws {
    do {
        try operation()
    } catch let error as E {
        try check(error == expected, "Expected \(expected), got \(error)")
        return
    }

    throw TestFailure("Expected \(expected) to be thrown")
}

private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw TestFailure(message)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
#endif
