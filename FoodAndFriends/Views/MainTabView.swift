import SwiftUI

/// Which chapter is open — shared so any page can turn to another
/// (Home's "All recipes" opens Recipes).
@MainActor
final class TabRouter: ObservableObject {
    @Published var selection: MainTabView.Tab {
        didSet {
            if MainTabView.Tab.more.contains(selection) { moreChapter = selection }
        }
    }
    /// Which chapter the fourth page holds — the last one opened from MORE.
    @Published private(set) var moreChapter: MainTabView.Tab

    init(selection: MainTabView.Tab = .home) {
        self.selection = selection
        self.moreChapter = MainTabView.Tab.more.contains(selection) ? selection : .mealPlans
    }
}

/// The journal's chapters, in the order they're bound.
///
/// HOME · RECIPES · SHOPPING on the thumb index, and MORE for the rest —
/// MENUS, TABLE, YOU. Use these names everywhere. A chapter opened from
/// More takes the More slot and prints its own name there, so you can see
/// which one is open.
struct MainTabView: View {
    @StateObject private var router: TabRouter = {
        #if DEBUG
        return TabRouter(selection: Tab(rawValue: DesignHarness.initialTab) ?? .home)
        #else
        return TabRouter()
        #endif
    }()

    enum Tab: Int, CaseIterable {
        case home
        case recipes
        case shopping
        case mealPlans
        case feed
        case profile

        /// Always on the thumb index.
        static let pinned: [Tab] = [.home, .recipes, .shopping]
        /// Behind MORE.
        static let more: [Tab] = [.mealPlans, .feed, .profile]

        var title: String {
            switch self {
            case .home: return "Home"
            case .recipes: return "Recipes"
            case .shopping: return "Shopping"
            case .mealPlans: return "Menus"
            case .feed: return "Table"
            case .profile: return "You"
            }
        }

        var glyph: String {
            switch self {
            case .home: return "book.closed"
            case .recipes: return "fork.knife"
            case .shopping: return "cart"
            case .mealPlans: return "calendar"
            case .feed: return "person.2"
            case .profile: return "person"
            }
        }
    }

    var body: some View {
        // Four pages, never more: past five, iOS files the extras under its own
        // "More" list and gives them a back button. The fourth page holds
        // whichever chapter was last opened from MORE.
        TabView(selection: $router.selection) {
            HomeView().hideSystemTabBar().tag(Tab.home)
            RecipesView().hideSystemTabBar().tag(Tab.recipes)
            ShoppingListView().hideSystemTabBar().tag(Tab.shopping)
            moreChapter.hideSystemTabBar().tag(router.moreChapter)
        }
        .environmentObject(router)
        // Laid over the foot of the book. Each chapter's scroll views leave room
        // for it (see hideSystemTabBar) — an inset on the TabView itself doesn't
        // reach the pages inside it, so the last lines of a list ended up underneath.
        .overlay(alignment: .bottom) { thumbIndex }
        // The thumb index stays at the foot of the page; the keyboard covers it
        // rather than carrying it up over the list.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var moreChapter: some View {
        switch router.moreChapter {
        case .feed: FeedView()
        case .profile: ProfileView()
        default: MealPlansView()
        }
    }

    /// The thumb index's height above the home indicator: its rule and its tabs.
    static let thumbIndexHeight: CGFloat = 45.5

    // MARK: - Thumb index

    /// The cookbook's thumb tabs, laid flat along the foot of the page.
    /// The open chapter is inked; the rest are printed on the paper.
    private var thumbIndex: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.ink)
                .frame(height: 1.5)

            HStack(spacing: 0) {
                ForEach(Tab.pinned, id: \.self) { tab in
                    Button {
                        router.selection = tab
                    } label: {
                        thumb(tab.title, glyph: tab.glyph, isOpen: router.selection == tab)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(router.selection == tab ? .isSelected : [])
                }

                moreThumb
            }
            .background(Theme.paper, ignoresSafeAreaEdges: [])
        }
        .background(Theme.paper)
    }
}

extension MainTabView {
    /// One thumb tab: glyph over small caps, inked when its chapter is open.
    fileprivate func thumb(_ title: String, glyph: String, isOpen: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: glyph)
                .font(.system(size: 13, weight: isOpen ? .semibold : .regular))
                .frame(height: 16) // "…" is shorter than the other glyphs; keep every label on one line
            Text(title.uppercased())
                .smallCaps(9, weight: isOpen ? .bold : .medium, tracking: 1.0)
        }
        .foregroundColor(isOpen ? Theme.paper : Theme.ink2)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        // A colour background touching the safe area bleeds into it;
        // the open tab is a tab, not a column to the bottom of the glass.
        .background(isOpen ? Theme.ink : Color.clear, ignoresSafeAreaEdges: [])
        .contentShape(Rectangle())
    }

    /// The fourth thumb: MORE, opening a short menu of the other chapters.
    /// Once one is open it holds this slot, inked and under its own name.
    fileprivate var moreThumb: some View {
        let open = Tab.more.first { $0 == router.selection }
        return Menu {
            ForEach(Tab.more, id: \.self) { tab in
                Button {
                    router.selection = tab
                } label: {
                    Label(tab.title, systemImage: tab.glyph)
                }
            }
        } label: {
            thumb(open?.title ?? "More", glyph: open?.glyph ?? "ellipsis", isOpen: open != nil)
        }
        .accessibilityLabel(open.map { "\($0.title), more chapters" } ?? "More chapters")
    }
}

private extension View {
    /// Ours replaces it — the system bar would print underneath.
    func hideSystemTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
            // Room at the foot of every page for the thumb index laid over it.
            // A content margin, not a safe-area inset: it's carried down through
            // the environment into each chapter's NavigationStack and its
            // scroll views, where an inset applied out here never arrives.
            .contentMargins(.bottom, MainTabView.thumbIndexHeight, for: .scrollContent)
    }
}

#Preview {
    MainTabView()
}
