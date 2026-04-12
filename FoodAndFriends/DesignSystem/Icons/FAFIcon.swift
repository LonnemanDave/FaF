import SwiftUI

// MARK: - Icon System
/// Food and Friends icons using SF Symbols
/// Wrapper for consistent styling across the app

enum FAFIconType: String, CaseIterable {
    case home
    case search
    case heart
    case heartFilled
    case profile
    case settings
    case plus
    case close
    case back
    case forward
    case check
    case menu
    case fork
    case friends
    case calendar
    case location
    case chat
    case bell
    case star
    case starFilled

    var sfSymbol: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .heart: return "heart"
        case .heartFilled: return "heart.fill"
        case .profile: return "person"
        case .settings: return "gearshape"
        case .plus: return "plus"
        case .close: return "xmark"
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .check: return "checkmark"
        case .menu: return "line.3.horizontal"
        case .fork: return "fork.knife"
        case .friends: return "person.2"
        case .calendar: return "calendar"
        case .location: return "location"
        case .chat: return "bubble.left"
        case .bell: return "bell"
        case .star: return "star"
        case .starFilled: return "star.fill"
        }
    }
}

struct FAFIcon: View {
    let type: FAFIconType
    let size: CGFloat
    let color: Color
    let weight: Font.Weight

    init(
        _ type: FAFIconType,
        size: CGFloat = 24,
        color: Color = .fafBlack,
        weight: Font.Weight = .regular
    ) {
        self.type = type
        self.size = size
        self.color = color
        self.weight = weight
    }

    var body: some View {
        Image(systemName: type.sfSymbol)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 24) {
            ForEach(FAFIconType.allCases, id: \.self) { icon in
                VStack(spacing: 8) {
                    FAFIcon(icon, size: 28, color: .fafBlack)
                    Text(icon.rawValue)
                        .font(.system(size: 9))
                        .foregroundColor(.fafGray)
                }
            }
        }
        .padding()
    }
}
