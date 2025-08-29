
import Foundation

// MARK: - Weekday model

enum HabitDay: Int, CaseIterable, Codable, Identifiable {
    case monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7, sunday = 1

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: return "Mo"
        case .tuesday: return "Di"
        case .wednesday: return "Mi"
        case .thursday: return "Do"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        case .sunday: return "So"
        }
    }

    var oneLetter: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "D"
        case .wednesday: return "M"
        case .thursday: return "D"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }
}

// MARK: - Interval segments (Start/Aktiv/Pause/Ende)

struct HabitSegment: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Equatable {
        case start  = "Start"
        case active = "Aktiv"
        case pause  = "Pause"
        case end    = "Ende"
    }

    var id: UUID = UUID()
    var type: Kind
    /// Dauer in Sekunden
    var duration: TimeInterval
    var isStop: Bool = false

    // Backward-compatible Codable: default `isStop` to false if missing in old saves
    enum CodingKeys: String, CodingKey { case id, type, duration, isStop }

    init(id: UUID = UUID(), type: Kind, duration: TimeInterval, isStop: Bool = false) {
        self.id = id
        self.type = type
        self.duration = duration
        self.isStop = isStop
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try c.decode(Kind.self, forKey: .type)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        isStop = (try c.decodeIfPresent(Bool.self, forKey: .isStop)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(duration, forKey: .duration)
        try c.encode(isStop, forKey: .isStop)
    }
}

// MARK: - Habit model

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var minutes: Int
    var seconds: Int = 0
    var activeDays: Set<HabitDay>
    var segments: [HabitSegment] = []

    // Designated initializer
    init(id: UUID = UUID(), title: String, minutes: Int, seconds: Int = 0, activeDays: Set<HabitDay>, segments: [HabitSegment] = []) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.seconds = seconds
        self.activeDays = activeDays
        self.segments = segments
    }

    // Convenience initializer matching call-site labels in views
    init(title: String, activeDays: Set<HabitDay>, minutes: Int, segments: [HabitSegment]) {
        self.init(id: UUID(), title: title, minutes: minutes, seconds: 0, activeDays: activeDays, segments: segments)
    }

    // Codable with backward-compatibility (older saves may miss `seconds`/`segments`)
    enum CodingKeys: String, CodingKey { case id, title, minutes, seconds, activeDays, segments }
}
