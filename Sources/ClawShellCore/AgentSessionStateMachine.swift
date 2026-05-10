import Foundation

public final class AgentSessionStateMachine {
    public var graceInterval: TimeInterval
    public private(set) var sessions: [AgentSession]
    public private(set) var pauseAllExpiresAt: Date?
    public private(set) var safetyCutoffActive: Bool

    public init(
        graceInterval: TimeInterval = 15 * 60,
        sessions: [AgentSession] = [],
        pauseAllExpiresAt: Date? = nil,
        safetyCutoffActive: Bool = false
    ) {
        self.graceInterval = graceInterval
        self.sessions = sessions
        self.pauseAllExpiresAt = pauseAllExpiresAt
        self.safetyCutoffActive = safetyCutoffActive
    }

    public func applyProcessObservations(_ observations: [AgentProcessObservation], at now: Date) {
        refreshExpirations(at: now)

        let observedIdentities = Set(observations.compactMap(\.key.processIdentity))
        for index in sessions.indices {
            guard sessions[index].source == .processScan,
                  sessions[index].state != .finished,
                  let identity = sessions[index].key.processIdentity,
                  !observedIdentities.contains(identity) else {
                continue
            }

            sessions[index].state = .finished
            sessions[index].standingByExpiresAt = nil
            sessions[index].lastEvent = SessionEvent(kind: .processDisappeared, occurredAt: now)
        }

        for observation in observations {
            guard let identity = observation.key.processIdentity else {
                continue
            }

            if let index = sessions.firstIndex(where: { $0.key.processIdentity == identity }) {
                sessions[index].lastObservedAt = now
                sessions[index].diagnosticCPUPercent = observation.snapshot.cpuPercent
            } else {
                sessions.append(
                    AgentSession(
                        key: observation.key,
                        agent: observation.agent,
                        confidence: observation.confidence,
                        source: observation.source,
                        firstSeenAt: now,
                        lastActivityAt: now,
                        lastObservedAt: now,
                        lastEvent: SessionEvent(kind: .matchingProcessStarted, occurredAt: now),
                        diagnosticCPUPercent: observation.snapshot.cpuPercent
                    )
                )
            }
        }
    }

    public func applyTrustedEvent(_ kind: SessionEventKind, to sessionID: UUID, at now: Date) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        applyTrustedEvent(kind, toSessionAt: index, at: now)
    }

    public func pauseAll(until expiresAt: Date?) {
        pauseAllExpiresAt = expiresAt ?? .distantFuture
    }

    public func clearPauseAll() {
        pauseAllExpiresAt = nil
    }

    public func setSafetyCutoffActive(_ isActive: Bool) {
        safetyCutoffActive = isActive
    }

    public func refreshExpirations(at now: Date) {
        if let pauseAllExpiresAt, pauseAllExpiresAt <= now {
            self.pauseAllExpiresAt = nil
        }

        for index in sessions.indices {
            guard sessions[index].state == .standingBy,
                  !sessions[index].holdWhileOpen,
                  let expiresAt = sessions[index].standingByExpiresAt,
                  expiresAt <= now else {
                continue
            }

            sessions[index].state = .finished
            sessions[index].lastEvent = SessionEvent(kind: .graceExpired, occurredAt: now)
        }
    }

    public func aggregateHoldState(at now: Date) -> AgentAggregateHoldState {
        if safetyCutoffActive {
            return AgentAggregateHoldState(
                shouldHold: false,
                heldSessionIDs: [],
                isSafetyCutoffActive: true
            )
        }

        let isPaused = pauseAllExpiresAt.map { $0 > now } ?? false
        if isPaused {
            return AgentAggregateHoldState(shouldHold: false, heldSessionIDs: [], isPaused: true)
        }

        let heldSessionIDs = sessions
            .filter { $0.contributesToHold(at: now) }
            .map(\.id)

        return AgentAggregateHoldState(
            shouldHold: !heldSessionIDs.isEmpty,
            heldSessionIDs: heldSessionIDs
        )
    }

    private func applyTrustedEvent(_ kind: SessionEventKind, toSessionAt index: Int, at now: Date) {
        switch kind {
        case .turnFinished:
            guard sessions[index].state == .active else {
                return
            }

            sessions[index].state = .standingBy
            sessions[index].standingByExpiresAt = now.addingTimeInterval(graceInterval)
            sessions[index].lastEvent = SessionEvent(kind: kind, occurredAt: now)

        case .sessionFinished, .processDisappeared, .releaseNow:
            sessions[index].state = .finished
            sessions[index].standingByExpiresAt = nil
            sessions[index].lastEvent = SessionEvent(kind: kind, occurredAt: now)

        case .toolStarted, .agentResumed, .processTreeChanged:
            sessions[index].state = .active
            sessions[index].lastActivityAt = now
            sessions[index].standingByExpiresAt = nil
            sessions[index].lastEvent = SessionEvent(kind: kind, occurredAt: now)

        case .keepHolding:
            guard sessions[index].state == .standingBy else {
                return
            }

            let baseline = max(sessions[index].standingByExpiresAt ?? now, now)
            sessions[index].standingByExpiresAt = baseline.addingTimeInterval(graceInterval)
            sessions[index].lastEvent = SessionEvent(kind: kind, occurredAt: now)

        case .pauseAll:
            pauseAll(until: nil)

        case .safetyCutoff:
            setSafetyCutoffActive(true)

        case .matchingProcessStarted, .graceExpired:
            return
        }
    }
}
