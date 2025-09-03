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
    }

    /// Optional habit identifier used to route actions (deeplinks / intents)
    var habitID: String?
}
