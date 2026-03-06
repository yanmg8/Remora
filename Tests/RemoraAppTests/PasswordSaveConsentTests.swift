import Testing
@testable import RemoraApp

struct PasswordSaveConsentTests {
    @Test
    func requiresConsentWhenEnablingWithoutAcknowledgement() {
        let decision = PasswordSaveConsentGate.decision(
            currentlyEnabled: false,
            requestedEnabled: true,
            hasAcknowledgedWarning: false
        )

        #expect(decision == .requireConsent)
    }

    @Test
    func allowsEnablingAfterAcknowledgement() {
        let decision = PasswordSaveConsentGate.decision(
            currentlyEnabled: false,
            requestedEnabled: true,
            hasAcknowledgedWarning: true
        )

        #expect(decision == .apply(true))
    }

    @Test
    func allowsDisablingWithoutConsent() {
        let decision = PasswordSaveConsentGate.decision(
            currentlyEnabled: true,
            requestedEnabled: false,
            hasAcknowledgedWarning: false
        )

        #expect(decision == .apply(false))
    }
}
