//
//  HabitTimerActivityAttributes.swift
//  HabitTimer
//
//  Shared Live Activity attributes used by App, Widget Extension, and App Intents Extension.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct HabitTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var remaining: Int   // seconds left
        var paused: Bool
        var total: Int?      // planned total seconds (optional, for progress)

        // Optional: name of the current phase (e.g. "Start", "Aktion 1"). Defaults to nil for backward compatibility.
        var currentPhaseName: String? = nil

        // Optional: seconds remaining in the current phase. Defaults to nil for backward compatibility.
        var currentPhaseRemaining: Int? = nil
    }

    /// Optional habit identifier used to route actions (deeplinks / intents)
    var habitID: String?
}
