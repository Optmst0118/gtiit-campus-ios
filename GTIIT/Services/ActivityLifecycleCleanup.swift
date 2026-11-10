import ActivityKit
import BackgroundTasks
import Foundation

@MainActor private final class BackgroundTaskCompletion {
    private let task: BGTask
    private var finished = false
    init(_ task: BGTask) { self.task = task }
    func finish(_ success: Bool) {
        guard !finished else { return }
        finished = true
        task.setTaskCompleted(success: success)
    }
}

/// Background refresh is a recovery path, never treated as a punctual timer.
@MainActor enum ActivityLifecycleCleanup {
    static let identifier = "io.github.optmst0118.gtiit.beta.activity-cleanup"
    static let studyIdentifier = "io.github.optmst0118.gtiit.beta.study-refresh"
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            Task { @MainActor in
                let work = Task { @MainActor in
                    await reconcile()
                    task.setTaskCompleted(success: !Task.isCancelled)
                }
                task.expirationHandler = { work.cancel() }
            }
        }
    }
    static func registerStudyRefresh(run: @escaping @MainActor () async -> Bool) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: studyIdentifier, using: nil) { task in
            Task { @MainActor in
                scheduleStudyRefresh()
                let completion = BackgroundTaskCompletion(task)
                let work = Task { @MainActor in
                    let success = await run()
                    completion.finish(success && !Task.isCancelled)
                }
                task.expirationHandler = {
                    work.cancel()
                    Task { @MainActor in completion.finish(false) }
                }
            }
        }
    }
    static func scheduleStudyRefresh() {
        #if !GTIIT_REGRESSION
        let request = BGAppRefreshTaskRequest(identifier: studyIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(MoodleUpcomingStore.refreshInterval)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { LocalDiagnostics.shared.record("studyBackground.scheduleFailed") }
        #endif
    }
    static func schedule() {
        #if !GTIIT_REGRESSION
        let dates = Activity<CourseActivityAttributes>.activities.map { $0.content.state.end.addingTimeInterval(600) }
            + Activity<ShuttleActivityAttributes>.activities.map { $0.content.state.departureDate.addingTimeInterval(600) }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        guard let date = dates.min() else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = max(date, Date())
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
    static func reconcile(now: Date = Date()) async {
        for activity in Activity<CourseActivityAttributes>.activities where activity.content.state.end.addingTimeInterval(600) <= now {
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for activity in Activity<ShuttleActivityAttributes>.activities where activity.content.state.departureDate.addingTimeInterval(600) <= now {
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        schedule()
    }
}
