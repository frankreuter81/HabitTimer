import SwiftUI
import UserNotifications
import Combine

struct CountdownView: View {
    let habit: Habit
    var onFinished: (() -> Void)? = nil
    var onUpdate: ((Habit) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: HabitStore

    @State private var title: String = ""
    @State private var segments: [HabitSegment]
    @State private var currentIndex: Int = 0
    @State private var remaining: Int = 0
    @State private var timerActive = false
    @State private var showEdit = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(habit: Habit, onFinished: (() -> Void)? = nil, onUpdate: ((Habit) -> Void)? = nil) {
        self.habit = habit
        self.onFinished = onFinished
        self.onUpdate = onUpdate
        _title = State(initialValue: habit.title)
        _segments = State(initialValue: habit.segments)
    }

    private func label(for index: Int) -> String {
        guard segments.indices.contains(index) else { return "–" }
        let seg = segments[index]
        switch seg.type {
        case .start: return HabitSegment.Kind.start.rawValue
        case .end:   return HabitSegment.Kind.end.rawValue
        case .active, .pause:
            let siblings = segments.filter { $0.type == seg.type }
            if let pos = siblings.firstIndex(where: { $0.id == seg.id }) {
                return "\(seg.type.rawValue) \(pos + 1)"
            }
            return seg.type.rawValue
        }
    }

    private func isStopSegment(at index: Int) -> Bool {
        guard segments.indices.contains(index) else { return false }
        let seg = segments[index]
        return seg.type == .pause && seg.isStop
    }

    private func durationString(for index: Int) -> String {
        guard segments.indices.contains(index) else { return "00:00" }
        if isStopSegment(at: index) { return "Stop" }
        let total = max(0, Int(segments[index].duration.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func format(_ seconds: Int) -> String {
        let secs = max(0, seconds)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private var totalSeconds: Int {
        segments.reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
    }

    private var totalTimeString: String { format(totalSeconds) }

    private var remainingTotalSeconds: Int {
        guard segments.indices.contains(currentIndex) else { return 0 }
        let tail = (currentIndex + 1 < segments.count)
            ? segments[(currentIndex + 1)...].reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
            : 0
        return max(0, remaining) + tail
    }
    private var elapsedSecondsSoFar: Int { max(0, totalSeconds - remainingTotalSeconds) }

    private var remainingTotalTimeString: String { format(remainingTotalSeconds) }

    private var isPaused: Bool {
        !timerActive && remaining > 0
    }

    private func jumpToFirstPlayable() {
        // Start at first segment; if duration is 0, skip forward
        currentIndex = min(max(0, currentIndex), max(0, segments.count - 1))
        while segments.indices.contains(currentIndex), Int(segments[currentIndex].duration) == 0, currentIndex < segments.count - 1 {
            currentIndex += 1
        }
        remaining = segments.indices.contains(currentIndex) ? max(0, Int(segments[currentIndex].duration)) : 0
    }

    private func advance() {
        // Move to next segment; skip zero-length segments
        if currentIndex < segments.count - 1 {
            currentIndex += 1
            remaining = max(0, Int(segments[currentIndex].duration))
            // Stop-Pause: Timer anhalten und hier warten, nicht automatisch weiter
            if isStopSegment(at: currentIndex) {
                timerActive = false
                return
            }
            // Zero-Duration (Start/Ende oder versehentlich 0): automatisch überspringen
            if remaining == 0 { advance() }
        } else {
            // Finished all segments
            timerActive = false

            // Log-Eintrag anlegen (nur bei echtem Abschluss)
            let finishedAt = Date()
            let total = segments.reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
            store.log(
                habit: habit,
                completed: true,
                plannedSeconds: total,
                elapsedSeconds: total
            )

            onFinished?()
            let finishedTitle = title
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationManager.shared.notifyTimerFinished(title: finishedTitle)
            }
        }
    }
    
    private func resetTimer() {
        timerActive = false
        currentIndex = 0
        jumpToFirstPlayable()
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(spacing: 6) {
                Text("Restzeit:")
                    .foregroundStyle(.secondary)
                Text(remainingTotalTimeString)
                    .bold()
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Text(label(for: currentIndex))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Text(timeString)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)

            let nextIndex = min(currentIndex + 1, segments.count - 1)
            if segments.indices.contains(nextIndex), nextIndex != currentIndex {
                VStack(spacing: 4) {
                    Text("Nächster:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(label(for: nextIndex)).bold()
                        Text("–")
                        Text(durationString(for: nextIndex))
                    }
                    .font(.body)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button {
                    if timerActive {
                        timerActive = false
                    } else {
                        // (Weiter)Start: Wenn wir auf einem Stop-Pause-Segment stehen, erst weiter springen
                        if isStopSegment(at: currentIndex) {
                            advance()
                        }
                        // nur starten, wenn wir nicht sofort am Ende sind
                        timerActive = true
                    }
                } label: {
                    Label(timerActive ? "Pause" : (isPaused ? "Weiter" : "Start"),
                          systemImage: timerActive ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    store.log(
                        habit: habit,
                        completed: false,
                        plannedSeconds: totalSeconds,
                        elapsedSeconds: elapsedSecondsSoFar
                    )
                    resetTimer()
                } label: {
                    Label("Abbrechen", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                EditHabitView(habit: habit, onSave: { updated in
                    onUpdate?(updated)
                    title = updated.title
                    segments = updated.segments
                    currentIndex = 0
                    jumpToFirstPlayable()
                    showEdit = false
                })
                    .navigationTitle("Timer bearbeiten")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Fertig") { showEdit = false } }
                    }
            }
        }
        .padding()
        .onAppear {
            segments = habit.segments

            title = habit.title

            if segments.isEmpty {
                segments = [HabitSegment(type: .start, duration: 0), HabitSegment(type: .end, duration: 0)]
            }
            currentIndex = 0
            jumpToFirstPlayable()
        }
        .onChange(of: habit.segments.map(\.id)) { _ in
            segments = habit.segments
            currentIndex = 0
            jumpToFirstPlayable()
        }
        .onChange(of: habit.title) { newTitle in
            title = newTitle
        }
        .onReceive(tick) { _ in
            guard timerActive else { return }
            if remaining > 1 {
                remaining -= 1
            } else {
                remaining = 0
                advance()
            }
        }
    }
}

#Preview("Countdown – Demo") {
    let demoHabit = Habit(
        title: "Demo-Timer",
        activeDays: Set(HabitDay.allCases),
        minutes: 0,
        segments: [
            HabitSegment(type: .start,  duration: 0),
            HabitSegment(type: .active, duration: 120),
            HabitSegment(type: .pause,  duration: 30),
            HabitSegment(type: .active, duration: 60),
            HabitSegment(type: .end,    duration: 0)
        ]
    )

    return NavigationStack {
        CountdownView(habit: demoHabit)
    }
    .environmentObject(HabitStore())
}
