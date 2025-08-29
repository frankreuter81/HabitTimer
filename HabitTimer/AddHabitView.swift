import SwiftUI
struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @FocusState private var nameIsFocused: Bool
    @State private var selectedDays: Set<HabitDay> = Set(HabitDay.allCases)
    @State private var segments: [HabitSegment] = []
    var onSave: (Habit) -> Void

    // MARK: - Helpers
    private func lastDurationsBeforeInsertion() -> (active: TimeInterval, pause: TimeInterval) {
        let insertAt = segments.firstIndex(where: { $0.type == .end }) ?? segments.count
        var lastActive: TimeInterval? = nil
        var lastPause: TimeInterval? = nil
        if insertAt > 0 {
            for i in stride(from: insertAt - 1, through: 0, by: -1) {
                let seg = segments[i]
                if seg.type == .active, lastActive == nil { lastActive = seg.duration }
                if seg.type == .pause,  lastPause  == nil { lastPause  = seg.duration }
                if lastActive != nil && lastPause != nil { break }
            }
        }
        return (lastActive ?? 60, lastPause ?? 30)
    }

    private func appendActivePausePairCopyingPrevious() {
        let insertAt = segments.firstIndex(where: { $0.type == .end }) ?? segments.count
        let durs = lastDurationsBeforeInsertion()
        segments.insert(HabitSegment(type: .active, duration: durs.active), at: insertAt)
        segments.insert(HabitSegment(type: .pause,  duration: durs.pause),  at: insertAt + 1)
    }

    private func ensureBaselineSegments() {
        // Ensure exactly one Start at index 0
        if let startIdx = segments.firstIndex(where: { $0.type == .start }) {
            if startIdx != 0 { let s = segments.remove(at: startIdx); segments.insert(s, at: 0) }
        } else {
            segments.insert(HabitSegment(type: .start, duration: 0), at: 0)
        }
        // Ensure exactly one End at last index
        if let endIdx = segments.firstIndex(where: { $0.type == .end }) {
            let last = segments.count - 1
            if endIdx != last { let e = segments.remove(at: endIdx); segments.append(e) }
        } else {
            segments.append(HabitSegment(type: .end, duration: 0))
        }
        // Remove duplicate Starts (keep only index 0)
        var seenStart = false
        segments.removeAll { seg in
            if seg.type == .start {
                if seenStart { return true }
                seenStart = true; return false
            }
            return false
        }
        // Remove duplicate Ends (keep only the LAST)
        var endCount = segments.filter{ $0.type == .end }.count
        if endCount > 1 {
            for i in (0..<(segments.count)).reversed() {
                if segments[i].type == .end { endCount -= 1; if endCount >= 1 { segments.remove(at: i) } }
            }
        }
        // Ensure at least one Active and one Pause exist between Start and End
        if !segments.contains(where: { $0.type == .active }) {
            let insertAt = min(max(1, segments.count - 1), segments.count - 1)
            segments.insert(HabitSegment(type: .active, duration: 60), at: insertAt)
        }
        if !segments.contains(where: { $0.type == .pause }) {
            let insertAt = min(max(segments.count - 1, 1), segments.count - 1)
            segments.insert(HabitSegment(type: .pause, duration: 30), at: insertAt)
        }
    }

    private func canDelete(_ segment: HabitSegment) -> Bool {
        switch segment.type {
        case .start, .end:
            return false
        case .active:
            return segments.filter { $0.type == .active }.count > 1
        case .pause:
            return segments.filter { $0.type == .pause }.count > 1
        }
    }

    private func label(for segment: HabitSegment) -> String {
        switch segment.type {
        case .start:
            return HabitSegment.Kind.start.rawValue
        case .end:
            return HabitSegment.Kind.end.rawValue
        case .active, .pause:
            let siblings = segments.filter { $0.type == segment.type }
            if let idx = siblings.firstIndex(where: { $0.id == segment.id }) {
                return "\(segment.type.rawValue) \(idx + 1)"
            } else {
                return segment.type.rawValue
            }
        }
    }

    private func normalizedSegmentsForSave() -> [HabitSegment] {
        var s = segments

        // Ensure exactly one Start at index 0
        if let startIdx = s.firstIndex(where: { $0.type == .start }) {
            if startIdx != 0 { let st = s.remove(at: startIdx); s.insert(st, at: 0) }
        } else {
            s.insert(HabitSegment(type: .start, duration: 0), at: 0)
        }

        // Ensure exactly one End at last index
        if let endIdx = s.firstIndex(where: { $0.type == .end }) {
            let last = s.count - 1
            if endIdx != last { let e = s.remove(at: endIdx); s.append(e) }
        } else {
            s.append(HabitSegment(type: .end, duration: 0))
        }

        // Remove duplicate Starts (keep only index 0)
        var seenStart = false
        s.removeAll { seg in
            if seg.type == .start {
                if seenStart { return true }
                seenStart = true; return false
            }
            return false
        }

        // Remove duplicate Ends (keep only the LAST)
        var endCount = s.filter { $0.type == .end }.count
        if endCount > 1 {
            for i in (0..<(s.count)).reversed() {
                if s[i].type == .end { endCount -= 1; if endCount >= 1 { s.remove(at: i) } }
            }
        }

        // Drop zero-length active; drop zero-length pause only if not a Stop
        s.removeAll { seg in
            switch seg.type {
            case .active:
                return Int(seg.duration.rounded()) <= 0
            case .pause:
                return Int(seg.duration.rounded()) <= 0 && (seg.isStop == false)
            case .start, .end:
                return false
            }
        }

        // Ensure at least one Active and one Pause between Start and End
        if !s.contains(where: { $0.type == .active }) {
            let insertAt = min(max(1, s.count - 1), s.count - 1)
            s.insert(HabitSegment(type: .active, duration: 60), at: insertAt)
        }
        if !s.contains(where: { $0.type == .pause }) {
            let insertAt = min(max(s.count - 1, 1), s.count - 1)
            s.insert(HabitSegment(type: .pause, duration: 30), at: insertAt)
        }

        // Clamp durations to whole seconds and force 0 for Start/End
        for i in s.indices {
            switch s[i].type {
            case .active:
                s[i].duration = Double(max(1, Int(s[i].duration.rounded())))
            case .pause:
                if s[i].isStop {
                    s[i].duration = 0
                } else {
                    s[i].duration = Double(max(1, Int(s[i].duration.rounded())))
                }
            case .start, .end:
                s[i].duration = 0
            }
        }
        return s
    }

    // MARK: - View
    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Name des Habits", text: $title).focused($nameIsFocused)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Wochentage") {
                    WeekdayPicker(selectedDays: $selectedDays)
                    if selectedDays.isEmpty {
                        Text("Bitte mindestens einen Wochentag wählen.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    ForEach($segments) { $segment in
                        SegmentRowView(segment: $segment, titleLabel: label(for: segment))
                            .swipeActions(edge: .trailing) {
                                if canDelete(segment) {
                                    Button(role: .destructive) {
                                        if let idx = segments.firstIndex(where: { $0.id == segment.id }) {
                                            segments.remove(at: idx)
                                        }
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                    }

                    Button { appendActivePausePairCopyingPrevious() } label: {
                        Label("Abschnitt hinzufügen", systemImage: "plus")
                    }

                    if segments.isEmpty {
                        Text("Bitte mindestens einen Abschnitt hinzufügen.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: { Text("Dauer") }
            }
            .onAppear {
                ensureBaselineSegments()
                DispatchQueue.main.async { self.nameIsFocused = true }
            }
            .navigationTitle("Neuer Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let s = normalizedSegmentsForSave()
                        let totalSeconds = s.reduce(0.0) { $0 + $1.duration }
                        let minutes = max(1, Int(ceil(totalSeconds / 60.0)))
                        let habit = Habit(title: trimmed, activeDays: selectedDays, minutes: minutes, segments: s)
                        onSave(habit)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDays.isEmpty || segments.isEmpty)
                }
            }
        }
    }
}

// MARK: - Segment Row
struct SegmentRowView: View {
    @Binding var segment: HabitSegment
    let titleLabel: String

    // Local UI state for minutes/seconds (derived from segment.duration in seconds)
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var isStop: Bool = false
    @State private var showDurationSheet = false
    @State private var tempMinutes: Int = 0
    @State private var tempSeconds: Int = 0

    var body: some View {
        HStack {
            Text(titleLabel)
                .font(.headline)
            Spacer()
            Button((segment.type == .pause && isStop) ? "Stop" : String(format: "%02d:%02d", minutes, seconds)) {
                tempMinutes = (segment.type == .pause && isStop) ? -1 : minutes
                tempSeconds = seconds
                showDurationSheet = true
            }
            .sheet(isPresented: $showDurationSheet) {
                NavigationStack {
                    VStack(spacing: 20) {
                        HStack {
                            Picker("", selection: $tempMinutes) {
                                if segment.type == .pause {
                                    ForEach(-1..<60, id: \.self) { m in
                                        if m == -1 { Text("Stop").tag(-1) } else { Text("\(m) Min").tag(m) }
                                    }
                                } else {
                                    ForEach(0..<60, id: \.self) { m in Text("\(m) Min").tag(m) }
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Picker("", selection: $tempSeconds) {
                                ForEach(0..<60, id: \.self) { s in Text("\(s) Sek").tag(s) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .disabled(tempMinutes == -1)
                        }
                        .frame(height: 180)
                        Spacer()
                    }
                    .navigationTitle(titleLabel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showDurationSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") {
                                if segment.type == .pause && tempMinutes == -1 {
                                    isStop = true
                                    segment.isStop = true
                                    minutes = 0
                                    seconds = 0
                                    segment.duration = 0
                                } else {
                                    isStop = false
                                    segment.isStop = false
                                    minutes = tempMinutes
                                    seconds = min(59, max(0, tempSeconds))
                                    segment.duration = Double(minutes * 60 + seconds)
                                }
                                showDurationSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
            }
        }
        .onAppear {
            isStop = segment.isStop
            let total = max(0, Int(segment.duration.rounded()))
            minutes = min(59, total / 60)
            seconds = total % 60
        }
        .onChange(of: minutes) {
            if !isStop { segment.duration = Double(minutes * 60 + seconds) }
        }
        .onChange(of: seconds) {
            if !isStop { segment.duration = Double(minutes * 60 + seconds) }
        }
        .onChange(of: segment.duration) { _, newValue in
            if !isStop {
                let total = max(0, Int(newValue.rounded()))
                minutes = min(59, total / 60)
                seconds = total % 60
            }
        }
        .onChange(of: segment.isStop) { _, newValue in
            isStop = newValue
            if newValue {
                minutes = 0
                seconds = 0
            }
        }
    }
}
