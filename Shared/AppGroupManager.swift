import Foundation
import ManagedSettings
import OSLog

struct PendingRequestSaveResult {
    let success: Bool
    let wroteFile: Bool
    let wroteSharedDefaults: Bool
    let sharedContainerAvailable: Bool
    let sharedDefaultsAvailable: Bool
}

final class AppGroupManager {
    static let shared = AppGroupManager()
    private let runtimeLogger = Logger(
        subsystem: "pro.lgandecki.MindfulPhone",
        category: "AppGroupIPC"
    )

    /// Writable data directory inside the shared container (Library/MindfulPhoneData/).
    /// The container ROOT is not writable on iOS — only Library/ and below are.
    private let dataDirectory: URL?

    /// UserDefaults scoped to the app group (for cross-process IPC).
    private let sharedDefaults: UserDefaults?

    /// Process-local defaults used only for main-app state when shared defaults are unavailable.
    private let localDefaults = UserDefaults.standard
    private var canWriteExtensionLogFile = true

    private init() {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName
        )
        self.sharedDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName)

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

    var isSharedContainerAvailable: Bool {
        dataDirectory != nil
    }

    var isSharedDefaultsAvailable: Bool {
        sharedDefaults != nil
    }

    private var appStateDefaults: UserDefaults {
        sharedDefaults ?? localDefaults
    }

    // MARK: - File-Based IPC Helpers

    private func fileURL(for filename: String) -> URL? {
        dataDirectory?.appendingPathComponent(filename)
    }

    @discardableResult
    private func writeData(_ data: Data, to filename: String) -> Bool {
        guard let url = fileURL(for: filename) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func readData(from filename: String) -> Data? {
        guard let url = fileURL(for: filename) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func removeFile(_ filename: String) {
        guard let url = fileURL(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    private func setSharedData(_ data: Data, forKey key: String) -> Bool {
        guard let sharedDefaults else { return false }
        sharedDefaults.set(data, forKey: key)
        return sharedDefaults.synchronize()
    }

    private func getSharedData(forKey key: String) -> Data? {
        sharedDefaults?.data(forKey: key)
    }

    private func removeSharedData(forKey key: String) {
        sharedDefaults?.removeObject(forKey: key)
        sharedDefaults?.synchronize()
    }

    // MARK: - Token → Name Mapping (Belt-and-Suspenders: File + UserDefaults)

    private let tokenMapFilename = "tokenNameMap.json"
    private let tokenMapUDKey = "tokenNameMapData"

    func saveTokenName(_ name: String, for token: ApplicationToken) {
        var map = getTokenNameMap()
        map[stableKey(for: token)] = name
        if let data = try? JSONEncoder().encode(map) {
            _ = writeData(data, to: tokenMapFilename)
            _ = setSharedData(data, forKey: tokenMapUDKey)
        }
    }

    /// Extension-safe variant that avoids app-group file writes.
    func saveTokenNameSharedDefaultsOnly(_ name: String, for token: ApplicationToken) {
        var map = getTokenNameMap()
        map[stableKey(for: token)] = name
        if let data = try? JSONEncoder().encode(map) {
            _ = setSharedData(data, forKey: tokenMapUDKey)
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
        if let data = getSharedData(forKey: tokenMapUDKey),
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

    @discardableResult
    func savePendingUnlockRequest(_ request: PendingUnlockRequest) -> PendingRequestSaveResult {
        guard let data = try? JSONEncoder().encode(request) else {
            return PendingRequestSaveResult(
                success: false,
                wroteFile: false,
                wroteSharedDefaults: false,
                sharedContainerAvailable: isSharedContainerAvailable,
                sharedDefaultsAvailable: isSharedDefaultsAvailable
            )
        }

        // Write to BOTH file and UserDefaults — if one mechanism fails
        // in the extension sandbox, the other might succeed.
        let fileWrite = writeData(data, to: pendingRequestFilename)
        let defaultsWrite = setSharedData(data, forKey: pendingRequestUDKey)
        return PendingRequestSaveResult(
            success: fileWrite || defaultsWrite,
            wroteFile: fileWrite,
            wroteSharedDefaults: defaultsWrite,
            sharedContainerAvailable: isSharedContainerAvailable,
            sharedDefaultsAvailable: isSharedDefaultsAvailable
        )
    }

    /// Extension-safe variant that avoids app-group file writes.
    @discardableResult
    func savePendingUnlockRequestSharedDefaultsOnly(_ request: PendingUnlockRequest) -> PendingRequestSaveResult {
        guard let data = try? JSONEncoder().encode(request) else {
            return PendingRequestSaveResult(
                success: false,
                wroteFile: false,
                wroteSharedDefaults: false,
                sharedContainerAvailable: isSharedContainerAvailable,
                sharedDefaultsAvailable: isSharedDefaultsAvailable
            )
        }

        let defaultsWrite = setSharedData(data, forKey: pendingRequestUDKey)
        return PendingRequestSaveResult(
            success: defaultsWrite,
            wroteFile: false,
            wroteSharedDefaults: defaultsWrite,
            sharedContainerAvailable: isSharedContainerAvailable,
            sharedDefaultsAvailable: isSharedDefaultsAvailable
        )
    }

    func getPendingUnlockRequest(maxAge: TimeInterval? = nil) -> PendingUnlockRequest? {
        // Try file first, fall back to UserDefaults
        if let data = readData(from: pendingRequestFilename),
           let request = decodePendingRequest(from: data, maxAge: maxAge) {
            return request
        }
        if let data = getSharedData(forKey: pendingRequestUDKey),
           let request = decodePendingRequest(from: data, maxAge: maxAge) {
            return request
        }
        return nil
    }

    private func decodePendingRequest(from data: Data, maxAge: TimeInterval?) -> PendingUnlockRequest? {
        guard let request = try? JSONDecoder().decode(PendingUnlockRequest.self, from: data) else {
            return nil
        }

        if let maxAge {
            let age = Date().timeIntervalSince(request.timestamp)
            if age > maxAge {
                return nil
            }
        }
        return request
    }

    func clearPendingUnlockRequest() {
        removeFile(pendingRequestFilename)
        removeSharedData(forKey: pendingRequestUDKey)
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
            _ = writeData(data, to: activeUnlocksFilename)
        }
    }

    // MARK: - Exempt Apps Selection (File-Based)

    private let exemptSelectionFilename = "exemptSelection.dat"

    func saveExemptSelection(_ data: Data) {
        _ = writeData(data, to: exemptSelectionFilename)
    }

    func getExemptSelectionData() -> Data? {
        readData(from: exemptSelectionFilename)
    }

    // MARK: - Diagnostics

    func diagnosticInfo() -> [String: String] {
        var info: [String: String] = [:]

        info["sharedContainerAvailable"] = isSharedContainerAvailable ? "YES" : "NO"
        info["sharedDefaultsAvailable"] = isSharedDefaultsAvailable ? "YES" : "NO"

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
        let udRequest = getSharedData(forKey: pendingRequestUDKey) != nil
        info["pendingInFile"] = fileRequest ? "YES" : "NO"
        info["pendingInUD"] = udRequest ? "YES" : "NO"

        if let pending = getPendingUnlockRequest() {
            let age = Int(Date().timeIntervalSince(pending.timestamp))
            info["pendingAppName"] = pending.appName
            info["pendingAgeSec"] = String(age)
        } else {
            info["pendingAppName"] = "(none)"
            info["pendingAgeSec"] = "(n/a)"
        }

        // Token map check
        let fileMap = readData(from: tokenMapFilename) != nil
        let udMap = getSharedData(forKey: tokenMapUDKey) != nil
        info["tokenMapInFile"] = fileMap ? "YES" : "NO"
        info["tokenMapInUD"] = udMap ? "YES" : "NO"

        for (key, value) in getShieldActionDiagnostics() {
            info["shieldAction.\(key)"] = value
        }

        let logSummary = extensionLogSummary()
        info["extensionLogCount"] = String(logSummary.count)
        info["extensionLastLog"] = logSummary.last ?? "(none)"

        return info
    }

    // MARK: - Shield Action Diagnostics (Belt-and-Suspenders: File + UserDefaults)

    private let shieldActionDiagnosticsFilename = "shieldActionDiagnostics.json"
    private let shieldActionDiagnosticsUDKey = AppGroupConstants.shieldActionDiagnosticsKey

    func saveShieldActionDiagnostics(_ diagnostics: [String: String]) {
        var merged = getShieldActionDiagnostics()
        for (key, value) in diagnostics {
            merged[key] = value
        }
        merged["updatedAt"] = Date().ISO8601Format()

        guard let data = try? JSONEncoder().encode(merged) else { return }
        _ = writeData(data, to: shieldActionDiagnosticsFilename)
        _ = setSharedData(data, forKey: shieldActionDiagnosticsUDKey)
    }

    /// Extension-safe variant that avoids app-group file writes.
    func saveShieldActionDiagnosticsSharedDefaultsOnly(_ diagnostics: [String: String]) {
        var merged = getShieldActionDiagnostics()
        for (key, value) in diagnostics {
            merged[key] = value
        }
        merged["updatedAt"] = Date().ISO8601Format()

        guard let data = try? JSONEncoder().encode(merged) else { return }
        _ = setSharedData(data, forKey: shieldActionDiagnosticsUDKey)
    }

    func getShieldActionDiagnostics() -> [String: String] {
        if let data = readData(from: shieldActionDiagnosticsFilename),
           let diagnostics = try? JSONDecoder().decode([String: String].self, from: data) {
            return diagnostics
        }

        if let data = getSharedData(forKey: shieldActionDiagnosticsUDKey),
           let diagnostics = try? JSONDecoder().decode([String: String].self, from: data) {
            return diagnostics
        }

        return [:]
    }

    // MARK: - Extension Logs (File-Based)

    private let extensionLogsFilename = "extensionLogs.txt"

    func appendExtensionLog(source: String, message: String, persistToSharedFile: Bool = true) {
        runtimeLogger.log("[\(source, privacy: .public)] \(message, privacy: .public)")

        guard persistToSharedFile else { return }
        guard canWriteExtensionLogFile else { return }

        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date())) [\(source)] \(message)\n"
        guard let lineData = line.data(using: .utf8) else { return }

        guard let url = fileURL(for: extensionLogsFilename) else {
            canWriteExtensionLogFile = false
            runtimeLogger.error("Disabling extension file logs: shared container URL unavailable")
            return
        }

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: lineData)
                    try handle.close()
                } catch {
                    try? handle.close()
                    canWriteExtensionLogFile = false
                    runtimeLogger.error("Disabling extension file logs after append error: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else {
            do {
                try lineData.write(to: url, options: .atomic)
            } catch {
                canWriteExtensionLogFile = false
                runtimeLogger.error("Disabling extension file logs after create error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func getExtensionLogs(limit: Int = 50) -> [String] {
        guard let data = readData(from: extensionLogsFilename),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard limit > 0 else { return lines }
        return Array(lines.suffix(limit))
    }

    func clearExtensionLogs() {
        removeFile(extensionLogsFilename)
    }

    private func extensionLogSummary() -> (count: Int, last: String?) {
        guard let data = readData(from: extensionLogsFilename),
              let text = String(data: data, encoding: .utf8) else {
            return (0, nil)
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return (lines.count, lines.last)
    }

    // MARK: - App State (UserDefaults — these are only read by the main app)

    var isOnboardingComplete: Bool {
        get { appStateDefaults.bool(forKey: AppGroupConstants.onboardingCompleteKey) }
        set { appStateDefaults.set(newValue, forKey: AppGroupConstants.onboardingCompleteKey) }
    }

    var areShieldsActive: Bool {
        get { appStateDefaults.bool(forKey: AppGroupConstants.shieldsActiveKey) }
        set { appStateDefaults.set(newValue, forKey: AppGroupConstants.shieldsActiveKey) }
    }
}
