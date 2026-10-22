import UIKit

@MainActor enum CampusNetworkAccess {
    // Registered by the vendor's installed aTrust client. iOS support is checked
    // at runtime; never assume an installed iOS client exposes this scheme.
    static let clientURL = URL(string: "atrust://")!
    static let storeURL = URL(string: "https://apps.apple.com/app/id1536711104")!
    static var canOpenClient: Bool { UIApplication.shared.canOpenURL(clientURL) }
    static func openClient(completion: @escaping (Bool) -> Void) {
        guard canOpenClient else { completion(false); return }
        UIApplication.shared.open(clientURL, options: [:], completionHandler: completion)
    }
}
