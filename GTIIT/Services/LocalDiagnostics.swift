import Foundation
import MetricKit
import OSLog

/// Bounded, local aggregate counters. No URLs, page text or account identifiers.
@MainActor final class LocalDiagnostics: NSObject, ObservableObject, MXMetricManagerSubscriber {
    static let shared = LocalDiagnostics()
    @Published private(set) var counters: [String: Int] = [:]
    private let logger = Logger(subsystem: "io.github.optmst0118.gtiit.beta", category: "performance")
    private let began = ProcessInfo.processInfo.systemUptime
    @Published private(set) var firstViewMilliseconds: Int?
    private var registered = false
    func start() {
        guard !registered else { return }
        registered = true
        MXMetricManager.shared.add(self)
    }
    func firstViewReady() {
        guard firstViewMilliseconds == nil else { return }
        firstViewMilliseconds = Int((ProcessInfo.processInfo.systemUptime - began) * 1000)
    }
    func record(_ event: String) {
        counters[event, default: 0] += 1
        logger.info("event=\(event, privacy: .public) count=\(self.counters[event, default: 0])")
    }
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let count = payloads.count
        Task { @MainActor in self.counters["systemMetricReports", default: 0] += count }
    }
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let crashes = payloads.reduce(0) { $0 + ($1.crashDiagnostics?.count ?? 0) }
        let hangs = payloads.reduce(0) { $0 + ($1.hangDiagnostics?.count ?? 0) }
        Task { @MainActor in
            self.counters["systemCrashReports", default: 0] += crashes
            self.counters["systemHangReports", default: 0] += hangs
        }
    }
    var report: String {
        (["GTIIT \(AppInfo.versionText)", "viewReadyMs=\(firstViewMilliseconds ?? 0)"] +
         counters.keys.sorted().map { "\($0)=\(counters[$0] ?? 0)" }).joined(separator: "\n")
    }
}
