import SwiftUI
import WidgetKit

@main
struct GTIITWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShuttleLiveActivityWidget()
        CourseLiveActivityWidget()
        StudyHomeWidget()
        ShuttleHomeWidget()
        ShuttleConfiguredWidget()
    }
}