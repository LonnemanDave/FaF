import SwiftUI
import UIKit

/// UIKit chrome, set in the journal's voice. SwiftUI still hands nav bars,
/// segmented controls, lists and search fields to UIKit, and their defaults
/// are the exact rounded-and-floating look the design is leaving behind.
enum JournalAppearance {

    static func install() {
        let paper = UIColor(named: "Paper") ?? .systemBackground
        let ink = UIColor(named: "Ink") ?? .label
        let ink2 = UIColor(named: "Ink2") ?? .secondaryLabel
        let rule = UIColor(named: "Rule") ?? .separator
        let accent = UIColor(named: "Paprika") ?? .systemRed

        // MARK: Navigation bar — paper ground, serif title, a rule for an edge

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = paper
        nav.shadowColor = rule
        nav.titleTextAttributes = [
            .foregroundColor: ink,
            .font: serif(size: 17, weight: .semibold),
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: ink,
            .font: serif(size: 32, weight: .bold),
        ]

        let barText: [NSAttributedString.Key: Any] = [
            .foregroundColor: ink,
            .font: UIFont.systemFont(ofSize: 15, weight: .medium),
        ]
        nav.buttonAppearance.normal.titleTextAttributes = barText
        nav.backButtonAppearance.normal.titleTextAttributes = barText

        /* iOS 26 draws bar buttons on a glass capsule. A clear background
         * image takes it away and leaves the word. */
        let clear = UIImage()
        nav.buttonAppearance.normal.backgroundImage = clear
        nav.buttonAppearance.highlighted.backgroundImage = clear
        nav.doneButtonAppearance.normal.backgroundImage = clear
        nav.backButtonAppearance.normal.backgroundImage = clear

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = ink

        // MARK: Segmented controls — flat index tabs, not a pill of bubbles

        let segment = UISegmentedControl.appearance()
        segment.selectedSegmentTintColor = ink
        segment.backgroundColor = paper
        segment.setTitleTextAttributes([
            .foregroundColor: ink2,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
        ], for: .normal)
        segment.setTitleTextAttributes([
            .foregroundColor: paper,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
        ], for: .selected)

        // MARK: Lists, search, refresh — all sit on paper

        UITableView.appearance().backgroundColor = paper
        UICollectionView.appearance().backgroundColor = paper
        UIRefreshControl.appearance().tintColor = accent
        UISearchBar.appearance().tintColor = ink
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = paper
    }

    /// New York (the system serif) at a given size and weight.
    static func serif(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
