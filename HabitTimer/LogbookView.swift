import SwiftUI

struct LogbookView: View {
    @EnvironmentObject var store: HabitStore

    var body: some View {
        List {
            if store.logs.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "book.closed",
                    description: Text("Starte einen Timer – hier erscheint dann das Protokoll.")
                )
            } else {
                ForEach(store.logs) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.completed ? .green : .red)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)

                            Text(entry.date, style: .date) + Text(" · ") + Text(entry.date, style: .time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Geplant: \(fmt(entry.plannedSeconds)) · Gelaufen: \(fmt(entry.elapsedSeconds))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Logbuch")
    }
}

private func fmt(_ s: Int) -> String {
    let m = s / 60
    let sec = s % 60
    return String(format: "%d:%02d", m, sec)
}

#Preview {
    LogbookView()
        .environmentObject(HabitStore())
}
