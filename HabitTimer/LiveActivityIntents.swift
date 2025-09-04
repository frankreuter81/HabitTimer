//
//  LiveActivityIntents.swift
//  HabitTimerIntentsExtension
//
//  App Intents that control the HabitTimer Live Activity.
//

import AppIntents
import ActivityKit
import os

fileprivate let intentsLog = Logger(subsystem: "de.frankreuter.habittimer", category: "AppIntent")

// MARK: - Toggle Pause / Resume
@available(iOS 16.1, *)
struct TogglePauseHabitIntent: AppIntent {
    static var title: LocalizedStringResource { "Pause/Resume Habit" }
    static var description = IntentDescription("Pausiert oder setzt einen laufenden Habit-Timer fort.")

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    func perform() async throws -> some IntentResult {
        intentsLog.info("[AppIntent] TogglePause perform habitID=\(self.habitID, privacy: .public)")
        let activities = Activity<HabitTimerActivityAttributes>.activities
        intentsLog.info("[AppIntent] Activities count=\(activities.count)")

        guard let activity = activities.first(where: { $0.attributes.habitID == self.habitID }) else {
            intentsLog.warning("[AppIntent] TogglePause: no matching activity for habitID=\(self.habitID, privacy: .public)")
            return .result()
        }

        let current = activity.content
        let state = current.state
        let newState = HabitTimerActivityAttributes.ContentState(
            title: state.title,
            remaining: state.remaining,
            paused: !state.paused, total: state.total
        )

        if #available(iOS 16.2, *) {
            try? await activity.update(ActivityContent(state: newState, staleDate: nil))
        } else {
            try? await activity.update(using: newState)
        }

        intentsLog.info("[AppIntent] TogglePause: updated activity id=\(activity.id, privacy: .public) paused=\(newState.paused)")
        return .result()
    }
}

// MARK: - Cancel / End
@available(iOS 16.1, *)
struct CancelHabitIntent: AppIntent {
    static var title: LocalizedStringResource { "Cancel Habit" }
    static var description = IntentDescription("Beendet die laufende Habit Live-Aktivität.")

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    func perform() async throws -> some IntentResult {
        intentsLog.info("[AppIntent] Cancel perform habitID=\(self.habitID, privacy: .public)")
        let activities = Activity<HabitTimerActivityAttributes>.activities
        intentsLog.info("[AppIntent] Activities count=\(activities.count)")

        guard let activity = activities.first(where: { $0.attributes.habitID == self.habitID }) else {
            intentsLog.warning("[AppIntent] Cancel: no matching activity for habitID=\(self.habitID, privacy: .public)")
            return .result()
        }

        let state = activity.content.state
        if #available(iOS 16.2, *) {
            try? await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        } else {
            try? await activity.end(using: state, dismissalPolicy: .immediate)
        }

        intentsLog.info("[AppIntent] Cancel: ended activity id=\(activity.id, privacy: .public)")
        return .result()
    }
}
