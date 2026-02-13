import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \UnlockRecord.requestedAt, order: .reverse)
    private var allRecords: [UnlockRecord]

    var body: some View {
        List {
            Section("Today") {
                let today = todayRecords
                StatRow(label: "Unlock requests", value: "\(today.count)")
                StatRow(label: "Approved", value: "\(today.filter(\.wasApproved).count)")
                StatRow(
                    label: "Total unlocked time",
                    value: "\(today.compactMap(\.durationMinutes).reduce(0, +)) min"
                )
                if let topApp = topApp(in: today) {
                    StatRow(label: "Most requested", value: topApp)
                }
            }

            Section("This Week") {
                let week = thisWeekRecords
                StatRow(label: "Unlock requests", value: "\(week.count)")
                StatRow(label: "Approved", value: "\(week.filter(\.wasApproved).count)")
                StatRow(
                    label: "Total unlocked time",
                    value: "\(week.compactMap(\.durationMinutes).reduce(0, +)) min"
                )
                if let topApp = topApp(in: week) {
                    StatRow(label: "Most requested", value: topApp)
                }
                let rate = approvalRate(in: week)
                StatRow(label: "Approval rate", value: "\(rate)%")
            }

            Section("Top Apps") {
                let apps = topApps(in: allRecords)
                if apps.isEmpty {
                    Text("No data yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(apps, id: \.name) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Text("\(app.count) requests")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !allRecords.isEmpty {
                Section("Active Unlocks") {
                    let active = UnlockManager.shared.getActiveUnlocks()
                    if active.isEmpty {
                        Text("No active unlocks")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(active) { unlock in
                            HStack {
                                Text(unlock.appName)
                                    .font(.headline)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Expires")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(unlock.expiresAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Stats")
    }

    // MARK: - Computed Properties

    private var todayRecords: [UnlockRecord] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allRecords.filter { $0.requestedAt >= startOfDay }
    }

    private var thisWeekRecords: [UnlockRecord] {
        let startOfWeek = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        return allRecords.filter { $0.requestedAt >= startOfWeek }
    }

    private func topApp(in records: [UnlockRecord]) -> String? {
        let grouped = Dictionary(grouping: records, by: \.appName)
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    private func approvalRate(in records: [UnlockRecord]) -> Int {
        guard !records.isEmpty else { return 0 }
        let approved = records.filter(\.wasApproved).count
        return Int(Double(approved) / Double(records.count) * 100)
    }

    private func topApps(in records: [UnlockRecord]) -> [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: records, by: \.appName)
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}
