import Testing
@testable import StatusMonitorCore

@Suite("PurgePermissionPromptPolicy")
struct PurgePermissionPromptPolicyTests {
    @Test("an installed rule is never asked about, even if the user never declined")
    func installedDoesNotAsk() {
        #expect(PurgePermissionPromptPolicy.shouldAsk(installed: true, declinedBefore: false) == false)
        #expect(PurgePermissionPromptPolicy.shouldAsk(installed: true, declinedBefore: true) == false)
    }

    @Test("a missing rule that the user never declined is asked about")
    func missingAndNeverDeclinedAsks() {
        #expect(PurgePermissionPromptPolicy.shouldAsk(installed: false, declinedBefore: false) == true)
    }

    @Test("a missing rule that the user declined before is not asked about again")
    func missingAndDeclinedDoesNotAsk() {
        #expect(PurgePermissionPromptPolicy.shouldAsk(installed: false, declinedBefore: true) == false)
    }

    @Test("an unknown install state (check not finished) is never asked about")
    func unknownDoesNotAsk() {
        #expect(PurgePermissionPromptPolicy.shouldAsk(installed: nil, declinedBefore: false) == false)
        #expect(PurgePermissionPromptPolicy.shouldAsk(installed: nil, declinedBefore: true) == false)
    }
}
