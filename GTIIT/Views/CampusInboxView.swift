import SwiftUI
import UserNotifications

struct CampusInboxView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var sync: CampusSessionSync
    @ObservedObject var upcoming: MoodleUpcomingStore
    @ObservedObject var exams: StudentExamStore
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = ShuttleNotificationCenter.shared
    @AppStorage("campusInboxBeta") private var beta = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let assignments = CampusInboxPolicy.assignments(upcoming.items, now: context.date)
            let reservations = CampusInboxPolicy.reservations(sync.reservations, now: context.date)
            let loginSites = SiteID.allCases
            let digest = StudyDailyPlan.make(works: settings.moodleDeadlineRemindersEnabled ? upcoming.items.filter { ($0.dueDate ?? .distantPast) > context.date } : [], exams: settings.examRemindersEnabled ? exams.items : [], days: settings.moodleReminderLead.rawValue / 24, hour: settings.studyReminderHour, now: context.date, includePastToday: true, horizonDays: 0).first { CampusDate.calendar.isDate($0.date, inSameDayAs: context.date) }
            List {
                if let digest {
                    Section(L10n.tr("今日提醒")) {
                        Text(digest.lines.joined(separator: "\n")).font(.subheadline)
                    }
                }
                if !exams.upcoming.isEmpty {
                    Section(L10n.tr("临近考试")) {
                        ForEach(exams.upcoming.filter { ($0.daysUntil(from: context.date) ?? 999) <= 31 }) { exam in
                            StudentExamRow(exam: exam)
                        }
                    }
                }
                if !notifications.delivered.isEmpty {
                    Section(L10n.tr("已送达")) {
                        ForEach(notifications.delivered, id: \.request.identifier) { notification in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(notification.request.content.title)
                                if !notification.request.content.body.isEmpty {
                                    Text(notification.request.content.body).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text(notification.date.gtiitFormatted()).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if beta || !assignments.isEmpty { Section(L10n.tr("24 小时内截止")) {
                    if assignments.isEmpty { Text(L10n.tr("暂无即将截止的作业")).foregroundStyle(Color.secondary) }
                    ForEach(assignments) { work in
                        Button {
                            if let url = MoodleWork.safeURL(work.url) { app.openWeb(url, site: .moodle, title: work.displayName) }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(work.displayName).foregroundStyle(Color.primary)
                                    Text(work.course).font(.subheadline).foregroundStyle(Color.secondary)
                                    MoodleDeadlineDate(item: work)
                                }
                            } icon: { Image(systemName: "doc.text").foregroundStyle(Theme.accent) }
                        }
                    }
                }
                }
                if beta || !reservations.isEmpty { Section(L10n.tr("6 小时内的预约")) {
                    if reservations.isEmpty { Text(L10n.tr("暂无即将开始的预约")).foregroundStyle(Color.secondary) }
                    ForEach(reservations) { reservation in
                        Button {
                            if let url = CachedRoomReservation.safeURL(reservation.url) { app.openWeb(url, site: .rooms, title: L10n.tr("我的预约")) }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(reservation.title).foregroundStyle(Color.primary)
                                    if !reservation.location.isEmpty { Text(reservation.location).font(.subheadline).foregroundStyle(Color.secondary) }
                                    Text(reservation.start.gtiitFormatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Theme.accent)
                                }
                            } icon: { Image(systemName: "calendar.badge.clock").foregroundStyle(Theme.accent) }
                        }
                    }
                }
                }
                if !loginSites.isEmpty { Section(L10n.tr("登录状态")) {
                    ForEach(loginSites) { site in
                        Button {
                            if site == .sports, let url = URL(string: "https://gtiit.mike-x.com/kcr2S") { app.openWeb(url, site: site, title: site.displayName) }
                            else { app.openSite(site) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: site.symbol).foregroundStyle(Theme.accent).frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(site.displayName).foregroundStyle(Color.primary)
                                    Text(sync.displayTitle(for: site)).font(.caption)
                                        .foregroundStyle(sync.states[site] == .needsLogin ? Theme.orange : Color.secondary)
                                }
                                Spacer()
                                if sync.states[site] == .checking { ProgressView() }
                                else if sync.states[site] == .signedIn { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                                else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.secondary) }
                            }
                        }
                    }
                }
                }
                if beta { Section { NavigationLink { CampusCacheView(sync: sync, upcoming: upcoming, exams: app.exams) } label: { Label(L10n.tr("本地校园信息"), systemImage: "internaldrive") } } }
            }
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
            .refreshable { app.refreshCampusSessions(force: true); app.refreshMoodleSummary(force: true); exams.refresh(force: true, allowed: { !app.lock.isLocked && app.lock.isActive && !app.isClearingData }); await notifications.refreshStatus() }
        }
        .navigationTitle(L10n.tr("通知中心")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
        .task {
            while !Task.isCancelled {
                await notifications.refreshStatus()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle(L10n.tr("显示全部通知项目"), isOn: $beta)
                } label: {
                    Text(L10n.tr("Beta")).font(.subheadline.weight(.medium))
                }.accessibilityLabel(L10n.tr("Beta 通知预览"))
            }
        }
    }
}

struct CampusCacheView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var sync: CampusSessionSync
    @ObservedObject var upcoming: MoodleUpcomingStore
    @ObservedObject var exams: StudentExamStore
    var body: some View {
        List {
            Section("Moodle") {
                ForEach(upcoming.courseItems) { course in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.displayName)
                        Text([course.shortname, course.category, course.term].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                if upcoming.courseItems.isEmpty { Text(L10n.tr("暂无已缓存课程")).foregroundStyle(Color.secondary) }
            }
            Section("Student") {
                ForEach(sync.studentCourses) { course in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                        Text([course.code, course.semester, course.teacher, course.location].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                if sync.studentCourses.isEmpty { Text(L10n.tr("暂无已缓存课程")).foregroundStyle(Color.secondary) }
            }
            if !upcoming.upcoming(days: settings.moodleUpcomingRange.rawValue).isEmpty { Section(L10n.tr("临近作业")) {
                ForEach(upcoming.upcoming(days: settings.moodleUpcomingRange.rawValue)) { work in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.displayName)
                        Text(work.course).font(.caption).foregroundStyle(Color.secondary)
                        MoodleDeadlineDate(item: work)
                    }
                }
            }
            }
            if !exams.upcoming.isEmpty { Section(L10n.tr("临近考试")) {
                ForEach(exams.upcoming) { exam in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.course)
                        Text([exam.code, exam.date, exam.time, exam.venue].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Color.secondary)
                    }
                }
            }
            }
            Section(L10n.tr("我的预约")) {
                ForEach(sync.reservations.filter { $0.end > Date() }) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                        Text(item.start.gtiitFormatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Color.secondary)
                    }
                }
                if sync.reservations.filter({ $0.end > Date() }).isEmpty { Text(L10n.tr("暂无已缓存预约")).foregroundStyle(Color.secondary) }
            }
        }.navigationTitle(L10n.tr("本地校园信息")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
            .scrollContentBackground(.hidden).background(Theme.pageBackground)
    }
}

struct CampusInboxToolbarButton: View {
    @ObservedObject var sync: CampusSessionSync
    @ObservedObject var upcoming: MoodleUpcomingStore
    @ObservedObject var exams: StudentExamStore
    let action: () -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let examCount = exams.upcoming.filter { [0,3,7,14,31].contains($0.daysUntil(from: context.date) ?? -1) }.count
            let count = examCount + CampusInboxPolicy.assignments(upcoming.items, now: context.date).count
                + CampusInboxPolicy.reservations(sync.reservations, now: context.date).count
                + CampusInboxPolicy.loginSites(sync.states, beta: false).count
            Button(action: action) {
                Image(systemName: count > 0 ? "bell.badge" : "bell")

            }.accessibilityLabel(L10n.tr("通知中心"))
                .accessibilityValue(L10n.format("%@ 条通知", String(count)))
        }
    }
}
