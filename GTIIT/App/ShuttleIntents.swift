import AppIntents
import Foundation

enum ShuttleIntentDestination: String, AppEnum {
    case north, south

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "班车方向"
    static var caseDisplayRepresentations: [ShuttleIntentDestination: DisplayRepresentation] = [
        .north: "北校区",
        .south: "南校区"
    ]
}

/// Siri / Shortcuts: answers with the planned countdown for the next shuttle.
struct ShuttleNextBusIntent: AppIntent {
    static var title: LocalizedStringResource = "班车还有多久"
    static var description = IntentDescription("查询下一班校车的计划发车倒计时。")
    static var openAppWhenRun = false

    @Parameter(title: "方向") var destination: ShuttleIntentDestination

    init() { destination = .north }
    init(destination: ShuttleIntentDestination) { self.destination = destination }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        L10n.language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "settings.language") ?? "") ?? .chinese
        let teachingWeek = UserDefaults.standard.object(forKey: "settings.shuttleTeachingWeek") as? Bool ?? true
        let direction: ShuttleDirection = destination == .north ? .southToNorth : .northToSouth
        let now = Date()
        let target = direction.destination

        guard let next = ShuttleSchedule.upcoming(direction, after: now, teachingWeek: teachingWeek, limit: 1).first else {
            let text = L10n.isEnglish
                ? "There is no shuttle to \(target) scheduled now."
                : "现在没有去\(target)的班车。"
            return .result(dialog: IntentDialog(stringLiteral: text))
        }

        let countdown = next.countdown(from: now)
        let text = L10n.isEnglish
            ? "The next shuttle to \(target) leaves in \(countdown), at \(next.trip.time)."
            : "去\(target)的下一班班车还有\(countdown)，\(next.trip.time) 发车。"
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}


/// Schedules a local reminder for the next shuttle (no server/remote push).
struct ScheduleShuttleReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "提醒我赶班车"
    static var description = IntentDescription("为下一班校车设置本机发车提醒。")
    static var openAppWhenRun = false

    @Parameter(title: "方向") var destination: ShuttleIntentDestination

    init() { destination = .north }
    init(destination: ShuttleIntentDestination) { self.destination = destination }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        L10n.language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "settings.language") ?? "") ?? .chinese
        let teachingWeek = UserDefaults.standard.object(forKey: "settings.shuttleTeachingWeek") as? Bool ?? true
        let direction: ShuttleDirection = destination == .north ? .southToNorth : .northToSouth
        guard let next = ShuttleSchedule.upcoming(direction, after: Date(), teachingWeek: teachingWeek, limit: 1).first else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.tr("现在没有符合条件的班车。")))
        }
        let center = ShuttleNotificationCenter.shared
        await center.refreshStatus()
        if center.authorizationStatus == .notDetermined {
            _ = await center.requestAuthorization()
        }
        guard center.authorizationStatus == .authorized || center.authorizationStatus == .provisional else {
            return .result(dialog: IntentDialog(stringLiteral: L10n.tr("请先在 App 的班车提醒中允许通知。")))
        }
        let ok = await center.scheduleReminder(direction: direction, departure: next, leadMinutes: UserDefaults.standard.object(forKey: "settings.shuttleReminderLead") as? Int ?? 10)
        let text = ok
            ? L10n.format("已设置：%@ 的班车提前 %@ 分钟提醒。", next.trip.time, String(UserDefaults.standard.object(forKey: "settings.shuttleReminderLead") as? Int ?? 10))
            : L10n.tr("提醒时间已过，未能设置。")
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct GTIITShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShuttleNextBusIntent(destination: .north),
            phrases: [
                "\(.applicationName) 去北校的班车还有多久",
                "\(.applicationName) 去北校的班车还有多久来",
                "\(.applicationName) 北校班车还有多久",
                "\(.applicationName) when is the next shuttle to north campus",
                "\(.applicationName) next shuttle to north campus"
            ],
            shortTitle: "北校班车",
            systemImageName: "bus.fill"
        )
        AppShortcut(
            intent: ShuttleNextBusIntent(destination: .south),
            phrases: [
                "\(.applicationName) 去南校的班车还有多久",
                "\(.applicationName) 去南校的班车还有多久来",
                "\(.applicationName) 南校班车还有多久",
                "\(.applicationName) when is the next shuttle to south campus",
                "\(.applicationName) next shuttle to south campus"
            ],
            shortTitle: "南校班车",
            systemImageName: "bus.fill"
        )
        AppShortcut(
            intent: ScheduleShuttleReminderIntent(destination: .north),
            phrases: [
                "\(.applicationName) 提醒我赶去北校的班车",
                "\(.applicationName) 提醒我赶北校班车",
                "\(.applicationName) remind me to catch the north campus shuttle"
            ],
            shortTitle: "北校班车提醒",
            systemImageName: "bell.badge.fill"
        )
        AppShortcut(
            intent: ScheduleShuttleReminderIntent(destination: .south),
            phrases: [
                "\(.applicationName) 提醒我赶去南校的班车",
                "\(.applicationName) 提醒我赶南校班车",
                "\(.applicationName) remind me to catch the south campus shuttle"
            ],
            shortTitle: "南校班车提醒",
            systemImageName: "bell.badge.fill"
        )
    }
}