import Foundation
import SwiftUI
import WidgetKit
import Combine
import ActivityKit
import os
#if canImport(AppIntents)
import AppIntents
#endif


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

private let habitLog = Logger(subsystem: "de.frankreuter.habittimer", category: "HabitStore")

@MainActor
final class HabitStore: ObservableObject {
    // Shared reference so AppIntents can control the running store instance
    static var shared: HabitStore?
    @Published var habits: [Habit] = [] { didSet { save() } }
    @Published var completions: [UUID: Set<String>] = [:] { didSet { save() } }
    @Published var logs: [TimerLogEntry] = [] { didSet { save() } }

    // MARK: - Background timer sessions
    struct BackgroundSession {
        var habitID: UUID
        var currentIndex: Int
        var remaining: Int
        var segments: [HabitSegment]
        var active: Bool
    }

    @Published var backgroundSessions: [UUID: BackgroundSession] = [:]
    private var backgroundTicker: AnyCancellable?

    #if canImport(ActivityKit)
    // MARK: - Live Activity helpers
    @available(iOS 16.1, *)
    private func findActivity(for habitID: UUID) -> Activity<HabitTimerActivityAttributes>? {
        let all = Activity<HabitTimerActivityAttributes>.activities
        let match = all.first { $0.attributes.habitID == habitID.uuidString }
        #if DEBUG
        print("[LiveActivity] findActivity: activities=\(all.count), match=\(match != nil)")
        #endif
        return match
    }

    private func updateLiveActivity(for habit: Habit, remaining: Int, paused: Bool) {
        guard remaining >= 0 else { return }
        if #available(iOS 16.1, *) {
            let auth = ActivityAuthorizationInfo()
            if !auth.areActivitiesEnabled {
                habitLog.warning("[LiveActivity] not enabled; skip update (remaining=\(remaining), paused=\(paused, privacy: .public))")
                return
            }
            let state = HabitTimerActivityAttributes.ContentState(title: habit.title, remaining: max(0, remaining), paused: paused, total: plannedSeconds(for: habit))
            if let act = findActivity(for: habit.id) {
                habitLog.info("[LiveActivity] update existing activity for \(habit.title, privacy: .public)")
                Task {
                    if #available(iOS 16.2, *) {
                        await act.update(ActivityContent(state: state, staleDate: nil))
                    } else {
                        await act.update(using: state)
                    }
                }
            } else {
                habitLog.info("[LiveActivity] request creating new activity for \(habit.title, privacy: .public)")
                do {
                    let attrs = HabitTimerActivityAttributes(habitID: habit.id.uuidString)
                    if #available(iOS 16.2, *) {
                        let content = ActivityContent(state: state, staleDate: nil)
                        let activity = try Activity.request(attributes: attrs, content: content, pushType: nil)
                        habitLog.info("[LiveActivity] started id=\(activity.id, privacy: .public) habitID=\(habit.id.uuidString, privacy: .public)")
                    } else {
                        let activity = try Activity.request(attributes: attrs, contentState: state, pushType: nil)
                        habitLog.info("[LiveActivity] started (16.1) id=\(activity.id, privacy: .public) habitID=\(habit.id.uuidString, privacy: .public)")
                    }
                } catch {
                    habitLog.error("[LiveActivity] request FAILED: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    func endLiveActivity(for habit: Habit) {
        if #available(iOS 16.1, *) {
            habitLog.info("[LiveActivity] end: \(habit.title, privacy: .public)")
            for act in Activity<HabitTimerActivityAttributes>.activities where act.attributes.habitID == habit.id.uuidString {
                Task {
                    if #available(iOS 16.2, *) {
                        await act.end(ActivityContent(state: act.content.state, staleDate: nil), dismissalPolicy: .immediate)
                    } else {
                        await act.end(dismissalPolicy: .immediate)
                    }
                }
            }
        }
    }

    @available(iOS 16.1, *)
    func debugDumpLiveActivities() {
        let all = Activity<HabitTimerActivityAttributes>.activities
        print("[LiveActivity] dump: count=\(all.count)")
        for a in all { print("  id=\(a.id), habitID=\(a.attributes.habitID ?? "-" )") }
    }
    #endif

    private func totalRemaining(for sess: BackgroundSession) -> Int {
        let tail: Int
        if sess.currentIndex + 1 < sess.segments.count {
            tail = sess.segments[(sess.currentIndex + 1)...].reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
        } else {
            tail = 0
        }
        return max(0, sess.remaining + tail)
    }

    /// Public wrapper: allow views to update the Live Activity while in foreground (no background session needed)
    func updateLiveActivityFromForeground(habit: Habit, remainingTotalSeconds: Int, paused: Bool) {
#if canImport(ActivityKit)
        self.updateLiveActivity(for: habit, remaining: remainingTotalSeconds, paused: paused)
#else
        // no-op when ActivityKit is unavailable
#endif
    }

    func beginBackgroundRun(habit: Habit, currentIndex: Int, remaining: Int, active: Bool = true) {
        backgroundSessions[habit.id] = BackgroundSession(
            habitID: habit.id,
            currentIndex: currentIndex,
            remaining: max(0, remaining),
            segments: habit.segments,
            active: active
        )
        // Update Live Activity state (start if needed)
        if let sess = backgroundSessions[habit.id] {
            let total = totalRemaining(for: sess)
            updateLiveActivity(for: habit, remaining: total, paused: !active)
        }
    }

    func pauseBackgroundRun(habit: Habit) {
        backgroundSessions[habit.id]?.active = false
        if let sess = backgroundSessions[habit.id], let habitObj = habits.first(where: { $0.id == habit.id }) {
            let total = totalRemaining(for: sess)
            updateLiveActivity(for: habitObj, remaining: total, paused: true)
        }
    }

    /// Toggles pause/resume for a habit and updates the Live Activity accordingly.
    func togglePause(habit: Habit) {
        if isPaused(habit) {
            resumeBackgroundRun(habit: habit)
        } else {
            pauseBackgroundRun(habit: habit)
        }
    }

    /// Setzt eine pausierte Sitzung fort oder startet sie neu, wenn keine Sitzung existiert
    func resumeBackgroundRun(habit: Habit) {
        if var sess = backgroundSessions[habit.id] {
            sess.active = true
            backgroundSessions[habit.id] = sess
            let total = totalRemaining(for: sess)
            updateLiveActivity(for: habit, remaining: total, paused: false)
        } else {
            // Keine Sitzung vorhanden → mit voller geplanter Dauer neu starten
            let remaining = plannedSeconds(for: habit)
            beginBackgroundRun(habit: habit, currentIndex: 0, remaining: remaining, active: true)
        }
    }

    /// Cancels any running/paused session for the habit and ends the Live Activity.
    func cancel(habit: Habit) {
        endLiveActivity(for: habit)
        stopBackgroundRun(habit: habit)
    }

    /// Verarbeitet Deeplinks wie:
    /// habittimer://live?habit=<UUID>&action=pause|resume|cancel
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.scheme?.lowercased() == "habittimer",
              (comps.host?.lowercased() == "live" || comps.path.lowercased().hasPrefix("/live"))
        else {
            return false
        }
        let items = comps.queryItems ?? []
        let habitIDString = items.first(where: { $0.name == "habit" })?.value
        let action = (items.first(where: { $0.name == "action" })?.value ?? "").lowercased()
        guard let idStr = habitIDString, let id = UUID(uuidString: idStr),
              let habit = habits.first(where: { $0.id == id }) else {
            #if DEBUG
            print("[DeepLink] invalid or missing habit id: \(habitIDString ?? "-")")
            #endif
            return false
        }
        #if DEBUG
        print("[DeepLink] action=\(action) habit=\(habit.title) (\(habit.id))")
        #endif
        switch action {
        case "pause":
            pauseBackgroundRun(habit: habit)
            return true
        case "resume", "play", "start":
            resumeBackgroundRun(habit: habit)
            return true
        case "cancel", "stop", "end":
            endLiveActivity(for: habit)
            stopBackgroundRun(habit: habit)
            return true
        default:
            // Unbekannte Aktion → nur App öffnen
            return false
        }
    }

    func stopBackgroundRun(habit: Habit) {
        backgroundSessions[habit.id] = nil
    }

    func isRunning(_ habit: Habit) -> Bool {
        backgroundSessions[habit.id]?.active == true
    }

    func isPaused(_ habit: Habit) -> Bool {
        if let s = backgroundSessions[habit.id] {
            return s.active == false
        }
        return false
    }

    /// Remaining total seconds for any session (running or paused)
    func sessionRemainingTotalSeconds(for habit: Habit) -> Int? {
        guard let s = backgroundSessions[habit.id] else { return nil }
        let tail: Int
        if s.currentIndex + 1 < s.segments.count {
            tail = s.segments[(s.currentIndex + 1)...].reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
        } else {
            tail = 0
        }
        return max(0, s.remaining + tail)
    }

    /// Remaining total seconds for a running background session of the given habit (including following segments).
    func runningRemainingTotalSeconds(for habit: Habit) -> Int? {
        guard let s = backgroundSessions[habit.id], s.active else { return nil }
        let tail: Int
        if s.currentIndex + 1 < s.segments.count {
            tail = s.segments[(s.currentIndex + 1)...].reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
        } else {
            tail = 0
        }
        return max(0, s.remaining + tail)
    }

    private func isStopSegment(_ seg: HabitSegment) -> Bool {
        seg.type == .pause && seg.isStop
    }

    private func advanceBackground(_ s: inout BackgroundSession) -> Bool {
        if s.currentIndex < s.segments.count - 1 {
            s.currentIndex += 1
            s.remaining = max(0, Int(s.segments[s.currentIndex].duration.rounded()))
            if isStopSegment(s.segments[s.currentIndex]) {
                s.active = false
            }
            return true
        } else {
            return false // finished
        }
    }

    private func setupBackgroundTicker() {
        backgroundTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.backgroundSessions.isEmpty { return }
                var toRemove: [UUID] = []
                for (id, var sess) in self.backgroundSessions {
                    guard sess.active else { continue }
                    if sess.remaining > 0 {
                        sess.remaining -= 1
                        self.backgroundSessions[id] = sess
                        if let habit = self.habits.first(where: { $0.id == id }) {
                            let total = self.totalRemaining(for: sess)
                            self.updateLiveActivity(for: habit, remaining: total, paused: !sess.active)
                        }
                    } else {
                        // segment finished → advance
                        if self.advanceBackground(&sess) {
                            // auto-advance zero-duration segments (except Stop-Pause)
                            while sess.remaining == 0 && sess.currentIndex < sess.segments.count && !self.isStopSegment(sess.segments[sess.currentIndex]) {
                                if !self.advanceBackground(&sess) { break }
                            }
                            self.backgroundSessions[id] = sess
                            if let habit = self.habits.first(where: { $0.id == id }) {
                                let total = self.totalRemaining(for: sess)
                                self.updateLiveActivity(for: habit, remaining: total, paused: !sess.active)
                            }
                        } else {
                            // finished all → log completion and remove
                            if let habit = self.habits.first(where: { $0.id == id }) {
                                let total = sess.segments.reduce(0) { $0 + max(0, Int($1.duration.rounded())) }
                                self.log(habit: habit, completed: true, plannedSeconds: total, elapsedSeconds: total)
                                self.endLiveActivity(for: habit)
                            }
                            toRemove.append(id)
                        }
                    }
                }
                for id in toRemove { self.backgroundSessions[id] = nil }
            }
    }

    private let habitsKey = "habits_v1"
    private let completionsKey = "completions_v1"
    private let logsKey = "logs_v1"
    private let lastSeenKey = "lastSeen_v1"
    private var lastSeenDate: Date? { didSet { saveLastSeen() } }

    init() { load(); setupBackgroundTicker() }

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
        // Clamp a future lastSeenDate back to today (can happen after debug time-travel)
        if let last = lastSeenDate, last > today {
            print("[HabitStore] backfill: clamping future lastSeenDate=\(last) -> today=\(today)")
            lastSeenDate = today
        }
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
        endLiveActivity(for: habit)
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
