import SwiftUI

/// One destination factory for existing native entry points. A page always uses
/// the AppModel-owned store, regardless of which shortcut/card opened it.
enum CampusDetail: String, CaseIterable, Hashable {
    case timetable, assignments, exams, downloads, academicCalendar
}

struct CampusDetailPage: View {
    @EnvironmentObject private var app: AppModel
    let destination: CampusDetail
    var body: some View {
        switch destination {
        case .timetable: LocalTimetableView(store: app.timetable)
        case .assignments: MoodleUpcomingView(store: app.upcoming)
        case .exams: StudentExamsView(store: app.exams)
        case .downloads: DownloadsView(center: app.downloads)
        case .academicCalendar: AcademicCalendarView()
        }
    }
}
