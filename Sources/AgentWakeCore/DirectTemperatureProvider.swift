import AgentWakeTemperatureIOReport
import Foundation

public struct DirectTemperatureProviderStatus: Equatable, Sendable {
    public var reading: BagModeTemperatureReading
    public var source: String
    public var celsius: Double?
    public var sampleCount: Int
    public var scaleVerifiedCount: Int
    public var invalidSampleCount: Int
    public var apiFailureCount: Int

    public init(
        reading: BagModeTemperatureReading,
        source: String = "libIOReport ANS2/MSP",
        celsius: Double? = nil,
        sampleCount: Int = 0,
        scaleVerifiedCount: Int = 0,
        invalidSampleCount: Int = 0,
        apiFailureCount: Int = 0
    ) {
        self.reading = reading
        self.source = source
        self.celsius = celsius
        self.sampleCount = sampleCount
        self.scaleVerifiedCount = scaleVerifiedCount
        self.invalidSampleCount = invalidSampleCount
        self.apiFailureCount = apiFailureCount
    }

    public var scaleVerified: Bool {
        sampleCount > 0 && sampleCount == scaleVerifiedCount
    }
}

public struct DirectTemperatureProvider: Sendable {
    public var timeoutSeconds: TimeInterval

    private static let readQueue = DispatchQueue(label: "wtf.vishal.agentwake.direct-temperature-provider")

    public init(timeoutSeconds: TimeInterval = 1) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func currentReading(capturedAt: Date = Date()) -> BagModeTemperatureReading {
        currentStatus(capturedAt: capturedAt).reading
    }

    public func currentStatus(capturedAt: Date = Date()) -> DirectTemperatureProviderStatus {
        let box = DirectTemperatureProviderResultBox()
        Self.readQueue.async {
            box.status = Self.readIOReportStatus(capturedAt: capturedAt)
            box.semaphore.signal()
        }

        let deadline = DispatchTime.now() + timeoutSeconds
        guard box.semaphore.wait(timeout: deadline) == .success else {
            return DirectTemperatureProviderStatus(reading: .timedOut)
        }

        return box.status ?? DirectTemperatureProviderStatus(reading: .unavailable)
    }

    private static func readIOReportStatus(capturedAt: Date) -> DirectTemperatureProviderStatus {
        var reading = AgentWakeIOReportTemperatureReading()
        let status = AgentWakeIOReportReadTemperature(&reading)
        let celsius = reading.celsius.isFinite ? reading.celsius : nil
        let hasUsableSample = status == AgentWakeIOReportTemperatureStatusOK &&
            reading.sampleCount > 0 &&
            reading.invalidSampleCount == 0
        let providerStatus = DirectTemperatureProviderStatus(
            reading: providerReading(
                status: Int(status),
                celsius: celsius,
                capturedAt: capturedAt,
                coversClosedBagRisk: hasUsableSample
            ),
            celsius: celsius,
            sampleCount: Int(reading.sampleCount),
            scaleVerifiedCount: Int(reading.scaleVerifiedCount),
            invalidSampleCount: Int(reading.invalidSampleCount),
            apiFailureCount: Int(reading.apiFailureCount)
        )
        return providerStatus
    }

    private static func providerReading(
        status: Int,
        celsius: Double?,
        capturedAt: Date,
        coversClosedBagRisk: Bool
    ) -> BagModeTemperatureReading {
        switch status {
        case AgentWakeIOReportTemperatureStatusOK:
            guard let celsius else {
                return .parseFailed
            }
            return .sample(
                BagModeTemperatureSample(
                    celsius: celsius,
                    capturedAt: capturedAt,
                    coversClosedBagRisk: coversClosedBagRisk
                )
            )
        case AgentWakeIOReportTemperatureStatusUnavailable:
            return .unavailable
        case AgentWakeIOReportTemperatureStatusParseFailed:
            return .parseFailed
        case AgentWakeIOReportTemperatureStatusUnsupportedHardware:
            return .unsupportedHardware
        default:
            return .unavailable
        }
    }
}

private final class DirectTemperatureProviderResultBox: @unchecked Sendable {
    let semaphore = DispatchSemaphore(value: 0)
    var status: DirectTemperatureProviderStatus?
}
