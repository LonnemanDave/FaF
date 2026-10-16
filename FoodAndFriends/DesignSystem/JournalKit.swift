import SwiftUI

/// JournalKit — the cooking journal's design language.
///
/// The app is a cook's notebook, not a feed of cards. Everything here exists
/// to make a screen read like a written-up page: plate headers with double
/// rules, small-caps section heads, recipes set as an index with dot leaders
/// and right-aligned figures, ingredients with their amounts in a column, and
/// meals that look stamped rather than badged. Nothing floats — no shadows,
/// no capsules, no rounded surfaces sitting on a background.
///
/// The same vocabulary as CragLog's GuidebookKit, on purpose: one way of
/// building a page across both books.

// MARK: - Type

extension Font {
    /// Display type — plate titles, recipe names, big figures.
    static func plate(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Tabular data — amounts, minutes, counts, dates. Always monospaced so columns line up.
    static func figure(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Body copy — ingredient names, method, prose.
    static func setting(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Text {
    /// Small-caps voice: uppercase, tracked wide. Section heads, labels, stamps.
    func smallCaps(_ size: CGFloat = 11, weight: Font.Weight = .semibold, tracking: CGFloat = 1.6) -> Text {
        self.font(.system(size: size, weight: weight))
            .tracking(tracking)
    }
}

// MARK: - Rules

/// A hairline rule that fills the space it's given. The journal's workhorse
/// separator — it replaces card edges everywhere.
struct Rule: View {
    var weight: CGFloat = 1
    var color: Color = Theme.rule

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
    }
}

/// Thick-over-thin double rule — the mark that opens a plate.
struct DoubleRule: View {
    var color: Color = Theme.ink

    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(color).frame(height: 2)
            Rectangle().fill(color.opacity(0.55)).frame(height: 0.5)
        }
    }
}

/// Dashed rule — used between entries inside a listing.
struct DashedDivider: View {
    var color: Color = Theme.rule

    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundColor(color)
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            return path
        }
    }
}

/// The dot leader that carries the eye from a recipe to its time.
/// Sits on the text baseline when used inside a `.firstTextBaseline` stack.
struct DotLeader: View {
    var spacing: CGFloat = 5
    var color: Color = Theme.ink3

    var body: some View {
        Canvas { context, size in
            let radius: CGFloat = 0.9
            var x = size.width.truncatingRemainder(dividingBy: spacing) / 2
            while x < size.width {
                let dot = Path(ellipseIn: CGRect(x: x - radius, y: size.height / 2 - radius,
                                                 width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(color))
                x += spacing
            }
        }
        .frame(height: 4)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 1 }
        .accessibilityHidden(true)
    }
}

// MARK: - Plate header

/// Opens a screen the way a cookbook opens a chapter: double rule, serif
/// title with an optional figure set opposite, hairline underneath.
struct PlateHeader: View {
    let title: String
    var subtitle: String?
    /// Set opposite the title — a count, a date range.
    var figure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 10)

            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.plate(30))
                    .foregroundColor(Theme.ink)
                Spacer(minLength: Theme.spacingSM)
                if let figure {
                    Text(figure)
                        .font(.figure(13, .medium))
                        .foregroundColor(Theme.ink2)
                }
            }

            if let subtitle {
                Text(subtitle.uppercased())
                    .smallCaps(10, weight: .medium, tracking: 1.4)
                    .foregroundColor(Theme.ink2)
                    .padding(.top, 4)
            }

            Rule()
                .padding(.top, 10)
        }
    }
}

/// A section head inside a plate: small-caps label, rule filling the line,
/// optional figure at the end. Replaces bold titles floating over cards.
struct SectionHead: View {
    let title: String
    var figure: String?

    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            Text(title.uppercased())
                .smallCaps()
                .foregroundColor(Theme.ink2)
                .fixedSize()
            Rule()
            if let figure {
                Text(figure.uppercased())
                    .smallCaps(10, weight: .medium, tracking: 1.2)
                    .foregroundColor(Theme.ink3)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Index entries

/// One line of the index: name (with optional second line), dot leader,
/// then the figure — a time, a count — set flush right in monospace.
struct IndexEntry<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let figure: String
    var figureColor: Color = Theme.accent
    var dimmed: Bool = false
    /// Recipe names are set in the display serif; lesser lines stay in the text face.
    var serifTitle: Bool = false
    /// An index numeral set in the left margin.
    var mark: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let mark {
                    Text(mark)
                        .font(.figure(11, .medium))
                        .foregroundColor(Theme.ink3)
                        .frame(width: 18, alignment: .leading)
                }

                Text(title)
                    .font(serifTitle ? .plate(17, .semibold) : .setting(16))
                    .foregroundColor(dimmed ? Theme.ink2 : Theme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)

                DotLeader()

                Text(figure)
                    .font(.figure(15, .semibold))
                    .foregroundColor(figureColor)
                    .fixedSize()

                trailing
            }

            if let subtitle {
                Text(subtitle)
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
                    .lineLimit(1)
                    .padding(.leading, mark == nil ? 0 : 24)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

extension IndexEntry where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, figure: String,
         figureColor: Color = Theme.accent, dimmed: Bool = false,
         serifTitle: Bool = false, mark: String? = nil) {
        self.init(title: title, subtitle: subtitle, figure: figure,
                  figureColor: figureColor, dimmed: dimmed,
                  serifTitle: serifTitle, mark: mark) { EmptyView() }
    }
}

/// A chapter head inside the index — a day of a menu, with its tally opposite.
struct ChapterHead: View {
    let name: String
    var note: String?
    var tally: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name)
                    .font(.plate(19))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: Theme.spacingSM)
                if let tally {
                    Text(tally)
                        .font(.figure(11, .medium))
                        .foregroundColor(Theme.ink3)
                }
            }
            if let note {
                Text(note)
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
            }
        }
    }
}

// MARK: - Printed figures

extension Date {
    /// Dates as the journal sets them: "2 Aug" this year, "2 Aug 2025" before.
    var printed: String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: self) == calendar.component(.year, from: Date())
        return sameYear
            ? formatted(.dateTime.day().month(.abbreviated))
            : formatted(.dateTime.day().month(.abbreviated).year())
    }
}

extension Int {
    /// Minutes as a recipe prints them: "45 min", "1 hr", "2 hr 15".
    var printedMinutes: String {
        guard self >= 60 else { return "\(self) min" }
        let hours = self / 60
        let minutes = self % 60
        return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes)"
    }
}

/// A row of figures — small-caps label over a monospaced value, columns
/// divided by hairlines. Prep · cook · serves; recipes · menus · friends.
struct Figures: View {
    let items: [(label: String, value: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.label.uppercased())
                        .smallCaps(9, weight: .medium, tracking: 1.3)
                        .foregroundColor(Theme.ink3)
                    Text(item.value)
                        .font(.figure(17, .semibold))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, index > 0 ? 12 : 0)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .plate()
        .padding(.vertical, 2)
    }
}

// MARK: - The recipe page

/// One ingredient, set the way a printed recipe sets it: the amount in a
/// monospaced column on the left, the name after it.
///
/// Tap to strike it through — at the counter while you cook, or in the
/// aisle while you shop. The strike is the reader's pencil, not the
/// recipe's: it lives on the page that's open, and isn't saved.
struct IngredientLine: View {
    let amount: String
    let name: String
    var struck: Bool = false
    var compact: Bool = false

    init(_ ingredient: Ingredient, struck: Bool = false, compact: Bool = false) {
        let unit = ingredient.unit.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        self.amount = unit.isEmpty ? ingredient.quantity : "\(ingredient.quantity) \(unit)"
        self.name = ingredient.name
        self.struck = struck
        self.compact = compact
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
            Text(amount)
                .font(.figure(compact ? 12 : 14, .medium))
                .foregroundColor(struck ? Theme.ink3 : Theme.accent)
                .frame(width: compact ? 64 : 76, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(name)
                .font(.setting(compact ? 13 : 16))
                .foregroundColor(struck ? Theme.ink3 : (compact ? Theme.ink2 : Theme.ink))
                .strikethrough(struck, color: Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 2 : 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(struck ? "crossed off" : "")
    }
}

/// One step of the method: a serif numeral in the margin, the prose beside
/// it, and the ingredients that step uses set small underneath.
struct MethodStep: View {
    let number: Int
    let text: String
    var ingredients: [Ingredient] = []

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
            Text("\(number)")
                .font(.plate(22))
                .foregroundColor(Theme.accent)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text(text)
                    .font(.setting(16))
                    .foregroundColor(Theme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ingredients) { ingredient in
                            IngredientLine(ingredient, compact: true)
                        }
                    }
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.rule).frame(width: 1)
                    }
                }
            }
        }
        .padding(.vertical, Theme.spacingSM)
    }
}

// MARK: - Stamps

/// A meal, stamped: boxed small caps in the meal's own ink, set square.
struct MealStamp: View {
    let mealType: MealType

    var body: some View {
        Text(abbreviation.uppercased())
            .smallCaps(9, weight: .bold, tracking: 1.0)
            .foregroundColor(Self.ink(mealType))
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .overlay(Rectangle().stroke(Self.ink(mealType), lineWidth: 1))
            .fixedSize()
            .accessibilityLabel(mealType.displayName)
    }

    private var abbreviation: String {
        switch mealType {
        case .breakfast: return "bkfst"
        case .lunch: return "lunch"
        case .dinner: return "dinner"
        case .snack: return "snack"
        }
    }

    /// Each meal's ink, pulled from the ramp — never a colour of its own.
    static func ink(_ mealType: MealType) -> Color {
        switch mealType {
        case .breakfast: return Theme.saffron
        case .lunch: return Theme.herb
        case .dinner: return Theme.paprika
        case .snack: return Theme.ink2
        }
    }
}

// MARK: - Ticks

/// A ruled square that's inked in when ticked — the shopping list's box.
struct TickBox: View {
    let ticked: Bool
    var size: CGFloat = 17

    var body: some View {
        ZStack {
            Rectangle()
                .fill(ticked ? Theme.ink : Color.clear)
            Rectangle()
                .stroke(ticked ? Theme.ink : Theme.ink2, lineWidth: 1.2)
            if ticked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundColor(Theme.paper)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Toolbar

extension View {
    /* A toolbar with nothing drawn behind its items.
     *
     * iOS 26 puts every bar button on a shared glass background — and it
     * isn't a capsule, it's a circle that clips the label, so "Cancel"
     * comes out as "CA…". No button style reaches it, because the toolbar
     * draws it around the item rather than the button drawing it itself.
     * sharedBackgroundVisibility is the only opt-out, and it's iOS 26
     * only, so the old path stays for 17 and 18.
     *
     * Use this instead of .toolbar everywhere. */
    @ViewBuilder
    func plainToolbar<C: ToolbarContent>(@ToolbarContentBuilder content: () -> C) -> some View {
        if #available(iOS 26.0, *) {
            self.toolbar { content().sharedBackgroundVisibility(.hidden) }
        } else {
            self.toolbar(content: content)
        }
    }
}

/* The journal's own back button.
 *
 * The system's sits on iOS 26's glass, and unlike the items we declare
 * there's no sharedBackgroundVisibility to reach it — the bar owns it.
 * So the screen hides it and supplies its own. */
struct BackLeaf: ViewModifier {
    let title: String
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text(title.uppercased())
                                .smallCaps(11, weight: .medium, tracking: 1.3)
                        }
                        .foregroundColor(Theme.ink)
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
            }
    }
}

extension View {
    /// Replaces the system back button with the journal's own.
    func backLeaf(_ title: String = "Back") -> some View {
        modifier(BackLeaf(title: title))
    }
}

/* A toolbar action, set as text in the margin.
 *
 * iOS 26 draws bar buttons as glass capsules, which no amount of tint
 * removes — and a capsule is the one shape this journal doesn't have. A
 * plain button style takes the chrome away and leaves the word. */
struct MarginButton: View {
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    init(_ title: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .smallCaps(11, weight: .medium, tracking: 1.3)
                .foregroundColor(destructive ? Theme.error : Theme.ink)
                .fixedSize()
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Writing in the journal

/* A line to write on: the label in small caps, the entry in ink, a rule
 * underneath that darkens while you're writing.
 *
 * No box. A text field with a filled background is how this app put
 * white text on a white box in dark mode — the entry here sits on the
 * page itself, so the ink and the paper always come from the same
 * edition. Use this for every text entry. */
struct FieldLine: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var secure: Bool = false
    var multiline: Bool = false
    /// Set opposite the label — "@", a unit, a character count.
    var note: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .smallCaps(10, weight: .semibold, tracking: 1.4)
                    .foregroundColor(focused ? Theme.ink : Theme.ink2)
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .font(.setting(11))
                        .foregroundColor(Theme.ink3)
                }
            }

            entry
                .font(.setting(17))
                .foregroundColor(Theme.ink)
                .tint(Theme.accent)
                .focused($focused)

            Rule(weight: focused ? 1.5 : 1, color: focused ? Theme.ink : Theme.rule)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    @ViewBuilder
    private var entry: some View {
        let placeholder = Text(prompt).foregroundColor(Theme.ink3)
        if secure {
            SecureField(text: $text, prompt: placeholder) { Text(label) }
        } else if multiline {
            TextField(text: $text, prompt: placeholder, axis: .vertical) { Text(label) }
                .lineLimit(2...8)
        } else {
            TextField(text: $text, prompt: placeholder) { Text(label) }
        }
    }
}

/* A date, set as an index line: the label, a dot leader, the date. The
 * system's compact picker is a grey rounded chip. */
struct DateLine: View {
    let label: String
    @Binding var date: Date
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { open.toggle() }
            } label: {
                IndexEntry(
                    title: label,
                    figure: date.formatted(date: .abbreviated, time: .omitted),
                    figureColor: Theme.ink
                )
            }
            .buttonStyle(.plain)

            if open {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.accent)
                    .padding(.bottom, Theme.spacingSM)
            }
        }
    }
}

// MARK: - Controls

/// Letterpress block button — square corners, inked or outlined, label set
/// in small caps. Replaces the rounded filled pill.
struct PressButtonStyle: ButtonStyle {
    var filled: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(filled ? Theme.paper : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(filled ? Theme.ink : Color.clear)
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
    }
}

extension ButtonStyle where Self == PressButtonStyle {
    static var press: PressButtonStyle { PressButtonStyle(filled: true) }
    static var pressOutline: PressButtonStyle { PressButtonStyle(filled: false) }
}

/// Tabbed index selector — the thumb tabs down the edge of a cookbook,
/// laid flat. Replaces the segmented control.
struct IndexSelector<Value: Hashable, Accessory: View>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    /// Set opposite the tabs — a toggle, a count.
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: Theme.spacingLG) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option.value }
                } label: {
                    VStack(spacing: 5) {
                        Text(option.label.uppercased())
                            .smallCaps(12, weight: isOn ? .bold : .medium, tracking: 1.4)
                            .foregroundColor(isOn ? Theme.ink : Theme.ink3)
                        Rectangle()
                            .fill(isOn ? Theme.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            accessory
        }
        .overlay(alignment: .bottom) { Rule() }
    }
}

extension IndexSelector where Accessory == EmptyView {
    init(options: [(value: Value, label: String)], selection: Binding<Value>) {
        self.init(options: options, selection: selection) { EmptyView() }
    }
}

/// The search line — squared, ruled, sitting on the page. Replaces the
/// rounded system search bubble.
struct SearchLine: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(Theme.ink3)

            TextField(text: $text, prompt: Text(placeholder).foregroundColor(Theme.ink3)) {
                Text(placeholder)
            }
            .font(.setting(15))
            .foregroundColor(Theme.ink)
            .tint(Theme.accent)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.ink3)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
    }
}

/// A small-caps toggle for the margin — anything that switches without
/// deserving a control of its own.
struct MarginToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            Text(label.uppercased())
                .smallCaps(11, weight: .semibold, tracking: 1.2)
                .foregroundColor(isOn ? Theme.paper : Theme.ink2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isOn ? Theme.ink : Color.clear)
                .overlay(Rectangle().stroke(isOn ? Theme.ink : Theme.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pictures

/// A photograph pasted into the journal: cropped square, a hairline round
/// it, the empty frame left as a pencilled box when there's no picture.
struct PhotoPlate: View {
    let url: String?
    var height: CGFloat = 220
    var placeholder: String = "No photograph"
    /// Show the whole picture rather than cropping it to the frame — for product shots.
    var fit: Bool = false

    var body: some View {
        ZStack {
            Theme.fill
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        if fit {
                            image.resizable().scaledToFit().padding(Theme.spacingSM)
                        } else {
                            image.resizable().scaledToFill()
                        }
                    case .empty:
                        ProgressView().tint(Theme.ink3)
                    default:
                        emptyFrame
                    }
                }
            } else {
                emptyFrame
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
    }

    private var emptyFrame: some View {
        Text(placeholder.uppercased())
            .smallCaps(9, weight: .medium, tracking: 1.4)
            .foregroundColor(Theme.ink3)
    }
}

/// A cook's mark in place of a portrait: their initial in the serif, in a
/// ruled square. Photographs, when there are any, are cropped to the same square.
struct Monogram: View {
    let name: String
    var imageURL: String?
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Theme.paper
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        initial
                    }
                }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var initial: some View {
        Text(String(name.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).prefix(1)).uppercased())
            .font(.plate(size * 0.45, .semibold))
            .foregroundColor(Theme.ink2)
    }
}

// MARK: - Page structure

/// Wraps a screen's content in the page: paper ground and the printer's
/// margin. Use instead of a background colour plus card padding.
struct PageModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper)
    }
}

/// A block of listing that runs edge to edge, closed off by hairlines
/// above and below — the printed alternative to a floating card.
struct PlateModifier: ViewModifier {
    var topRule: Bool = true
    var bottomRule: Bool = true

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if topRule { Rule() }
            content
            if bottomRule { Rule() }
        }
    }
}

extension View {
    func page() -> some View { modifier(PageModifier()) }

    func plate(topRule: Bool = true, bottomRule: Bool = true) -> some View {
        modifier(PlateModifier(topRule: topRule, bottomRule: bottomRule))
    }
}

// MARK: - Empty states

/// Nothing written here yet. Set as a centred note, not an illustration in a box.
struct BlankLeaf: View {
    let note: String
    var action: (label: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            Text("—")
                .font(.plate(22))
                .foregroundColor(Theme.ink3)
            Text(note)
                .font(.setting(14))
                .foregroundColor(Theme.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            if let action {
                Button(action.label, action: action.run)
                    .buttonStyle(.pressOutline)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacingXL)
    }
}
