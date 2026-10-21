import SwiftUI

struct SiteInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let site: SiteID
    var body: some View {
        NavigationStack {
            SiteDataView(site: site)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
