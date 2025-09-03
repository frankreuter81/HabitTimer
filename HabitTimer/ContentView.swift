import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: HabitStore
    @State private var showingAdd = false
    @State private var editingHabit: Habit? = nil
    @State private var showAll: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if todays.isEmpty && otherHabits.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Timer",
                        systemImage: "list.bullet",
                        description: Text("Lege mit dem Plus oben rechts neue Timer an.")
                    )
                } else {
                    List {
                        if !todays.isEmpty {
                            TodayListSection(
                                habits: todays,
                                done: markDone,
                                skipYesterday: skipYesterday,
                                edit: beginEdit,
                                update: { store.update($0) }
                            )
                        }
                        AllListSection(
                            habits: otherHabits,
                            showAll: $showAll,
                            done: markDone,
                            skipYesterday: skipYesterday,
                            edit: beginEdit,
                            update: { store.update($0) }
                        )
                        Section {
                            NavigationLink {
                                LogbookScreen()
                            } label: {
                                Label("Logbuch", systemImage: "book.closed")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("HabitTimer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Label("Neu", systemImage: "plus") }
                }
            }
            .sheet(item: $editingHabit) { habit in
                EditHabitView(habit: habit) { updated in
                    store.update(updated)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddHabitView { newHabit in
                    store.habits.append(newHabit)
                }
            }
        }
    }

    // MARK: - Actions
    private func beginEdit(_ habit: Habit) { editingHabit = habit }
    private func markDone(_ habit: Habit) { withAnimation { store.markCompletedToday(habit) } }
    private func skipYesterday(_ habit: Habit) {
        withAnimation {
            _ = self.store.markSkippedYesterday(for: habit)
        }
    }

    // MARK: - Sortier-Helfer
    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = Locale(identifier: "de_DE")
        return c
    }

    private func daysUntilNext(for habit: Habit, from date: Date = Date()) -> Int {
        let today = calendar.component(.weekday, from: date)
        let deltas = habit.activeDays.map { day -> Int in
            let d = (day.rawValue - today + 7) % 7
            return d == 0 ? 7 : d
        }
        return deltas.min() ?? 7
    }

    // MARK: - Ableitungen
    private var todays: [Habit] { store.todaysHabits }

    private var otherHabits: [Habit] {
        let todayIDs = Set(todays.map { $0.id })
        return store.habits
            .filter { !todayIDs.contains($0.id) }
            .sorted { a, b in
                let da = daysUntilNext(for: a)
                let db = daysUntilNext(for: b)
                if da != db { return da < db }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
    }
}

// MARK: - Unteransichten
struct TodayListSection: View {
    let habits: [Habit]
    var done: (Habit) -> Void
    var skipYesterday: (Habit) -> Void
    var edit: (Habit) -> Void
    var update: (Habit) -> Void

    var body: some View {
        Section("Heute") {
            ForEach(habits) { habit in
                NavigationLink {
                    CountdownView(
                        habit: habit,
                        onFinished: { done(habit) },
                        onUpdate: { update($0) }
                    )
                } label: {
                    HabitListRow(habit: habit)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button { done(habit) } label: { Label("Erledigt", systemImage: "checkmark") }.tint(.green)
                    Button { skipYesterday(habit) } label: { Label("Gestern ausgelassen", systemImage: "calendar.badge.exclamationmark") }.tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button { edit(habit) } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.blue)
                }
            }
        }
    }
}

struct AllListSection: View {
    let habits: [Habit]
    @Binding var showAll: Bool
    var done: (Habit) -> Void
    var skipYesterday: (Habit) -> Void
    var edit: (Habit) -> Void
    var update: (Habit) -> Void

    var body: some View {
        Section {
            Button { withAnimation { showAll.toggle() } } label: {
                HStack {
                    Label("Alle", systemImage: "list.bullet")
                    Spacer()
                    Text("\(habits.count)").foregroundStyle(.secondary)
                    Image(systemName: showAll ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        if showAll, !habits.isEmpty {
            Section {
                ForEach(habits) { habit in
                    NavigationLink {
                        CountdownView(
                            habit: habit,
                            onFinished: { done(habit) },
                            onUpdate: { update($0) }
                        )
                    } label: {
                        HabitListRow(habit: habit)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button { done(habit) } label: { Label("Erledigt", systemImage: "checkmark") }.tint(.green)
                        Button { skipYesterday(habit) } label: { Label("Gestern ausgelassen", systemImage: "calendar.badge.exclamationmark") }.tint(.red)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { edit(habit) } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.blue)
                    }
                }
            }
        }
    }
}

struct HabitListRow: View {
    let habit: Habit
    @EnvironmentObject var store: HabitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.headline)
                    Text("\(formatDuration(habit)) • " + dayString(habit.activeDays))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let rem = store.sessionRemainingTotalSeconds(for: habit) {
                    let isRunning = store.isRunning(habit)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isRunning ? "Aktiv" : "Pausiert")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background((isRunning ? Color.green : Color.orange).opacity(0.15))
                            .clipShape(Capsule())
                        Label(formatSeconds(rem), systemImage: isRunning ? "timer" : "pause")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let p = progressFraction(for: habit) {
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                    .tint(.green)
            }
        }
        .contentShape(Rectangle())
    }

    private func plannedSeconds(_ habit: Habit) -> Int {
        if !habit.segments.isEmpty {
            return habit.segments.reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
        }
        return habit.minutes * 60 + habit.seconds
    }

    private func progressFraction(for habit: Habit) -> Double? {
        guard let remaining = store.sessionRemainingTotalSeconds(for: habit) else { return nil }
        let total = plannedSeconds(habit)
        guard total > 0 else { return nil }
        let done = max(0, total - remaining)
        return max(0, min(1, Double(done) / Double(total)))
    }

    private func dayString(_ days: Set<HabitDay>) -> String {
        let ordered = HabitDay.allCases.filter { days.contains($0) }
        return ordered.map { $0.shortLabel }.joined(separator: ", ")
    }

    private func formatDuration(_ habit: Habit) -> String {
        let totalSeconds: Int
        if !habit.segments.isEmpty {
            totalSeconds = habit.segments.reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
        } else {
            totalSeconds = habit.minutes * 60 + habit.seconds
        }
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    private func formatSeconds(_ s: Int) -> String {
        let s = max(0, s)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

struct LogbookScreen: View {
    @EnvironmentObject var store: HabitStore

    var body: some View {
        Group {
            if store.logs.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "book",
                    description: Text("Beende oder brich einen Timer ab, um Einträge zu sehen.")
                )
            } else {
                List(store.logs) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: meta(for: entry.status).icon)
                            .foregroundStyle(meta(for: entry.status).color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Label(format(entry.elapsedSeconds), systemImage: "hourglass")
                                Text("von \(format(entry.plannedSeconds))")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }

                        Spacer()

                        Text(meta(for: entry.status).text)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(meta(for: entry.status).color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Logbuch")
    }

    private func meta(for status: TimerLogStatus) -> (icon: String, color: Color, text: String) {
        switch status {
        case .completed:
            return ("checkmark.circle.fill", .green, "Beendet")
        case .aborted:
            return ("xmark.circle.fill", .orange, "Abgebrochen")
        case .skipped:
            return ("xmark.circle.fill", .red, "Ausgelassen")
        }
    }

    private func format(_ secs: Int) -> String {
        let s = max(0, secs)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}
