import Combine
import FamilyControls
import Foundation
import SwiftUI

@MainActor
final class AccountabilityService: ObservableObject {
    static let shared = AccountabilityService()

    private var cancellable: AnyCancellable?

    private init() {}

    /// Start observing authorization status changes for revocation detection.
    func startObserving() {
        cancellable = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .notDetermined || status == .denied {
                    self?.handleRevocation()
                }
            }
    }

    private func handleRevocation() {
        // Log the revocation event
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName)
        var events = defaults?.array(forKey: "revocationEvents") as? [String] ?? []
        events.append(Date().ISO8601Format())
        defaults?.set(events, forKey: "revocationEvents")
    }

    func stopObserving() {
        cancellable?.cancel()
    }

    // MARK: - Stats Sharing

    /// Generates a weekly summary image suitable for sharing.
    @MainActor
    func generateWeeklyStatsImage(records: [UnlockRecord]) -> UIImage? {
        let view = WeeklyStatsShareView(records: records)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Returns revocation event dates.
    func getRevocationEvents() -> [Date] {
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName)
        let events = defaults?.array(forKey: "revocationEvents") as? [String] ?? []
        return events.compactMap { ISO8601DateFormatter().date(from: $0) }
    }
}

// MARK: - Share View

private struct WeeklyStatsShareView: View {
    let records: [UnlockRecord]

    private var weekRecords: [UnlockRecord] {
        let startOfWeek = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        return records.filter { $0.requestedAt >= startOfWeek }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                Text("MindfulPhone")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.blue)

            Text("Weekly Summary")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 32) {
                StatColumn(value: "\(weekRecords.count)", label: "Requests")
                StatColumn(
                    value: "\(weekRecords.filter(\.wasApproved).count)",
                    label: "Approved"
                )
                StatColumn(
                    value: "\(weekRecords.compactMap(\.durationMinutes).reduce(0, +))m",
                    label: "Total Time"
                )
            }

            if let topApp = topApp {
                Text("Most requested: \(topApp)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(Date(), style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var topApp: String? {
        let grouped = Dictionary(grouping: weekRecords, by: \.appName)
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }
}

private struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
