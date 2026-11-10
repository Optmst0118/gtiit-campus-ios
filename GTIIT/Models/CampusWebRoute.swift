import Foundation

struct CampusWebRoute: Identifiable, Hashable {
    let id = UUID()
    let site: SiteID
    let url: URL
    let title: String
    var replacesStack = false
}
