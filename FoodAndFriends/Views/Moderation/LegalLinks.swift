import Foundation

/// The pages App Review and the cook both need to be able to reach.
enum LegalLinks {
    static let site = URL(string: "https://faf-1-93659.web.app")!
    static let terms = site.appendingPathComponent("terms")
    static let privacy = site.appendingPathComponent("privacy")
    static let support = site.appendingPathComponent("support")
}
