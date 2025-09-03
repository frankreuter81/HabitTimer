//
//  LiveActivityIntents.swift
//  HabitTimer
//
//  Created by Frank Reuter on 03.09.25.
//


import Foundation
import ActivityKit
import AppIntents
import os

#if !canImport(WidgetKit)
@available(iOS 16.1, *)
struct HabitTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var remaining: Int
        var paused: Bool
        var total: Int?
    }
    var habitID: String?
}
#endif

private let intentLogger = Logger(subsystem: "de.frankreuter.habittimer", category: "AppIntent")

// App Group to optionally signal the app about state changes
private let appGroupID = "group.de.frankreuter.habittimer"

// MARK: - Toggle Pause/Resume
@available(iOS 17.0, *)
struct TogglePauseHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer pausieren/fortsetzen"
    static var description = IntentDescription("Pausiert oder setzt den ausgewählten Timer fort – direkt aus der Live-Aktivität.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    @MainActor func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else { return .result() }
        intentLogger.info("[AppIntent] TogglePauseHabitIntent perform habitID=\(self.habitID, privacy: .public)")
        print("[AppIntent] TogglePauseHabitIntent perform habitID=\(habitID)")
        // Diagnostics: list all current activities
        let acts = Activity<HabitTimerActivityAttributes>.activities
        intentLogger.info("[AppIntent] Activities count=\(acts.count, privacy: .public)")
        print("[AppIntent] Activities count=\(acts.count)")
        for a in acts {
            let hid = a.attributes.habitID ?? "-"
            intentLogger.info("[AppIntent] Activity id=\(a.id, privacy: .public) habitID=\(hid, privacy: .public)")
            print("[AppIntent] Activity id=\(a.id) habitID=\(hid)")
        }
        if let act = Activity<HabitTimerActivityAttributes>.activities.first(where: { $0.attributes.habitID == id.uuidString }) {
            // Toggle paused based on current content state
            let current = act.content.state
            let newPaused = !current.paused
            intentLogger.info("[AppIntent] TogglePause: current.paused=\(current.paused, privacy: .public) -> newPaused=\(newPaused, privacy: .public), remaining=\(current.remaining, privacy: .public)")
            print("[AppIntent] TogglePause: current.paused=\(current.paused) -> newPaused=\(newPaused), remaining=\(current.remaining)")
            let updated = HabitTimerActivityAttributes.ContentState(
                title: current.title,
                remaining: max(0, current.remaining),
                paused: newPaused,
                total: current.total
            )
            intentLogger.info("[AppIntent] TogglePause: update LiveActivity")
            print("[AppIntent] TogglePause: update LiveActivity")
            await act.update(ActivityContent(state: updated, staleDate: nil))

            intentLogger.info("[AppIntent] TogglePause: update Store (pause/resume)")
            print("[AppIntent] TogglePause: update Store (pause/resume)")

            // Hint for the main app via App Group (optional)
            let defaults = UserDefaults(suiteName: appGroupID)
            defaults?.set(newPaused, forKey: "intent_pause_\(id.uuidString)")
            defaults?.set(Date().timeIntervalSince1970, forKey: "intent_pause_ts_\(id.uuidString)")
        } else {
            intentLogger.error("[AppIntent] TogglePause: no matching activity for habitID=\(self.habitID, privacy: .public)")
            print("[AppIntent] TogglePause: no matching activity for habitID=\(habitID)")
        }
        return .result()
    }
}

// MARK: - Cancel
@available(iOS 17.0, *)
struct CancelHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer abbrechen"
    static var description = IntentDescription("Bricht den laufenden Timer ab und beendet die Live-Aktivität – direkt aus der Live-Aktivität.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    @MainActor func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else { return .result() }
        intentLogger.info("[AppIntent] CancelHabitIntent perform habitID=\(self.habitID, privacy: .public)")
        print("[AppIntent] CancelHabitIntent perform habitID=\(habitID)")
        if let act = Activity<HabitTimerActivityAttributes>.activities.first(where: { $0.attributes.habitID == id.uuidString }) {
            await act.end(ActivityContent(state: act.content.state, staleDate: nil), dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            intentLogger.info("[AppIntent] Cancel: ended LiveActivity")
            print("[AppIntent] Cancel: ended LiveActivity")
            let defaults = UserDefaults(suiteName: appGroupID)
            defaults?.set(true, forKey: "intent_cancel_\(id.uuidString)")
            defaults?.set(Date().timeIntervalSince1970, forKey: "intent_cancel_ts_\(id.uuidString)")
        }

        intentLogger.info("[AppIntent] Cancel: stop Store background run")
        print("[AppIntent] Cancel: stop Store background run")

        return .result()
    }
}
