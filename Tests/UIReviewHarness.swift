import SwiftUI
import UIKit

/// 独立测试包：用原 App 的完整 RootTabView 检查外观及 Dynamic Type，不进入产品 target。
@main struct UIReviewApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var app: AppModel
    @StateObject private var previewLock: AppLockController
    private let environment = ProcessInfo.processInfo.environment
    init() {
        let defaults = UserDefaults(suiteName: "ui-review.preferences")!
        defaults.removePersistentDomain(forName: "ui-review.preferences")
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true
        settings.language = ProcessInfo.processInfo.environment["UI_REVIEW_ENGLISH"] == "1" ? .english : .chinese
        settings.preloadSitesOnLaunch = false
        settings.startupTab = .me
        settings.appearance = ProcessInfo.processInfo.environment["UI_REVIEW_DARK"] == "1" ? .dark : .light
        _settings = StateObject(wrappedValue: settings)
        let model = AppModel(settings: settings)
        if ProcessInfo.processInfo.environment["UI_REVIEW_TIMETABLE"] == "1" {
            let classes = (1...5).flatMap { day in [
                LocalCourse(name: "Engineering Mechanics", code: "TEST1001", group: "L10", weekday: day, start: "08:00", end: "09:45", room: "SC E1-201", building: "Education Building 1"),
                LocalCourse(name: "Design Studio", code: "TEST2002", group: "Lab20", weekday: day, start: "14:00", end: "16:00", room: "SC E2-302", building: "Education Building 2")
            ] }
            try? model.timetable.save(TimetableSnapshot(semester: "Synthetic review semester", validFrom: "2026-10-12", validUntil: "2027-01-11", courses: classes))
        }
        if let raw = ProcessInfo.processInfo.environment["UI_REVIEW_SITE"], let site = SiteID(rawValue: raw) { model.openSite(site) }
        _app = StateObject(wrappedValue: model)
        let lock = AppLockController(authenticator: PreviewUnavailableAuthenticator())
        lock.lock()
        _previewLock = StateObject(wrappedValue: lock)
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if environment["UI_REVIEW_CALENDAR"] == "1" {
                    NavigationStack { AcademicCalendarView() }
                } else if environment["UI_REVIEW_WEEK"] == "1" {
                    NavigationStack { LocalTimetableView(store: app.timetable).environmentObject(app) }
                } else if environment["UI_REVIEW_ABOUT"] == "1" {
                    NavigationStack { AboutView().environmentObject(app).environmentObject(settings) }
                        .overlay { YilongOverlay(controller: app.yilong) }
                } else if environment["UI_REVIEW_DOWNLOADS"] == "1" {
                    NavigationStack { DownloadsView(center: app.downloads).environmentObject(app).environmentObject(settings) }
                        .task {
                            if app.downloads.items.isEmpty {
                                let source = FileManager.default.temporaryDirectory.appendingPathComponent("review.pdf")
                                let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
                                let data = renderer.pdfData { context in
                                    context.beginPage()
                                    ("GTIIT PDF Preview\nVisual test fixture\n\nPinch to zoom. Scroll to read." as NSString).draw(at: CGPoint(x: 48, y: 80), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
                                }
                                try? data.write(to: source)
                                for name in ["Robotics syllabus.pdf", "Engineering mathematics.pdf", "Campus reference.pdf", "Week 3 notes.pdf"] {
                                    _ = try? await app.downloads.savePreview(source, filename: name, site: .moodle)
                                }
                            }
                            if environment["UI_REVIEW_PDF"] == "1", let item = app.downloads.items.first { app.downloads.open(item) }
                            if environment["UI_REVIEW_UNSAVED_PDF"] == "1", let item = app.downloads.items.first, let url = app.downloads.fileURL(for: item) {
                                let session = PDFPreviewSession(site: .moodle)
                                session.filename = "PDF Preview.pdf"; session.read(url)
                                let controller = UIHostingController(rootView: DocumentPreviewView(session: session))
                                controller.modalPresentationStyle = .fullScreen
                                session.closeAction = { [weak controller] in controller?.dismiss(animated: true) }
                                session.saveAction = {
                                    guard session.canSave else { return }; session.state = .saving
                                    Task {
                                        do { _ = try await app.downloads.savePreview(url, filename: session.filename, site: .moodle); session.state = .saved }
                                        catch { session.state = .readable; session.error = error.localizedDescription }
                                    }
                                }
                                _ = app.browserPresent(viewController: controller)
                            }
                        }
                } else if environment["UI_REVIEW_LOCK"] == "1" {
                    LockScreenView().environmentObject(previewLock)
                } else {
                    RootTabView().environmentObject(app).environmentObject(settings)
                }
            }
            .environment(\.locale, Locale(identifier: settings.language.rawValue))
            .tint(Theme.accent)
            .preferredColorScheme(settings.appearance.colorScheme)
            .background(
                SceneWindowReader { scene in
                    scene.traitOverrides.preferredContentSizeCategory =
                        environment["UI_REVIEW_LARGE_TEXT"] == "1"
                        ? .accessibilityExtraExtraExtraLarge : .large
                }.frame(width: 0, height: 0))
        }
    }
}

@MainActor private final class PreviewUnavailableAuthenticator: LocalAuthenticating {
    var isAvailable: Bool { false }
    var label: String { "设备密码" }
    func authenticate() async throws -> Bool { false }
}
