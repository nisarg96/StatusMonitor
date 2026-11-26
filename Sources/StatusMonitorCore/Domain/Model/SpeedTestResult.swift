import Foundation

/**
 The outcome of one internet speed test.

 Rates are decimal Mbit/s (1 Mbit = 10^6 bits), unlike the 1024-step rates used elsewhere in the app. Every
 measurement is optional, because a test can fail part-way. Nil means not measured, never zero.
 */
public struct SpeedTestResult: Equatable, Sendable {
    /// Download throughput in decimal Mbit/s. Nil when the download was not measured.
    public let downloadMbps: Double?
    /// Upload throughput in decimal Mbit/s. Nil when the upload was not measured.
    public let uploadMbps: Double?
    /// Round-trip latency in milliseconds. Nil when latency was not measured.
    public let latencyMs: Double?
    /// Latency jitter in milliseconds. Nil when fewer than two latency samples were taken.
    public let jitterMs: Double?
    /// Share of probe packets lost, as a percentage 0...100. Nil when loss was not measured.
    public let packetLossPercent: Double?
    /// When the test finished.
    public let measuredAt: Date

    /**
     Creates a result. Every measurement defaults to nil, meaning not measured.

     - Parameters:
       - downloadMbps: Download throughput in decimal Mbit/s. Nil when not measured.
       - uploadMbps: Upload throughput in decimal Mbit/s. Nil when not measured.
       - latencyMs: Round-trip latency in milliseconds. Nil when not measured.
       - jitterMs: Latency jitter in milliseconds. Nil when not measured.
       - packetLossPercent: Packet loss as a percentage. Nil when not measured.
       - measuredAt: When the test finished.
     */
    public init(
        downloadMbps: Double? = nil,
        uploadMbps: Double? = nil,
        latencyMs: Double? = nil,
        jitterMs: Double? = nil,
        packetLossPercent: Double? = nil,
        measuredAt: Date
    ) {
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.latencyMs = latencyMs
        self.jitterMs = jitterMs
        self.packetLossPercent = packetLossPercent
        self.measuredAt = measuredAt
    }
}
