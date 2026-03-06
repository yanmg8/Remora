import Foundation
import Testing
@testable import RemoraApp

struct ConnectionInfoPasswordCopyConsentTests {
    @Test
    func passwordAuthRequiresConfirmationByDefault() {
        let decision = ConnectionInfoPasswordCopyConsentGate.decision(
            hostUsesPasswordAuth: true,
            mutedUntil: nil,
            muteForever: false,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(decision == .requireConfirmation)
    }

    @Test
    func nonPasswordAuthCopiesWithoutPrompt() {
        let decision = ConnectionInfoPasswordCopyConsentGate.decision(
            hostUsesPasswordAuth: false,
            mutedUntil: nil,
            muteForever: false,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(decision == .copy(includePassword: false))
    }

    @Test
    func todayMuteAllowsPasswordCopyUntilDeadline() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = ConnectionInfoPasswordCopyConsentGate.decision(
            hostUsesPasswordAuth: true,
            mutedUntil: now.addingTimeInterval(60),
            muteForever: false,
            now: now
        )

        #expect(decision == .copy(includePassword: true))
    }

    @Test
    func expiredTodayMutePromptsAgain() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = ConnectionInfoPasswordCopyConsentGate.decision(
            hostUsesPasswordAuth: true,
            mutedUntil: now.addingTimeInterval(-1),
            muteForever: false,
            now: now
        )

        #expect(decision == .requireConfirmation)
    }

    @Test
    func continueOnceCopiesPasswordWithoutPersistingMute() {
        let outcome = ConnectionInfoPasswordCopyConsentGate.outcome(
            for: .continueOnce,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(outcome.shouldCopy)
        #expect(outcome.includePassword)
        #expect(outcome.mutedUntil == nil)
        #expect(outcome.muteForever == false)
    }

    @Test
    func muteTodayCopiesPasswordAndExpiresAtNextDayBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let outcome = ConnectionInfoPasswordCopyConsentGate.outcome(
            for: .dontRemindAgainToday,
            now: now,
            calendar: calendar
        )

        #expect(outcome.shouldCopy)
        #expect(outcome.includePassword)
        #expect(outcome.muteForever == false)
        #expect(outcome.mutedUntil == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
    }

    @Test
    func muteForeverCopiesPasswordAndPersistsPreference() {
        let outcome = ConnectionInfoPasswordCopyConsentGate.outcome(
            for: .dontRemindAgainEver,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(outcome.shouldCopy)
        #expect(outcome.includePassword)
        #expect(outcome.mutedUntil == nil)
        #expect(outcome.muteForever)
    }

    @Test
    func cancelSkipsCopyAndLeavesMuteStateUntouched() {
        let outcome = ConnectionInfoPasswordCopyConsentGate.outcome(
            for: .cancel,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(outcome.shouldCopy == false)
        #expect(outcome.includePassword == false)
        #expect(outcome.mutedUntil == nil)
        #expect(outcome.muteForever == false)
    }
}
