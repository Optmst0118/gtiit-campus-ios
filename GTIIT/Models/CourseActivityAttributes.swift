import ActivityKit
import Foundation
struct CourseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { let start: Date; let end: Date }
    let occurrenceID: String
    let title: String
    let room: String
    let building: String
    let language: String
}
