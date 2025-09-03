import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents
@available(iOS 16.1, *)
struct HabitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return ActivityConfiguration(for: HabitTimerActivityAttributes.self) { context in
                // Lock Screen / Banner (iOS 17)
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.state.title)
                        .font(.headline)
                    HStack(alignment: .center) {
                        HStack(spacing: 12) {
                            if let habitID = context.attributes.habitID {
                                // Echte interaktive Buttons (iOS 17+)
                                Button(intent: TogglePauseHabitIntent(habitID: habitID)) {
                                    Image(systemName: context.state.paused ? "play.fill" : "pause.fill")
                                        .font(.title2)
                                }
                                Button(role: .destructive, intent: CancelHabitIntent(habitID: habitID)) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(timeString(context.state.remaining))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            ProgressView(value: progress(state: context.state))
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
            } dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        if let habitID = context.attributes.habitID {
                            HStack(spacing: 12) {
                                Button(intent: TogglePauseHabitIntent(habitID: habitID)) {
                                    Image(systemName: context.state.paused ? "play.fill" : "pause.fill")
                                        .font(.title3)
                                }
                                Button(intent: CancelHabitIntent(habitID: habitID)) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                }
                            }
                        }
                    }
                    DynamicIslandExpandedRegion(.center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(context.state.title).font(.headline)
                            Text(timeString(context.state.remaining))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            ProgressView(value: progress(state: context.state))
                        }
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Text(context.state.paused ? "Pausiert" : "Aktiv").font(.caption)
                    }
                } compactLeading: {
                    if let habitID = context.attributes.habitID {
                        Button(intent: TogglePauseHabitIntent(habitID: habitID)) {
                            Image(systemName: context.state.paused ? "play.fill" : "pause.fill")
                        }
                    }
                } compactTrailing: {
                    if let habitID = context.attributes.habitID {
                        Button(intent: CancelHabitIntent(habitID: habitID)) {
                            Image(systemName: "xmark")
                        }
                    }
                } minimal: {
                    if let habitID = context.attributes.habitID {
                        Button(intent: TogglePauseHabitIntent(habitID: habitID)) {
                            Image(systemName: context.state.paused ? "play.fill" : "pause.fill")
                        }
                    }
                }
            }
        } else {
            // iOS 16.1–16.4: ohne actions{}, Fallback via Deeplinks/Links
            return ActivityConfiguration(for: HabitTimerActivityAttributes.self) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.state.title)
                        .font(.headline)
                    HStack(alignment: .center) {
                        HStack(spacing: 12) {
                            if let habitID = context.attributes.habitID {
                                Link(destination: URL(string: "habittimer://live?habit=\(habitID)&action=\(context.state.paused ? "resume" : "pause")")!) {
                                    Image(systemName: context.state.paused ? "play.fill" : "pause.fill").font(.title2)
                                }
                                Link(destination: URL(string: "habittimer://live?habit=\(habitID)&action=cancel")!) {
                                    Image(systemName: "xmark.circle.fill").font(.title2)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(timeString(context.state.remaining))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            ProgressView(value: progress(state: context.state))
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
            } dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        if let habitID = context.attributes.habitID {
                            HStack(spacing: 12) {
                                Link(destination: URL(string: "habittimer://live?habit=\(habitID)&action=\(context.state.paused ? "resume" : "pause")")!) {
                                    Image(systemName: context.state.paused ? "play.fill" : "pause.fill").font(.title3)
                                }
                                Link(destination: URL(string: "habittimer://live?habit=\(habitID)&action=cancel")!) {
                                    Image(systemName: "xmark.circle.fill").font(.title3)
                                }
                            }
                        }
                    }
                    DynamicIslandExpandedRegion(.center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(context.state.title).font(.headline)
                            Text(timeString(context.state.remaining))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            ProgressView(value: progress(state: context.state))
                        }
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Text(context.state.paused ? "Pausiert" : "Aktiv").font(.caption)
                    }
                } compactLeading: {
                    Image(systemName: context.state.paused ? "pause" : "timer")
                } compactTrailing: {
                    Text(shortTime(context.state.remaining))
                } minimal: {
                    Image(systemName: context.state.paused ? "pause" : "timer")
                }
            }
        }
    }
}
// MARK: - Helpers
private func timeString(_ seconds: Int) -> String {
    let m = max(0, seconds) / 60
    let s = max(0, seconds) % 60
    return String(format: "%02d:%02d", m, s)
}
private func shortTime(_ seconds: Int) -> String { timeString(seconds) }
private func progress(state: HabitTimerActivityAttributes.ContentState) -> Double {
    guard let total = state.total, total > 0 else { return 0 }
    let done = max(0, min(total, total - state.remaining))
    return Double(done) / Double(total)
}
