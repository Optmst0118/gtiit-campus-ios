import SwiftUI
struct ActivityExamplesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.tr("班车实时活动")).font(.headline)
                ShuttleActivitySummary(attributes: ShuttleActivityAttributes(directionTitle: "南 → 北", origin: "南校区", destination: "北校区", departureTime: "17:25", busLabel: "1 号车", directionRaw: "southToNorth", languageCode: "zh-Hans", departedLabel: "计划时间已过"), state: .init(departureDate: Date().addingTimeInterval(345), busNumber: 1))
                Text(L10n.tr("课程实时活动")).font(.headline)
                CourseActivitySummary(attributes: CourseActivityAttributes(occurrenceID: "example", title: "Introduction to Robotics", room: "E1-205", building: "南校区 · 教学楼", language: L10n.language.rawValue), state: .init(start: Date().addingTimeInterval(480), end: Date().addingTimeInterval(5880)))
            }.padding(20)
        }.nativeDetailSurface(title: L10n.tr("实时活动示例"))
    }
}
