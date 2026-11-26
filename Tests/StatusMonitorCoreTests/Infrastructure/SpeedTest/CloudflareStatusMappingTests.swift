import Testing
@testable import StatusMonitorCore

@Suite("CloudflareSpeedTestClient status mapping")
struct CloudflareStatusMappingTests {
    @Test("every 2xx status is accepted", arguments: [200, 201, 204, 299])
    func successStatusesAccepted(status: Int) {
        #expect(CloudflareSpeedTestClient.failure(forStatusCode: status) == nil)
    }

    @Test("429 maps to rateLimited")
    func tooManyRequests() {
        #expect(CloudflareSpeedTestClient.failure(forStatusCode: 429) == .rateLimited)
    }

    @Test("503 maps to serviceUnavailable")
    func serviceUnavailable() {
        #expect(CloudflareSpeedTestClient.failure(forStatusCode: 503) == .serviceUnavailable)
    }

    @Test("every other non-2xx status maps to serviceUnavailable", arguments: [100, 199, 300, 302, 400, 404, 500, 502])
    func otherNonSuccessStatuses(status: Int) {
        #expect(CloudflareSpeedTestClient.failure(forStatusCode: status) == .serviceUnavailable)
    }
}
