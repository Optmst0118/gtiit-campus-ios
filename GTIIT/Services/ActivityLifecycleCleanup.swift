import ActivityKit
import BackgroundTasks
import Foundation

/// Background refresh is a recovery path, never treated as a punctual timer.
@MainActor enum ActivityLifecycleCleanup {
    static let identifier = "io.github.optmst0118.gtiit.beta.activity-cleanup"
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
    static func schedule() {
        #if !GTIIT_REGRESSION
        let dates = Activity<CourseActivityAttributes>.activities.map { $0.content.state.end.addingTimeInterval(300) }
            + Activity<ShuttleActivityAttributes>.activities.map { $0.content.state.departureDate.addingTimeInterval(300) }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        guard let date = dates.min() else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = max(date, Date())
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
    static func reconcile(now: Date = Date()) async {
        for activity in Activity<CourseActivityAttributes>.activities where activity.content.state.end.addingTimeInterval(300) <= now {
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for activity in Activity<ShuttleActivityAttributes>.activities where activity.content.state.departureDate.addingTimeInterval(300) <= now {
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        schedule()
    }
}
