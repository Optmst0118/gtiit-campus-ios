import SwiftUI
import UIKit

struct ShuttleReminderSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notifications = ShuttleNotificationCenter.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(L10n.tr("通知权限"), value: statusText)
                    if notifications.authorizationStatus == .notDetermined {
                        Button(L10n.tr("允许通知")) {
                            Task { _ = await notifications.requestAuthorization() }
                        }
                    }
                    if notifications.authorizationStatus == .denied {
                        Button(L10n.tr("前往系统设置")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section {
                    Picker(L10n.tr("常用方向"), selection: $settings.favoriteShuttleDirection) {
                        ForEach(ShuttleDirection.allCases) { direction in
                            Text(direction.title).tag(direction)
                        }
                    }
                    Picker(L10n.tr("提前时间"), selection: $settings.shuttleReminderLead) {
                        Text(L10n.tr("5 分钟")).tag(5)
                        Text(L10n.tr("10 分钟")).tag(10)
                        Text(L10n.tr("15 分钟")).tag(15)
                    }
                    Button(L10n.tr("为下一班设置提醒")) {
                        Task { await scheduleNext() }
                    }
                    .disabled(notifications.authorizationStatus == .denied)
                    if notifications.pendingCount > 0 {
                        Button(L10n.tr("清除全部班车提醒"), role: .destructive) {
                            notifications.cancelAllShuttleReminders()
                            message = nil
                        }
                    }
                    Toggle(L10n.tr("隐藏提醒详情"), isOn: $settings.privateShuttleReminders)
                }

                if let message {
                    Section {
                        Text(message).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.tr("班车提醒"))
            .navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("完成")) { dismiss() }
                }
            }
            .task { await notifications.refreshStatus() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await notifications.refreshStatus() } } }
        }
    }

    private var statusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return L10n.tr("已允许")
        case .denied: return L10n.tr("已关闭")
        case .notDetermined: return L10n.tr("未选择")
        @unknown default: return L10n.tr("未选择")
        }
    }

    private func scheduleNext() async {
        if notifications.authorizationStatus == .notDetermined {
            _ = await notifications.requestAuthorization()
        }
        guard notifications.authorizationStatus == .authorized || notifications.authorizationStatus == .provisional else {
            message = L10n.tr("请先在系统设置中允许通知。")
            return
        }
        guard let next = ShuttleSchedule.upcoming(
            settings.favoriteShuttleDirection,
            after: Date(),
            teachingWeek: settings.shuttleTeachingWeek,
            limit: 1
        ).first else {
            message = L10n.tr("没有可提醒的班次。")
            return
        }
        let ok = await notifications.scheduleReminder(
            direction: settings.favoriteShuttleDirection,
            departure: next,
            leadMinutes: settings.shuttleReminderLead
        )
        message = ok
            ? L10n.format("已设置：%@ 的班车提前 %@ 分钟提醒。", String(describing: next.trip.time), String(describing: settings.shuttleReminderLead))
            : L10n.tr("未能设置，请选择更短的提前时间或重试。")
    }
}
