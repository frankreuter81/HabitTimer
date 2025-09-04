import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents
import os
private let widgetLog = Logger(subsystem: "de.frankreuter.habittimer", category: "LiveActivityWidget")
@available(iOS 16.1, *)
struct HabitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return activityConfiguration17()
        } else {
            return activityConfiguration16()
        }
    }

    @available(iOS 17.0, *)
    private func activityConfiguration17() -> ActivityConfiguration<HabitTimerActivityAttributes> {
        ActivityConfiguration(
            for: HabitTimerActivityAttributes.self,
            content: { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.state.title)
                        .font(.headline)
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.state.paused ? "Pausiert" : "Läuft")
                                .font(.subheadline)
                            if let phase = context.state.currentPhaseName {
                                Text(phase)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .accessibilityLabel("Rest Abschnitt")
                            Text(timeString(context.state.remaining))
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Rest gesamt")
                            ProgressView(value: progress(state: context.state))
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
                .background(
                    Color.clear
                        .onAppear {
                            widgetLog.info("[Widget] content17 title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public) total=\(context.state.total ?? -1, privacy: .public)")
                            print("[Widget] content17 title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining) total=\(context.state.total ?? -1)")
                        }
                )
            },
            dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        Color.clear.frame(width: 0, height: 0).onAppear {
                            widgetLog.info("[Widget] island17 render title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public)")
                            print("[Widget] island17 render title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining)")
                        }
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
                            HStack {
                                Text("Abschnitt: \(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Spacer()
                                Text("Gesamt: \(timeString(context.state.remaining))")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
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
        )
    }

    private func activityConfiguration16() -> ActivityConfiguration<HabitTimerActivityAttributes> {
        ActivityConfiguration(for: HabitTimerActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.title)
                    .font(.headline)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.paused ? "Pausiert" : "Läuft")
                            .font(.subheadline)
                        if let phase = context.state.currentPhaseName {
                            Text(phase)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .accessibilityLabel("Rest Abschnitt")
                        Text(timeString(context.state.remaining))
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Rest gesamt")
                        ProgressView(value: progress(state: context.state))
                            .progressViewStyle(.linear)
                    }
                }
            }
            .padding()
                .background(
                    Color.clear
                        .onAppear {
                            widgetLog.info("[Widget] content16 title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public) total=\(context.state.total ?? -1, privacy: .public)")
                            print("[Widget] content16 title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining) total=\(context.state.total ?? -1)")
                        }
                )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Color.clear.frame(width: 0, height: 0).onAppear {
                        widgetLog.info("[Widget] island16 render title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public)")
                        print("[Widget] island16 render title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining)")
                    }
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
                        HStack {
                            Text("Abschnitt: \(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("Gesamt: \(timeString(context.state.remaining))")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
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

// MARK: - Optional ContentState helpers
private func contentStateString(_ state: HabitTimerActivityAttributes.ContentState, key: String) -> String? {
    let mirror = Mirror(reflecting: state)
    for child in mirror.children {
        if child.label == key, let value = child.value as? String { return value }
    }
    return nil
}

private func contentStateInt(_ state: HabitTimerActivityAttributes.ContentState, key: String) -> Int? {
    let mirror = Mirror(reflecting: state)
    for child in mirror.children {
        if child.label == key {
            if let v = child.value as? Int { return v }
            if let vOpt = child.value as? Optional<Int> { return vOpt }
        }
    }
    return nil
}

private func phaseName(from state: HabitTimerActivityAttributes.ContentState) -> String? {
    // Try several common keys to avoid compile-time coupling
    return contentStateString(state, key: "phaseName")
        ?? contentStateString(state, key: "currentPhaseName")
        ?? contentStateString(state, key: "stepName")
        ?? contentStateString(state, key: "actionName")
}

private func phaseRemaining(from state: HabitTimerActivityAttributes.ContentState) -> Int? {
    // Try several common keys to avoid compile-time coupling
    return contentStateInt(state, key: "phaseRemaining")
        ?? contentStateInt(state, key: "currentPhaseRemaining")
        ?? contentStateInt(state, key: "stepRemaining")
        ?? contentStateInt(state, key: "actionRemaining")
}

// MARK: - Debug Widget (to make the extension discoverable in Simulator)
struct DebugProvider: TimelineProvider {
    struct SimpleEntry: TimelineEntry { let date: Date }
    func placeholder(in context: Context) -> SimpleEntry {
        widgetLog.info("[Widget] DebugProvider.placeholder")
        print("[Widget] DebugProvider.placeholder")
        return SimpleEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        widgetLog.info("[Widget] DebugProvider.getSnapshot")
        print("[Widget] DebugProvider.getSnapshot")
        completion(SimpleEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        widgetLog.info("[Widget] DebugProvider.getTimeline")
        print("[Widget] DebugProvider.getTimeline")
        let entry = SimpleEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct DebugWidgetEntryView: View {
    var entry: DebugProvider.SimpleEntry
    var body: some View {
        VStack {
            Text("HabitTimer Debug").padding()
        }
        .onAppear {
            widgetLog.info("[Widget] DebugWidgetEntryView.onAppear")
            print("[Widget] DebugWidgetEntryView.onAppear")
        }
    }
}

struct DebugWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DebugWidget", provider: DebugProvider()) { entry in
            DebugWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HabitTimer Debug")
        .description("Helper widget for debugging the extension.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle Entry Point
import WidgetKit

@main
struct HabitTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        DebugWidget()
        HabitLiveActivity()
    }
}
