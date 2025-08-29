// MARK: - TimerSegment and SegmentType
struct TimerSegment: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: SegmentType
    var duration: TimeInterval
}

enum SegmentType: String, Codable, CaseIterable {
    case active = "Aktiv"
    case pause = "Pause"
}
import SwiftUI

// MARK: - WeekdayPicker (single row, one-letter labels)
struct WeekdayPicker: View {
    @Binding var selectedDays: Set<HabitDay>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HabitDay.allCases, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button(action: {
                        if isSelected { selectedDays.remove(day) } else { selectedDays.insert(day) }
                    }) {
                        Text(day.oneLetter)
                            .font(.headline)
                            .frame(minWidth: 26.0)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 5.6)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    .overlay(
                        Capsule().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    WeekdayPicker(selectedDays: .constant(Set(HabitDay.allCases)))
}
