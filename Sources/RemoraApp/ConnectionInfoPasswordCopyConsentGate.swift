import Foundation

enum ConnectionInfoPasswordCopyConsentDecision: Equatable {
    case copy(includePassword: Bool)
    case requireConfirmation
}

enum ConnectionInfoPasswordCopyConsentChoice {
    case continueOnce
    case dontRemindAgainToday
    case dontRemindAgainEver
    case cancel
}

struct ConnectionInfoPasswordCopyConsentOutcome: Equatable {
    var shouldCopy: Bool
    var includePassword: Bool
    var mutedUntil: Date?
    var muteForever: Bool
}

enum ConnectionInfoPasswordCopyConsentGate {
    static func decision(
        hostUsesPasswordAuth: Bool,
        mutedUntil: Date?,
        muteForever: Bool,
        now: Date = Date()
    ) -> ConnectionInfoPasswordCopyConsentDecision {
        guard hostUsesPasswordAuth else {
            return .copy(includePassword: false)
        }

        if muteForever {
            return .copy(includePassword: true)
        }

        if let mutedUntil, mutedUntil > now {
            return .copy(includePassword: true)
        }

        return .requireConfirmation
    }

    static func outcome(
        for choice: ConnectionInfoPasswordCopyConsentChoice,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ConnectionInfoPasswordCopyConsentOutcome {
        switch choice {
        case .continueOnce:
            return .init(shouldCopy: true, includePassword: true, mutedUntil: nil, muteForever: false)
        case .dontRemindAgainToday:
            return .init(
                shouldCopy: true,
                includePassword: true,
                mutedUntil: nextDayBoundary(after: now, calendar: calendar),
                muteForever: false
            )
        case .dontRemindAgainEver:
            return .init(shouldCopy: true, includePassword: true, mutedUntil: nil, muteForever: true)
        case .cancel:
            return .init(shouldCopy: false, includePassword: false, mutedUntil: nil, muteForever: false)
        }
    }

    private static func nextDayBoundary(after now: Date, calendar: Calendar) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
    }
}
