import Foundation
import SwiftUI
import WidgetKit

enum TimerLogStatus: String, Codable, Hashable {
    case completed
    case aborted
    case skipped
}

struct TimerLogEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var habitID: UUID
    var title: String
    var date: Date
    /// Deprecated in favor of `status`, kept for UI/back-compat
    var completed: Bool       // true = beendet, false = abgebrochen/ausgelassen
    var plannedSeconds: Int   // geplante Gesamtdauer beim Start
    var elapsedSeconds: Int   // tatsächlich gelaufene Zeit
    var status: TimerLogStatus

    init(id: UUID = UUID(), habitID: UUID, title: String, date: Date, completed: Bool, plannedSeconds: Int, elapsedSeconds: Int, status: TimerLogStatus) {
        self.id = id
        self.habitID = habitID
        self.title = title
        self.date = date
        self.completed = completed
        self.plannedSeconds = plannedSeconds
        self.elapsedSeconds = elapsedSeconds
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id, habitID, title, date, completed, plannedSeconds, elapsedSeconds, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        habitID = try c.decode(UUID.self, forKey: .habitID)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        plannedSeconds = try c.decode(Int.self, forKey: .plannedSeconds)
        elapsedSeconds = try c.decode(Int.self, forKey: .elapsedSeconds)
        if let decodedStatus = try c.decodeIfPresent(TimerLogStatus.self, forKey: .status) {
            status = decodedStatus
            completed = (decodedStatus == .completed)
        } else {
            // Backwards compatibility: derive status from legacy `completed`
            let legacyCompleted = (try? c.decode(Bool.self, forKey: .completed)) ?? false
            completed = legacyCompleted
            status = legacyCompleted ? .completed : .aborted
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(habitID, forKey: .habitID)
        try c.encode(title, forKey: .title)
        try c.encode(date, forKey: .date)
        try c.encode(plannedSeconds, forKey: .plannedSeconds)
        try c.encode(elapsedSeconds, forKey: .elapsedSeconds)
        // keep writing legacy `completed` for UI/back-compat
        try c.encode(completed, forKey: .completed)
        try c.encode(status, forKey: .status)
    }
}

private let appGroupID = "group.de.frankreuter.habittimer" // <- HIER DEINE GRUPPE
private var sharedDefaults: UserDefaults {
    UserDefaults(suiteName: appGroupID) ?? .standard
}

@MainActor
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = [] { didSet { save() } }
    @Published var completions: [UUID: Set<String>] = [:] { didSet { save() } }
    @Published var logs: [TimerLogEntry] = [] { didSet { save() } }

    private let habitsKey = "habits_v1"
    private let completionsKey = "completions_v1"
    private let logsKey = "logs_v1"
    private let lastSeenKey = "lastSeen_v1"
    private var lastSeenDate: Date? { didSet { saveLastSeen() } }

    init() { load() }

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = Locale(identifier: "de_DE")
        return c
    }

    private func dayKey(for date: Date = Date()) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    func isScheduledToday(_ habit: Habit, on date: Date = Date()) -> Bool {
        let wd = HabitDay(rawValue: calendar.component(.weekday, from: date))
        guard let wd else { return false }
        return habit.activeDays.contains(wd)
    }

    func isCompletedToday(_ habit: Habit) -> Bool {
        let key = dayKey()
        return completions[habit.id]?.contains(key) ?? false
    }

    func markCompletedToday(_ habit: Habit) {
        let key = dayKey()
        var set = completions[habit.id] ?? []
        set.insert(key)
        completions[habit.id] = set
    }

    func resetCompletionToday(_ habit: Habit) {
        let key = dayKey()
        var set = completions[habit.id] ?? []
        set.remove(key)
        completions[habit.id] = set
    }

    func update(_ habit: Habit) {
        if habits.contains(where: { $0.id == habit.id }) {
            // Reassign the whole array so Combine publishes a change and `didSet` calls `save()`
            habits = habits.map { $0.id == habit.id ? habit : $0 }
        } else {
            // Fallback: if not found, treat it as new
            habits.append(habit)
        }
    }

    var todaysHabits: [Habit] {
        habits.filter { isScheduledToday($0) && !isCompletedToday($0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func hasLog(for habit: Habit, on date: Date) -> Bool {
        logs.contains { $0.habitID == habit.id && calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func plannedSeconds(for habit: Habit) -> Int {
        if !habit.segments.isEmpty {
            return habit.segments.reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
        }
        return habit.minutes * 60 + habit.seconds
    }

    @discardableResult
    func markSkippedYesterday(for habit: Habit) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return false }
        // nur markieren, wenn der Habit gestern geplant war
        guard isScheduledToday(habit, on: yesterday) else { return false }
        // Duplikate vermeiden
        guard !hasLog(for: habit, on: yesterday) else { return false }

        let entry = TimerLogEntry(
            habitID: habit.id,
            title: habit.title,
            date: yesterday,
            completed: false,
            plannedSeconds: plannedSeconds(for: habit),
            elapsedSeconds: 0,
            status: .skipped
        )
        logs.insert(entry, at: 0)
        print("[HabitStore] markSkippedYesterday(): inserted for \(habit.title)")
        return true
    }

    // MARK: - Auto-Skip Backfill
    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func loadLastSeen() {
        if let t = sharedDefaults.object(forKey: lastSeenKey) as? TimeInterval {
            lastSeenDate = Date(timeIntervalSince1970: t)
            print("[HabitStore] loadLastSeen(): loaded=\(lastSeenDate!)")
        } else {
            lastSeenDate = nil
            print("[HabitStore] loadLastSeen(): none")
        }
    }

    private func saveLastSeen() {
        if let d = lastSeenDate {
            sharedDefaults.set(d.timeIntervalSince1970, forKey: lastSeenKey)
            print("[HabitStore] saveLastSeen(): saved=\(d)")
        }
    }

    /// Trägt für alle Tage seit `lastSeenDate` bis **gestern** automatisch `skipped` ein,
    /// falls der Habit an dem Tag aktiv war und kein Eintrag existiert.
    /// Setzt anschließend `lastSeenDate` auf den Start des heutigen Tages.
    func backfillSkippedSinceLastSeen(now: Date = Date()) {
        let today = startOfDay(now)
        if lastSeenDate == nil {
            // Erste Initialisierung: nicht rückwirkend alles skippen
            lastSeenDate = today
            print("[HabitStore] backfill: initialized lastSeenDate=\(today)")
            return
        }
        guard let from = lastSeenDate, from < today else {
            print("[HabitStore] backfill: up-to-date (lastSeen=\(String(describing: lastSeenDate)))")
            return
        }

        var day = calendar.date(byAdding: .day, value: 1, to: startOfDay(from)) ?? from
        var inserted = 0
        while day < today {
            for habit in habits {
                guard isScheduledToday(habit, on: day) else { continue }
                guard !hasLog(for: habit, on: day) else { continue }
                let entry = TimerLogEntry(
                    habitID: habit.id,
                    title: habit.title,
                    date: day,
                    completed: false,
                    plannedSeconds: plannedSeconds(for: habit),
                    elapsedSeconds: 0,
                    status: .skipped
                )
                logs.insert(entry, at: 0)
                inserted += 1
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? today
        }
        lastSeenDate = today
        print("[HabitStore] backfill: inserted=\(inserted), lastSeenDate=\(today)")
    }

    // MARK: Persistence (+ Widget Reload)
    private func save() {
        let encoder = JSONEncoder()
        print("[HabitStore] save(): habits=\(habits.count) completionsKeys=\(completions.count) logs=\(logs.count)")

        do {
            let data = try encoder.encode(habits)
            sharedDefaults.set(data, forKey: habitsKey)
            print("[HabitStore] save(): wrote habits (\(data.count) bytes) → key=\(habitsKey)")
        } catch {
            print("[HabitStore] save(): FAILED to encode habits → \(error)")
        }

        do {
            let data = try encoder.encode(completions)
            sharedDefaults.set(data, forKey: completionsKey)
            print("[HabitStore] save(): wrote completions (\(data.count) bytes) → key=\(completionsKey)")
        } catch {
            print("[HabitStore] save(): FAILED to encode completions → \(error)")
        }

        do {
            let data = try encoder.encode(logs)
            sharedDefaults.set(data, forKey: logsKey)
            print("[HabitStore] save(): wrote logs (\(data.count) bytes) → key=\(logsKey)")
        } catch {
            print("[HabitStore] save(): FAILED to encode logs → \(error)")
        }

        WidgetCenter.shared.reloadAllTimelines()
        print("[HabitStore] save(): WidgetCenter.reloadAllTimelines() called")
    }

    private func load() {
        let decoder = JSONDecoder()
        print("[HabitStore] load(): using suite=\(appGroupID)")

        if let data = sharedDefaults.data(forKey: habitsKey) {
            if let decoded = try? decoder.decode([Habit].self, from: data) {
                self.habits = decoded
                print("[HabitStore] load(): loaded habits count=\(decoded.count)")
            } else {
                print("[HabitStore] load(): FAILED to decode habits (\(data.count) bytes), using defaults")
                self.habits = [
                    Habit(title: "Zähneputzen (morgen)", minutes: 2, activeDays: Set(HabitDay.allCases)),
                    Habit(title: "Zähneputzen (abends)", minutes: 2, activeDays: Set(HabitDay.allCases)),
                    Habit(title: "Rückentraining", minutes: 5, activeDays: Set(HabitDay.allCases)),
                    Habit(title: "Meditieren", minutes: 10, activeDays: Set(HabitDay.allCases))
                ]
            }
        } else {
            print("[HabitStore] load(): no habits data, seeding defaults")
            self.habits = [
                Habit(title: "Zähneputzen (morgen)", minutes: 2, activeDays: Set(HabitDay.allCases)),
                Habit(title: "Zähneputzen (abends)", minutes: 2, activeDays: Set(HabitDay.allCases)),
                Habit(title: "Rückentraining", minutes: 5, activeDays: Set(HabitDay.allCases)),
                Habit(title: "Meditieren", minutes: 10, activeDays: Set(HabitDay.allCases))
            ]
        }

        if let data = sharedDefaults.data(forKey: completionsKey) {
            if let decoded = try? decoder.decode([UUID: Set<String>].self, from: data) {
                self.completions = decoded
                print("[HabitStore] load(): loaded completions keys=\(decoded.keys.count)")
            } else {
                print("[HabitStore] load(): FAILED to decode completions (\(data.count) bytes)")
            }
        } else {
            print("[HabitStore] load(): no completions data")
        }

        if let data = sharedDefaults.data(forKey: logsKey) {
            if let decoded = try? decoder.decode([TimerLogEntry].self, from: data) {
                self.logs = decoded
                print("[HabitStore] load(): loaded logs count=\(decoded.count)")
            } else {
                print("[HabitStore] load(): FAILED to decode logs (\(data.count) bytes); initializing empty")
                self.logs = []
            }
        } else {
            print("[HabitStore] load(): no logs data; initializing empty")
            self.logs = []
        }
        // Load last seen day marker
        loadLastSeen()
        if lastSeenDate == nil {
            // On first install, start tracking from today
            lastSeenDate = startOfDay(Date())
        }
    }
    
    func log(habit: Habit, completed: Bool, plannedSeconds: Int, elapsedSeconds: Int) {
        let before = logs.count
        print("[HabitStore] log(): adding entry title=\(habit.title), completed=\(completed), planned=\(plannedSeconds), elapsed=\(elapsedSeconds), beforeCount=\(before)")
        let status: TimerLogStatus = completed ? .completed : .aborted
        let entry = TimerLogEntry(
            habitID: habit.id,
            title: habit.title,
            date: Date(),
            completed: completed,
            plannedSeconds: max(0, plannedSeconds),
            elapsedSeconds: max(0, min(elapsedSeconds, plannedSeconds)),
            status: status
        )
        logs.insert(entry, at: 0) // neueste zuerst
        print("[HabitStore] log(): inserted, afterCount=\(logs.count)")
    }

    // MARK: - Log Helpers
    /// Löscht alle Logbucheinträge (nur zu Testzwecken)
    func clearLogs() {
        print("[HabitStore] clearLogs(): before=\(logs.count)")
        logs.removeAll()
        print("[HabitStore] clearLogs(): after=\(logs.count)")
    }

    /// Alle Log-Einträge für HEUTE (lokales Datum)
    func logsForToday() -> [TimerLogEntry] {
        logs.filter { calendar.isDateInToday($0.date) }
    }

    /// Alle Log-Einträge zu einem bestimmten Habit (neueste zuerst)
    func logs(for habit: Habit) -> [TimerLogEntry] {
        logs.filter { $0.habitID == habit.id }
    }
}
