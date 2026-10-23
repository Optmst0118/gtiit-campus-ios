import Foundation

struct CampusWebRoute: Identifiable, Equatable {
    let id = UUID()
    let site: SiteID
    let url: URL
    let title: String
}
