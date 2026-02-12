import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \UnlockRecord.requestedAt, order: .reverse)
    private var records: [UnlockRecord]

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock",
                    description: Text("Your unlock requests will appear here.")
                )
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        HistoryDetailView(record: record)
                    } label: {
                        HistoryRowView(record: record)
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

// MARK: - Row View

private struct HistoryRowView: View {
    let record: UnlockRecord

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: record.wasApproved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.wasApproved ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.appName)
                        .font(.headline)
                    if record.wasOffline {
                        Text("Offline")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                Text(record.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(record.requestedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if let minutes = record.durationMinutes, record.wasApproved {
                        Text("\(minutes) min")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View

private struct HistoryDetailView: View {
    let record: UnlockRecord

    var body: some View {
        List {
            Section("Request") {
                LabeledContent("App", value: record.appName)
                LabeledContent("Status", value: record.wasApproved ? "Approved" : "Denied")
                LabeledContent("Requested", value: record.requestedAt.formatted())
                if record.wasOffline {
                    LabeledContent("Mode", value: "Offline")
                }
            }

            Section("Reason") {
                Text(record.reason)
            }

            if record.wasApproved {
                Section("Duration") {
                    if let minutes = record.durationMinutes {
                        LabeledContent("Granted", value: "\(minutes) minutes")
                    }
                    if let approved = record.approvedAt {
                        LabeledContent("Approved at", value: approved.formatted(date: .omitted, time: .shortened))
                    }
                    if let expires = record.expiresAt {
                        LabeledContent("Expired at", value: expires.formatted(date: .omitted, time: .shortened))
                    }
                }
            }
        }
        .navigationTitle(record.appName)
    }
}
