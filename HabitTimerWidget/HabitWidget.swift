import WidgetKit
import SwiftUI

// App Group & Keys (müssen zu deinem Store passen!)
private let appGroupID = "group.de.frankreuter.habittimer"
private let habitsKey = "habits_v1"
private let completionsKey = "completions_v1"

// MARK: - Entry
struct HabitEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let countOpen: Int
}

// MARK: - Provider
struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), title: "Heute", subtitle: "3 offene Timer", countOpen: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // Aus Shared Defaults lesen (App Group!)
    private func loadEntry() -> HabitEntry {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let decoder = JSONDecoder()

        var habits: [Habit] = []
        if let data = defaults.data(forKey: habitsKey),
           let decoded = try? decoder.decode([Habit].self, from: data) {
            habits = decoded
        }

        var completions: [UUID: Set<String>] = [:]
        if let data = defaults.data(forKey: completionsKey),
           let decoded = try? decoder.decode([UUID: Set<String>].self, from: data) {
            completions = decoded
        }

        var cal = Calendar.current; cal.locale = Locale(identifier: "de_DE")
        let weekday = HabitDay(rawValue: cal.component(.weekday, from: Date()))
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        let key = String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)

        let today = habits.filter { h in
            guard let wd = weekday else { return false }
            guard h.activeDays.contains(wd) else { return false }
            return !(completions[h.id]?.contains(key) ?? false)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        if today.isEmpty {
            return HabitEntry(date: Date(), title: "Alles erledigt!", subtitle: "🎉 Nichts offen", countOpen: 0)
        } else {
            let first = today.first!
            let subtitle = "Nächster: \(first.title) – \(first.minutes) min"
            return HabitEntry(date: Date(), title: "Heute", subtitle: subtitle, countOpen: today.count)
        }
    }
}

// MARK: - View
struct HabitWidgetEntryView: View {
    var entry: HabitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title).font(.headline)
            Text(entry.subtitle).font(.caption)
            Spacer()
            Text("\(entry.countOpen) offen")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .widgetURL(URL(string: "habittimer://today"))
    }
}

// MARK: - Widget (eine Konfiguration, Familien abhängig von iOS)
struct HabitWidget: Widget {
    let kind: String = "HabitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HabitTimer – Heute")
        .description("Zeigt deine offenen Timer für heute.")
        .supportedFamilies(families)
    }

    // iOS-abhängig – ohne if im WidgetBundle
    private var families: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryRectangular]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }
}

// MARK: - Bundle (ohne if!)
@main
struct HabitTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitWidget()
    }
}
