//
//  HabitTimerActivityAttributes.swift
//  HabitTimer
//
//  Shared Live Activity attributes used by App, Widget Extension, and App Intents Extension.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
public struct HabitTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var remaining: Int   // seconds left
        var paused: Bool
        var total: Int?      // planned total seconds (optional, for progress)

        // Optional: name of the current phase (e.g. "Start", "Aktion 1"). Defaults to nil for backward compatibility.
        var currentPhaseName: String? = nil

        // Optional: seconds remaining in the current phase. Defaults to nil for backward compatibility.
        var currentPhaseRemaining: Int? = nil

        // Optional: total number of phases/segments in this timer (for displaying e.g. 1/5).
        var phaseCount: Int? = nil

        // Optional: 1-based index of the current phase (1 = first phase). If your source index is 0-based, add 1 before assigning.
        var currentPhaseIndex: Int? = nil

        // Optional: durations in seconds for ALL phases in order. Used by the widget to count only phases with time > 0.
        var phaseDurations: [Int]? = nil

        // Optional: current phase index (ZERO-based) into the unfiltered phases array above.
        // The widget maps this to a 1-based position among phases with duration > 0.
        var phaseIndexZeroBased: Int? = nil

        // Optional: total seconds of the current phase. If 0 or nil, the widget may hide the counter.
        var currentPhaseTotal: Int? = nil
    }

    /// Optional habit identifier used to route actions (deeplinks / intents)
    var habitID: String
}
