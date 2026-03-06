import Foundation

enum PasswordSaveConsentDecision: Equatable {
    case apply(Bool)
    case requireConsent
}

enum PasswordSaveConsentGate {
    static func decision(
        currentlyEnabled: Bool,
        requestedEnabled: Bool,
        hasAcknowledgedWarning: Bool
    ) -> PasswordSaveConsentDecision {
        if requestedEnabled && !currentlyEnabled && !hasAcknowledgedWarning {
            return .requireConsent
        }
        return .apply(requestedEnabled)
    }
}
