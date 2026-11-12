import SwiftUI

/// One destination factory for existing native entry points. A page always uses
/// the AppModel-owned store, regardless of which shortcut/card opened it.
enum CampusDetail: Hashable {
    case timetable, assignments, exams, downloads, academicCalendar, inbox, settings
    case calendarDay(String), timetableDay(String)
    case web(CampusWebRoute)
}

struct CampusDetailPage: View {
    @EnvironmentObject private var app: AppModel
    let destination: CampusDetail
    var body: some View {
        switch destination {
        case .web(let route): NativeWebPageView(site: route.site, title: route.title, url: route.url)
        case .settings: SettingsView()
        case .calendarDay(let date): AcademicCalendarView(selectedDate: CampusDate.parse(date))
        case .inbox: CampusInboxView(store: app.messages)
        case .timetable: LocalTimetableView(store: app.timetable)
        case .timetableDay(let day): LocalTimetableView(store: app.timetable, initialDay: day)
        case .assignments: MoodleUpcomingView(store: app.upcoming)
        case .exams: StudentExamsView(store: app.exams)
        case .downloads: DownloadsView(center: app.downloads)
        case .academicCalendar: AcademicCalendarView()
        }
    }
}
