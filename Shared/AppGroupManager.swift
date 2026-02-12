import Foundation
import ManagedSettings

final class AppGroupManager {
    static let shared = AppGroupManager()

    /// Writable data directory inside the shared container (Library/MindfulPhoneData/).
    /// The container ROOT is not writable on iOS — only Library/ and below are.
    private let dataDirectory: URL?

    /// UserDefaults for simple key-value storage (main app only reads/writes these).
    private let defaults: UserDefaults

    private init() {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName
        )
        self.defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard

        // Use Library/MindfulPhoneData/ — the container root is NOT writable,
        // but Library/ and its subdirectories ARE.
        if let container {
            let dir = container
                .appendingPathComponent("Library")
                .appendingPathComponent("MindfulPhoneData")
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )
            self.dataDirectory = dir
        } else {
            self.dataDirectory = nil
        }
    }

    // MARK: - File-Based IPC Helpers

    private func fileURL(for filename: String) -> URL? {
        dataDirectory?.appendingPathComponent(filename)
    }

    private func writeData(_ data: Data, to filename: String) {
        guard let url = fileURL(for: filename) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func readData(from filename: String) -> Data? {
        guard let url = fileURL(for: filename) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func removeFile(_ filename: String) {
        guard let url = fileURL(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Token → Name Mapping (Belt-and-Suspenders: File + UserDefaults)

    private let tokenMapFilename = "tokenNameMap.json"
    private let tokenMapUDKey = "tokenNameMapData"

    func saveTokenName(_ name: String, for token: ApplicationToken) {
        var map = getTokenNameMap()
        map[stableKey(for: token)] = name
        if let data = try? JSONEncoder().encode(map) {
            writeData(data, to: tokenMapFilename)
            defaults.set(data, forKey: tokenMapUDKey)
            defaults.synchronize()
        }
    }

    func getTokenName(for token: ApplicationToken) -> String? {
        let map = getTokenNameMap()
        return map[stableKey(for: token)]
    }

    private func getTokenNameMap() -> [String: String] {
        // Try file first, fall back to UserDefaults
        if let data = readData(from: tokenMapFilename),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            return map
        }
        if let data = defaults.data(forKey: tokenMapUDKey),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            return map
        }
        return [:]
    }

    func stableKey(for token: ApplicationToken) -> String {
        let data = try? JSONEncoder().encode(token)
        return data?.base64EncodedString() ?? UUID().uuidString
    }

    func encodeToken(_ token: ApplicationToken) -> Data {
        (try? JSONEncoder().encode(token)) ?? Data()
    }

    func decodeToken(from data: Data) -> ApplicationToken? {
        try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    // MARK: - Pending Unlock Request (Belt-and-Suspenders: File + UserDefaults)

    private let pendingRequestFilename = "pendingUnlockRequest.json"
    private let pendingRequestUDKey = "pendingUnlockRequestData"

    func savePendingUnlockRequest(_ request: PendingUnlockRequest) {
        if let data = try? JSONEncoder().encode(request) {
            // Write to BOTH file and UserDefaults — if one mechanism fails
            // in the extension sandbox, the other might succeed.
            writeData(data, to: pendingRequestFilename)
            defaults.set(data, forKey: pendingRequestUDKey)
            defaults.synchronize()
        }
    }

    func getPendingUnlockRequest() -> PendingUnlockRequest? {
        // Try file first, fall back to UserDefaults
        if let data = readData(from: pendingRequestFilename),
           let request = try? JSONDecoder().decode(PendingUnlockRequest.self, from: data) {
            return request
        }
        if let data = defaults.data(forKey: pendingRequestUDKey),
           let request = try? JSONDecoder().decode(PendingUnlockRequest.self, from: data) {
            return request
        }
        return nil
    }

    func clearPendingUnlockRequest() {
        removeFile(pendingRequestFilename)
        defaults.removeObject(forKey: pendingRequestUDKey)
        defaults.synchronize()
    }

    // MARK: - Active Unlocks (File-Based)

    private let activeUnlocksFilename = "activeUnlocks.json"

    func saveActiveUnlock(_ record: ActiveUnlockRecord) {
        var unlocks = getActiveUnlocks()
        unlocks.append(record)
        saveAllActiveUnlocks(unlocks)
    }

    func getActiveUnlocks() -> [ActiveUnlockRecord] {
        guard let data = readData(from: activeUnlocksFilename) else { return [] }
        return (try? JSONDecoder().decode([ActiveUnlockRecord].self, from: data)) ?? []
    }

    func removeActiveUnlock(id: UUID) {
        var unlocks = getActiveUnlocks()
        unlocks.removeAll { $0.id == id }
        saveAllActiveUnlocks(unlocks)
    }

    func removeActiveUnlock(activityName: String) {
        var unlocks = getActiveUnlocks()
        unlocks.removeAll { $0.activityName == activityName }
        saveAllActiveUnlocks(unlocks)
    }

    func getExpiredUnlocks() -> [ActiveUnlockRecord] {
        let now = Date()
        return getActiveUnlocks().filter { $0.expiresAt <= now }
    }

    private func saveAllActiveUnlocks(_ unlocks: [ActiveUnlockRecord]) {
        if let data = try? JSONEncoder().encode(unlocks) {
            writeData(data, to: activeUnlocksFilename)
        }
    }

    // MARK: - Exempt Apps Selection (File-Based)

    private let exemptSelectionFilename = "exemptSelection.dat"

    func saveExemptSelection(_ data: Data) {
        writeData(data, to: exemptSelectionFilename)
    }

    func getExemptSelectionData() -> Data? {
        readData(from: exemptSelectionFilename)
    }

    // MARK: - Diagnostics

    func diagnosticInfo() -> [String: String] {
        var info: [String: String] = [:]

        // Data directory
        if let dir = dataDirectory {
            info["dataDirectory"] = dir.path
            let exists = FileManager.default.fileExists(atPath: dir.path)
            info["dataDirExists"] = exists ? "YES" : "NO"

            // List files in data directory
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                info["files"] = files.isEmpty ? "(empty)" : files.joined(separator: ", ")
            } else {
                info["files"] = "(can't list)"
            }
        } else {
            info["dataDirectory"] = "nil"
        }

        // Pending request check
        let fileRequest = readData(from: pendingRequestFilename) != nil
        let udRequest = defaults.data(forKey: pendingRequestUDKey) != nil
        info["pendingInFile"] = fileRequest ? "YES" : "NO"
        info["pendingInUD"] = udRequest ? "YES" : "NO"

        // Token map check
        let fileMap = readData(from: tokenMapFilename) != nil
        let udMap = defaults.data(forKey: tokenMapUDKey) != nil
        info["tokenMapInFile"] = fileMap ? "YES" : "NO"
        info["tokenMapInUD"] = udMap ? "YES" : "NO"

        return info
    }

    // MARK: - App State (UserDefaults — these are only read by the main app)

    var isOnboardingComplete: Bool {
        get { defaults.bool(forKey: AppGroupConstants.onboardingCompleteKey) }
        set { defaults.set(newValue, forKey: AppGroupConstants.onboardingCompleteKey) }
    }

    var areShieldsActive: Bool {
        get { defaults.bool(forKey: AppGroupConstants.shieldsActiveKey) }
        set { defaults.set(newValue, forKey: AppGroupConstants.shieldsActiveKey) }
    }
}
