//
//  HabitTimerIntentsExtension.swift
//  HabitTimerIntentsExtension
//
//  Created by Frank Reuter on 03.09.25.
//

import AppIntents

struct HabitTimerIntentsExtension: AppIntent {
    static var title: LocalizedStringResource { "HabitTimerIntentsExtension" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
