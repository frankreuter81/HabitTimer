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
                    // Header: title • counter • phase ............ status (right)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(extractBaseTitle(context.state.title))
                            .font(.headline)
                        if let pos = phasePositionString(from: context.state) {
                            Text("• \(pos)")
                                .font(.headline)
                        }
                        if let name = (context.state.currentPhaseName ?? extractPhaseFromTitle(context.state.title)), !name.isEmpty {
                            Text("• \(name)")
                                .font(.headline)
                        }
                        Spacer()
                        Text(context.state.paused ? "Pausiert" : "Läuft")
                            .font(.subheadline)
                    }
                    // Countdown right-aligned
                    HStack {
                        Spacer()
                        Text(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .accessibilityLabel("Rest aktueller Timer-Abschnitt")
                    }
                    // Full-width progress
                    ProgressView(value: phaseProgress(state: context.state))
                        .progressViewStyle(.linear)
                }
                .padding()
                .background(
                    Color.clear
                        .onAppear {
                            widgetLog.info("[Widget] content17 title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public) total=\(context.state.total ?? -1, privacy: .public)")
                            print("[Widget] content17 title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining) total=\(context.state.total ?? -1)")
                            let phaseName = context.state.currentPhaseName ?? "-"
                            let segRemain = context.state.currentPhaseRemaining ?? -1
                            widgetLog.info("[Widget] content17 phase=\(phaseName, privacy: .public) segRemain=\(segRemain)")
                            print("[Widget] content17 phase=\(phaseName) segRemain=\(segRemain)")
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
                        let habitID = context.attributes.habitID
                        if !habitID.isEmpty {
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
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(extractBaseTitle(context.state.title))
                                    .font(.headline)
                                if let pos = phasePositionString(from: context.state) {
                                    Text("• \(pos)")
                                        .font(.headline)
                                }
                                if let name = (context.state.currentPhaseName ?? extractPhaseFromTitle(context.state.title)), !name.isEmpty {
                                    Text("• \(name)")
                                        .font(.headline)
                                }
                                Spacer()
                                Text(context.state.paused ? "Pausiert" : "Läuft")
                                    .font(.subheadline)
                            }
                            HStack {
                                Spacer()
                                Text(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            ProgressView(value: phaseProgress(state: context.state))
                        }
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        EmptyView()
                    }
                } compactLeading: {
                    let habitID = context.attributes.habitID
                    if !habitID.isEmpty {
                        Button(intent: TogglePauseHabitIntent(habitID: habitID)) {
                            Image(systemName: context.state.paused ? "play.fill" : "pause.fill")
                        }
                    }
                } compactTrailing: {
                    let habitID = context.attributes.habitID
                    if !habitID.isEmpty {
                        Button(intent: CancelHabitIntent(habitID: habitID)) {
                            Image(systemName: "xmark")
                        }
                    }
                } minimal: {
                    let habitID = context.attributes.habitID
                    if !habitID.isEmpty {
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(extractBaseTitle(context.state.title))
                        .font(.headline)
                    if let pos = phasePositionString(from: context.state) {
                        Text("• \(pos)")
                            .font(.headline)
                    }
                    if let name = (context.state.currentPhaseName ?? extractPhaseFromTitle(context.state.title)), !name.isEmpty {
                        Text("• \(name)")
                            .font(.headline)
                    }
                    Spacer()
                    Text(context.state.paused ? "Pausiert" : "Läuft")
                        .font(.subheadline)
                }
                HStack {
                    Spacer()
                    Text(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .accessibilityLabel("Rest aktueller Timer-Abschnitt")
                }
                ProgressView(value: phaseProgress(state: context.state))
                    .progressViewStyle(.linear)
            }
            .padding()
                .background(
                    Color.clear
                        .onAppear {
                            widgetLog.info("[Widget] content16 title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public) total=\(context.state.total ?? -1, privacy: .public)")
                            print("[Widget] content16 title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining) total=\(context.state.total ?? -1)")
                            let phaseName = context.state.currentPhaseName ?? "-"
                            let segRemain = context.state.currentPhaseRemaining ?? -1
                            widgetLog.info("[Widget] content16 phase=\(phaseName, privacy: .public) segRemain=\(segRemain)")
                            print("[Widget] content16 phase=\(phaseName) segRemain=\(segRemain)")
                        }
                )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Color.clear.frame(width: 0, height: 0).onAppear {
                        widgetLog.info("[Widget] island16 render title=\(context.state.title, privacy: .public) paused=\(context.state.paused, privacy: .public) remaining=\(context.state.remaining, privacy: .public)")
                        print("[Widget] island16 render title=\(context.state.title) paused=\(context.state.paused) remaining=\(context.state.remaining)")
                    }
                    let habitID = context.attributes.habitID
                    if !habitID.isEmpty {
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
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(extractBaseTitle(context.state.title))
                                .font(.headline)
                            if let pos = phasePositionString(from: context.state) {
                                Text("• \(pos)")
                                    .font(.headline)
                            }
                            if let name = (context.state.currentPhaseName ?? extractPhaseFromTitle(context.state.title)), !name.isEmpty {
                                Text("• \(name)")
                                    .font(.headline)
                            }
                            Spacer()
                            Text(context.state.paused ? "Pausiert" : "Läuft")
                                .font(.subheadline)
                        }
                        HStack {
                            Spacer()
                            Text(timeString(context.state.currentPhaseRemaining ?? context.state.remaining))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        ProgressView(value: phaseProgress(state: context.state))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
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

private func extractPhaseFromTitle(_ title: String) -> String? {
    if let range = title.range(of: "•", options: .backwards) {
        let raw = title[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : String(raw)
    }
    return nil
}

private func extractBaseTitle(_ title: String) -> String {
    if let range = title.range(of: "•") {
        let raw = title[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { return String(raw) }
    }
    return title
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

private func contentStateIntArray(_ state: HabitTimerActivityAttributes.ContentState, key: String) -> [Int]? {
    let mirror = Mirror(reflecting: state)
    for child in mirror.children {
        if child.label == key {
            if let arr = child.value as? [Int] { return arr }
            if let arrOpt = child.value as? Optional<[Int]> { return arrOpt }
            if let s = child.value as? String {
                if let parsed = parseIntList(from: s) { return parsed }
            }
        }
    }
    return nil
}

private func parseIntList(from s: String) -> [Int]? {
    // Accept CSV or any non-digit separators
    let parts = s.split(whereSeparator: { !$0.isNumber && $0 != "-" })
    let nums = parts.compactMap { Int($0) }
    return nums.isEmpty ? nil : nums
}

private func findPhaseDurationsArray(_ state: HabitTimerActivityAttributes.ContentState) -> [Int]? {
    // Try common keys for phase/segment/action durations
    let keys = [
        "phaseDurations","phaseTotals","phaseSeconds","phasesSeconds","sectionDurations","segmentDurations","actionDurations","durations","secondsPerPhase"
    ]
    for k in keys {
        if let arr = contentStateIntArray(state, key: k) { return arr }
    }
    // Heuristic: scan all arrays named with 'phase'/'segment'/'action' and 'duration'/'total'/'seconds'
    let mirror = Mirror(reflecting: state)
    for child in mirror.children {
        guard let label = child.label else { continue }
        let l = label.lowercased()
        if (l.contains("phase") || l.contains("segment") || l.contains("action")) &&
           (l.contains("duration") || l.contains("total") || l.contains("seconds")) {
            if let arr = child.value as? [Int] { return arr }
            if let arrOpt = child.value as? Optional<[Int]> { return arrOpt }
        }
        if let s = child.value as? String {
            if (l.contains("phase") || l.contains("segment") || l.contains("action")) &&
               (l.contains("duration") || l.contains("total") || l.contains("seconds")) {
                if let parsed = parseIntList(from: s) { return parsed }
            }
        }
    }
    return nil
}

private func rawPhaseIndexZeroBased(_ state: HabitTimerActivityAttributes.ContentState) -> Int? {
    for key in ["phaseIndexZeroBased","currentPhaseIndexZeroBased","stepIndexZeroBased","actionIndexZeroBased","currentActionIndexZeroBased"] {
        if let v = contentStateInt(state, key: key) { return v }
    }
    return nil
}

private func rawPhaseIndexOneBased(_ state: HabitTimerActivityAttributes.ContentState) -> Int? {
    for key in ["phaseIndex","currentPhaseIndex","stepIndex","actionIndex","currentActionIndex","phaseNumber","currentPhaseNumber","stepNumber","actionNumber"] {
        if let v = contentStateInt(state, key: key) { return v }
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

private func phaseTotal(from state: HabitTimerActivityAttributes.ContentState) -> Int? {
    // Try common keys so we don't create a hard dependency
    return contentStateInt(state, key: "phaseTotal")
        ?? contentStateInt(state, key: "currentPhaseTotal")
        ?? contentStateInt(state, key: "stepTotal")
        ?? contentStateInt(state, key: "actionTotal")
}

private func isActivePhaseName(_ name: String) -> Bool {
    let n = name.lowercased()
    // Count only real action phases; ignore start/pause/end-like labels
    if n.contains("pause") || n.contains("pausiert") || n.contains("start") || n.contains("ende") || n.contains("finish") || n.contains("fertig") {
        return false
    }
    // Treat labels like "aktiv 1", "aktion 2" as active
    return n.contains("aktiv") || n.contains("aktion") || n.contains("action")
}


private func phaseCount(from state: HabitTimerActivityAttributes.ContentState) -> Int? {
    // Prefer deriving from explicit durations: count only phases with time > 0
    if let arr = findPhaseDurationsArray(state) {
        let c = arr.filter { $0 > 0 }.count
        return c > 0 ? c : nil
    }
    // Fallbacks: counts provided by the state (may include all phases)
    for key in [
        "actionCount", "totalActions", "currentActionCount",
        "phaseCount", "totalPhases", "currentPhaseCount",
        "stepCount", "stepsCount", "phasesTotal", "totalSteps"
    ] {
        if let v = contentStateInt(state, key: key) { return v }
    }
    return nil
}

private func phaseIndex(from state: HabitTimerActivityAttributes.ContentState) -> Int? {
    if let arr = findPhaseDurationsArray(state), !arr.isEmpty {
        let hasAnyNonZero = arr.contains { $0 > 0 }
        if let z = rawPhaseIndexZeroBased(state) { // zero-based raw index from engine
            let zi = max(0, min(arr.count - 1, z))
            let nonZeroPos = arr[0...zi].filter { $0 > 0 }.count
            if nonZeroPos > 0 { return nonZeroPos } // 1-based among >0 phases
            // If we're still before the first non-zero phase, start display at 1
            return hasAnyNonZero ? 1 : nil
        }
        if let o = rawPhaseIndexOneBased(state) { // one-based raw index from engine
            let zi = max(1, min(arr.count, o)) - 1
            let nonZeroPos = arr[0...zi].filter { $0 > 0 }.count
            if nonZeroPos > 0 { return nonZeroPos }
            return hasAnyNonZero ? 1 : nil
        }
    }
    // Fallbacks when no durations array is available
    for key in ["currentPhaseIndex", "phaseIndex", "phaseNumber", "currentPhaseNumber"] { // assume 1-based
        if let v = contentStateInt(state, key: key) { return max(1, v) }
    }
    for key in ["actionIndex", "currentActionIndex"] { // assume 1-based
        if let v = contentStateInt(state, key: key) { return max(1, v) }
    }
    if let name = phaseName(from: state) { // last resort: extract number from name
        let digits = name.compactMap { $0.isNumber ? $0 : nil }
        if !digits.isEmpty, let n = Int(String(digits)) { return max(1, n) }
    }
    return nil
}

private func phasePositionString(from state: HabitTimerActivityAttributes.ContentState) -> String? {
    guard let total = phaseCount(from: state), total > 0,
          let rawIndex = phaseIndex(from: state) else { return nil }
    let display = max(1, min(total, rawIndex))
    print("[Widget] counter idx=\(display)/\(total) durations=\(findPhaseDurationsArray(state) ?? []) rawZ=\(rawPhaseIndexZeroBased(state) ?? -1) rawO=\(rawPhaseIndexOneBased(state) ?? -1)")
    return "\(display)/\(total)"
}

private func phaseProgress(state: HabitTimerActivityAttributes.ContentState) -> Double {
    if let rem = state.currentPhaseRemaining, let total = phaseTotal(from: state), total > 0 {
        let clampedRem = max(0, min(total, rem))
        let done = total - clampedRem
        return Double(done) / Double(total)
    }
    // Fallback to overall progress when we don't know the phase total
    return progress(state: state)
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


