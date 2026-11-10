import SwiftUI
import WidgetKit

@main struct WidgetReviewApp: App {
    var body: some Scene { WindowGroup { WidgetGallery().task { WidgetFixtures.render() } } }
}

@MainActor enum WidgetFixtures {
    static let now = Date()
    static var snapshot: StudyWidgetSnapshot {
        let courses = ["Ordinary Differential Equations", "Introduction to Robotics", "Thermodynamics 1", "Graphics and Engin. Design"]
        var items: [StudyWidgetSnapshot.Item] = []
        for index in 0..<4 {
            let course = StudyWidgetSnapshot.courseName(courses[index])
            let title = index == 0 ? "Homework 3 Assignment" : "Homework 4 Assignment"
            let due = now.addingTimeInterval(Double(index + 1) * 86400)
            items.append(.init(id: String(index), course: course, title: title, due: due, pending: true))
        }
        items.append(.init(id: "expired", course: "Expired item must never appear", title: "Old work", due: now.addingTimeInterval(-86400), pending: true))
        items.append(.init(id: "farFuture", course: "Far future must never appear", title: "Later work", due: now.addingTimeInterval(30 * 86400), pending: true))
        return StudyWidgetSnapshot(items: items, updatedAt: now, verified: true)
    }
    static func study(_ family: WidgetFamily, english: Bool = false) -> some View {
        StudyHomeView(familyOverride: family, entry: .init(date: now, snapshot: snapshot, english: english))
    }
    static func shuttle(_ family: WidgetFamily, direction: ShuttleDirection? = nil, english: Bool = false) -> some View {
        ShuttleHomeView(familyOverride: family, entry: .init(date: now, suggested: direction,
            north: ShuttleSchedule.upcoming(.southToNorth, after: now, teachingWeek: true, limit: 1).first,
            south: ShuttleSchedule.upcoming(.northToSouth, after: now, teachingWeek: true, limit: 1).first, english: english))
    }
    static func exam(_ family: WidgetFamily, english: Bool = false) -> some View {
        let courses = ["Ordinary Differential Equations", "Thermodynamics 1", "Creative Mechanical Engineering"]
        var items: [ExamWidgetSnapshot.Item] = []
        for index in 0..<6 {
            let date = now.addingTimeInterval(Double(index + 1) * 86400)
            items.append(ExamWidgetSnapshot.Item(id: String(index), course: courses[index % 3], date: date, end: date.addingTimeInterval(7200), venue: "SC L-110 · L-111", sitting: index > 2 ? "A 考" : nil))
        }
        return ExamHomeView(familyOverride: family, entry: .init(date: now, snapshot: .init(items: items, updatedAt: now), english: english))
    }
    static func render() {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let warmup = ImageRenderer(content: study(.systemSmall).frame(width: 170, height: 170))
        _ = warmup.uiImage
        for dark in [false, true] {
            for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
                let label = family == .systemSmall ? "small" : family == .systemMedium ? "medium" : "large"
                let size = CGSize(width: family == .systemSmall ? 170 : 364, height: family == .systemLarge ? 382 : 170)
                func save<V: View>(_ view: V, _ name: String) {
                    let renderer = ImageRenderer(content: view.padding(16).frame(width: size.width, height: size.height)
                        .background(WidgetStyle.background).environment(\.colorScheme, dark ? .dark : .light))
                    renderer.scale = 2
                    try? renderer.uiImage?.pngData()?.write(to: root.appendingPathComponent("\(name)-\(label)-\(dark ? "dark" : "light").png"))
                }
                save(exam(family), "exam"); save(exam(family, english: true), "exam-en")
                save(study(family), "study"); save(study(family, english: true), "study-en")
                if family != .systemLarge {
                    save(shuttle(family), "shuttle")
                    save(shuttle(family, direction: .southToNorth), "shuttle-near-south")
                    save(shuttle(family, direction: .northToSouth, english: true), "shuttle-near-north-en")
                }
            }
        }
        if let runID = ProcessInfo.processInfo.environment["WIDGET_REVIEW_RUN_ID"] {
            try? runID.write(to: root.appendingPathComponent("render-complete.txt"), atomically: true, encoding: .utf8)
        }
    }
}

struct WidgetGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    tile(WidgetFixtures.study(.systemSmall), width: 170)
                    tile(WidgetFixtures.shuttle(.systemSmall, direction: .southToNorth), width: 170)
                }
                tile(WidgetFixtures.study(.systemMedium), width: 364)
                tile(WidgetFixtures.shuttle(.systemMedium), width: 364)
                tile(WidgetFixtures.shuttle(.systemMedium, direction: .northToSouth), width: 364)
            }.padding(.vertical, 24).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground))
    }
    private func tile<V: View>(_ view: V, width: CGFloat) -> some View {
        view.padding(16).frame(width: width, height: 170)
            .background(WidgetStyle.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
