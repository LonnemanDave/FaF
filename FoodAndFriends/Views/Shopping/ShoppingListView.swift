import SwiftUI

// MARK: - One line of the list

/// A thing to buy: the tick box, the name, a dot leader, the amount flush
/// right, and its Kroger product underneath once one's chosen.
///
/// Two targets: the box ticks it (it's in the cart); the rest of the line
/// opens it — its Kroger pick, or the shelves to find one.
struct ShoppingLine: View {
    let item: ShoppingItem
    var showSources: Bool = false
    /// Print the store aisle beside the product — when the list isn't already grouped by it.
    var showAisle: Bool = false
    /// Whether there's a store to search — the "Find at Kroger" hint only makes sense with one.
    var canSearchKroger: Bool = false
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Button(action: onToggle) {
                TickBox(ticked: item.isChecked)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 11 }
            .accessibilityLabel(item.isChecked ? "In the cart" : "Tick off")
            .accessibilityValue(item.shoppingName)

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(item.shoppingName)
                            .font(.setting(16))
                            .foregroundColor(item.isChecked ? Theme.ink3 : Theme.ink)
                            .strikethrough(item.isChecked, color: Theme.ink3)
                            .lineLimit(2)
                            .layoutPriority(1)

                        if item.printedAmount.isEmpty {
                            Spacer(minLength: 0)
                        } else {
                            DotLeader()
                            Text(item.printedAmount)
                                .font(.figure(13, .semibold))
                                .foregroundColor(item.isChecked ? Theme.ink3 : Theme.accent)
                                .fixedSize()
                        }
                    }

                    krogerLine

                    if showSources, !item.sourceRecipeTitles.isEmpty {
                        Text("for " + item.sourceRecipeTitles.joined(separator: ", "))
                            .font(.setting(11).italic())
                            .foregroundColor(Theme.ink3)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(canSearchKroger ? "Opens it at Kroger" : "Ticks it off")
        }
    }

    /// "Kroger Hickory Smoked Bacon · 16 oz ........ $5.49" — or a hint to find one.
    @ViewBuilder
    private var krogerLine: some View {
        if let product = item.krogerProductName {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text([product, item.krogerProductSize, showAisle ? item.krogerProductAisle : nil]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if let cost = item.krogerCost {
                    Text(cost.formatted(.currency(code: "USD")))
                        .font(.figure(11, .medium))
                        .foregroundColor(item.isChecked ? Theme.ink3 : Theme.ink2)
                        .fixedSize()
                }
            }
        } else if canSearchKroger && !item.isChecked {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9, weight: .semibold))
                Text("Find at Kroger".uppercased())
                    .smallCaps(9, weight: .semibold, tracking: 1.3)
            }
            .foregroundColor(Theme.ink3)
            .padding(.vertical, 2)
        }
    }
}

// MARK: - The list, laid out

/// How the list is laid out.
enum ShoppingOrder: Hashable, CaseIterable {
    /// The store's own aisles — produce, then the numbered aisles, then the departments round the back.
    case store
    /// Produce, meat, dairy, pantry… — by kind of thing.
    case section
    /// Which recipe asked for it; what you added yourself on its own.
    case recipe

    var label: String {
        switch self {
        case .store: return "By aisle"
        case .section: return "By section"
        case .recipe: return "By recipe"
        }
    }
}

/// What's still to get, grouped by the chosen order, then everything
/// already ticked folded into one "in the cart" line.
struct ShoppingAisles: View {
    let list: ShoppingList
    var order: ShoppingOrder = .section
    var canSearchKroger: Bool = false
    @ObservedObject private var service = ShoppingListService.shared
    @State private var showCart = false
    @State private var choosingFor: ShoppingItem?

    private struct Group: Identifiable {
        let title: String
        let items: [ShoppingItem]
        var id: String { title }
    }

    private static let byName: (ShoppingItem, ShoppingItem) -> Bool = {
        $0.shoppingName.localizedCaseInsensitiveCompare($1.shoppingName) == .orderedAscending
    }

    private var groups: [Group] {
        switch order {
        case .section:
            return Dictionary(grouping: list.toGet, by: \.aisle)
                .sorted { $0.key < $1.key }
                .map { Group(title: $0.key.title, items: $0.value.sorted(by: Self.byName)) }
        case .store:
            return Dictionary(grouping: list.toGet) { $0.krogerProductAisle ?? "" }
                .sorted { StoreAisle.rank($0.key) < StoreAisle.rank($1.key) }
                .map { Group(title: $0.key.isEmpty ? "Not matched yet" : $0.key, items: $0.value.sorted(by: Self.byName)) }
        case .recipe:
            // An ingredient two recipes share is listed once, under "More than one recipe".
            return Dictionary(grouping: list.toGet) { item -> String in
                switch item.sourceRecipeTitles.count {
                case 0: return ""
                case 1: return item.sourceRecipeTitles[0]
                default: return "More than one recipe"
                }
            }
            .sorted { lhs, rhs in
                // Recipes alphabetically, the shared ones after, your own lines last.
                let rank: (String) -> Int = { $0.isEmpty ? 2 : ($0 == "More than one recipe" ? 1 : 0) }
                return (rank(lhs.key), lhs.key) < (rank(rhs.key), rhs.key)
            }
            .map { Group(title: $0.key.isEmpty ? "Your own" : $0.key, items: $0.value.sorted(by: Self.byName)) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if list.toGet.isEmpty {
                Text(list.items.isEmpty ? "Nothing on the list." : "Everything's in the cart.")
                    .font(.setting(15).italic())
                    .foregroundColor(Theme.ink2)
                    .padding(.vertical, Theme.spacingSM)
            }

            ForEach(groups) { group in
                HStack(alignment: .firstTextBaseline) {
                    Text(group.title.uppercased())
                        .smallCaps(9, weight: .semibold, tracking: 1.4)
                        .foregroundColor(Theme.ink3)
                    Spacer()
                    // A recipe's own group can be taken off the list in one go.
                    if order == .recipe, group.title != "Your own", group.title != "More than one recipe" {
                        MarginButton("Remove") {
                            Task { await service.removeRecipe(titled: group.title) }
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 1)

                ForEach(group.items) { item in
                    line(item)
                }
            }

            if !list.inTheCart.isEmpty {
                Rule().padding(.top, 12)

                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showCart.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCart ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(list.inTheCart.count) in the cart".uppercased())
                                .smallCaps(10, weight: .semibold, tracking: 1.3)
                        }
                        .foregroundColor(Theme.ink2)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    MarginButton("Clear the cart") {
                        Task { await service.clearChecked() }
                    }
                }

                if showCart {
                    ForEach(list.inTheCart) { item in
                        line(item)
                    }
                }
            }
        }
        .sheet(item: $choosingFor) { item in
            KrogerShelf(mode: .line(item))
        }
    }

    private func line(_ item: ShoppingItem) -> some View {
        ShoppingLine(
            item: item,
            showSources: order != .recipe && Set(list.items.flatMap(\.sourceRecipeTitles)).count > 1,
            showAisle: order != .store,
            canSearchKroger: canSearchKroger,
            onToggle: { Task { await service.toggle(item) } },
            onOpen: {
                if canSearchKroger {
                    choosingFor = item
                } else {
                    Task { await service.toggle(item) }
                }
            }
        )
        .contextMenu {
            Button(role: .destructive) {
                Task { await service.remove(item) }
            } label: {
                Label("Take off the list", systemImage: "minus.circle")
            }
        }
    }
}

/// Where a Kroger aisle comes in a walk round the store.
enum StoreAisle {
    /// Produce at the door, the numbered aisles in order, the departments
    /// round the back (meat, dairy, bakery…) alphabetically, unmatched last.
    static func rank(_ label: String) -> (Int, Int, String) {
        if label.isEmpty { return (3, 0, "") }
        let lowered = label.lowercased()
        if lowered.contains("produce") || ShoppingAisle.classify(label) == .produce { return (0, 0, lowered) }
        if let number = Int(lowered.filter(\.isNumber)), lowered.contains("aisle") { return (1, number, lowered) }
        return (2, 0, lowered)
    }
}

// MARK: - Shopping

/// Shopping — the list's own chapter. Recipes' ingredients and anything
/// else you need, laid out by aisle, section or recipe; matched to your
/// Kroger store one line at a time.
struct ShoppingListView: View {
    @ObservedObject private var service = ShoppingListService.shared
    @ObservedObject private var userService = UserService.shared
    @State private var newLine = ""
    @State private var confirmStartOver = false
    @State private var choosingStore = false
    /// Nil until chosen: by section while lines are still being matched,
    /// by aisle once every one has a Kroger product.
    @State private var order: ShoppingOrder?
    @State private var isMatching = false
    @State private var matchNote: String?
    @State private var shelf: KrogerShelf.Mode?

    var body: some View {
        NavigationStack {
            page
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                PlateHeader(
                    title: "Shopping",
                    subtitle: subtitle,
                    figure: service.list.map { "\($0.toGet.count) to get" }
                )

                kroger

                writeIn

                if let list = service.list, !list.items.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        IndexSelector(
                            options: orders.map { (value: $0, label: $0.label) },
                            selection: Binding(get: { effectiveOrder }, set: { order = $0 })
                        )
                        ShoppingAisles(list: list, order: effectiveOrder, canSearchKroger: storeId != nil)
                    }

                    Button("Clear the list") { confirmStartOver = true }
                        .buttonStyle(.pressOutline)
                        .padding(.top, Theme.spacingSM)
                } else {
                    BlankLeaf(note: "Nothing on the list yet. Add a recipe's ingredients from its page, or write anything in above.")
                }

                if let error = service.lastError {
                    Text(error)
                        .font(.setting(12))
                        .foregroundColor(Theme.error)
                }
            }
            .padding(.top, Theme.spacingSM)
            .padding(.bottom, Theme.spacingXL)
            .page()
        }
        .background(Theme.paper)
        .confirmationDialog("Clear the list?", isPresented: $confirmStartOver, titleVisibility: .visible) {
            Button("Clear the list", role: .destructive) {
                Task { await service.startOver() }
            }
        } message: {
            Text("Everything comes off and you start fresh. This list is filed away, not deleted.")
        }
        .sheet(isPresented: $choosingStore) {
            KrogerStorePicker()
        }
        .sheet(item: $shelf) { mode in
            KrogerShelf(mode: mode)
        }
    }

    private var storeId: String? { userService.currentUser?.krogerLocationId }

    /// Aisle order only makes sense once there's a store to take the aisles from.
    private var orders: [ShoppingOrder] {
        storeId == nil ? [.section, .recipe] : ShoppingOrder.allCases
    }

    private var effectiveOrder: ShoppingOrder {
        // Jumping to aisle order after the first pick would pile every other
        // line into "Not matched yet" — so only once they're all matched.
        let toGet = service.list?.toGet ?? []
        let allMatched = !toGet.isEmpty && toGet.allSatisfy(\.isMatchedAtKroger)
        let wanted = order ?? (allMatched ? .store : .section)
        return orders.contains(wanted) ? wanted : .section
    }

    /// What the list holds — "1 recipe · 2 of your own" — not whose it is.
    private var subtitle: String {
        guard let list = service.list, !list.items.isEmpty else { return "For the next shop" }
        let recipes = Set(list.items.flatMap(\.sourceRecipeTitles)).count
        let own = list.items.filter { $0.sourceRecipeTitles.isEmpty }.count
        var parts: [String] = []
        if recipes > 0 { parts.append("\(recipes) \(recipes == 1 ? "recipe" : "recipes")") }
        if own > 0 { parts.append("\(own) of your own") }
        return parts.joined(separator: " · ")
    }

    // MARK: Kroger

    /// The store, matching everything at once, and what the list should come to.
    @ViewBuilder
    private var kroger: some View {
        if let storeName = userService.currentUser?.krogerStoreName, let locationId = storeId {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Kroger".uppercased())
                        .smallCaps(10, weight: .bold, tracking: 1.4)
                        .foregroundColor(Theme.accent)
                    Text(storeName)
                        .font(.setting(14))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    MarginButton("Change") { choosingStore = true }
                }

                if let list = service.list, !list.toGet.isEmpty {
                    let unmatched = list.toGet.filter { !$0.isMatchedAtKroger }.count
                    if unmatched > 0 {
                        HStack {
                            Text("Tap a line to pick its product".uppercased())
                                .smallCaps(9, weight: .medium, tracking: 1.2)
                                .foregroundColor(Theme.ink3)
                            Spacer()
                            if isMatching {
                                ProgressView().tint(Theme.ink3).scaleEffect(0.7)
                            } else {
                                MarginButton("Match all \(unmatched)") {
                                    Task { await match(at: locationId) }
                                }
                            }
                        }
                    }

                    if let total = estimatedTotal(list) {
                        IndexEntry(
                            title: "Estimated total",
                            subtitle: "What's still to get, at today's prices",
                            figure: total.formatted(.currency(code: "USD")),
                            figureColor: Theme.ink
                        )
                    }
                }

                if let matchNote {
                    Text(matchNote.uppercased())
                        .smallCaps(9, weight: .semibold, tracking: 1.3)
                        .foregroundColor(Theme.herb)
                }
            }
            .padding(.vertical, Theme.spacingSM)
            .plate()
        } else {
            Button {
                choosingStore = true
            } label: {
                IndexEntry(
                    title: "Shop at Kroger",
                    subtitle: "Pick your store to see real products, prices and aisles",
                    figure: "Choose",
                    figureColor: Theme.accent
                )
            }
            .buttonStyle(.plain)
            .plate()
        }
    }

    private func estimatedTotal(_ list: ShoppingList) -> Double? {
        let costs = list.toGet.compactMap(\.krogerCost)
        return costs.isEmpty ? nil : costs.reduce(0, +)
    }

    private func match(at locationId: String) async {
        isMatching = true
        matchNote = nil
        let result = await service.matchAtKroger(locationId: locationId)
        isMatching = false
        if service.lastError == nil {
            matchNote = result.missed == 0
                ? "Found all \(result.matched)"
                : "Found \(result.matched) · \(result.missed) still to find"
            if result.missed == 0 { order = .store }
        }
    }

    // MARK: Writing in

    /// Anything you need — written in plain, or found on the Kroger shelves.
    private var writeIn: some View {
        HStack(alignment: .bottom, spacing: Theme.spacingMD) {
            FieldLine(label: "Add anything", text: $newLine, prompt: "Paper towels, coffee, a lemon…")
                .submitLabel(.done)
                .onSubmit(addLine)
            if !newLine.trimmingCharacters(in: .whitespaces).isEmpty {
                if storeId != nil {
                    MarginButton("Kroger") {
                        shelf = .newLine(newLine.trimmingCharacters(in: .whitespaces))
                        newLine = ""
                    }
                    .padding(.bottom, 10)
                }
                MarginButton("Add", action: addLine)
                    .padding(.bottom, 10)
            }
        }
    }

    private func addLine() {
        guard let user = userService.currentUser else { return }
        let text = newLine
        newLine = ""
        Task { await service.addByHand(text, author: user) }
    }
}

// MARK: - Choosing a store

/// Kroger stores near a ZIP code; the one you pick is remembered on your profile.
struct KrogerStorePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var zipCode = ""
    @State private var storeLink = ""
    @State private var linkError: String?
    @State private var stores: [KrogerStore] = []
    @State private var isSearching = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    PlateHeader(title: "Your Kroger", subtitle: "Where you shop")

                    HStack(alignment: .bottom, spacing: Theme.spacingSM) {
                        FieldLine(label: "ZIP code", text: $zipCode, prompt: "Five digits")
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                        MarginButton("Find") { Task { await search() } }
                            .disabled(zipCode.count != 5 || isSearching)
                            .padding(.bottom, 10)
                    }

                    if isSearching {
                        ProgressView().tint(Theme.ink3).frame(maxWidth: .infinity)
                    }

                    if let error {
                        Text(error).font(.setting(13)).foregroundColor(Theme.error)
                    }

                    if !stores.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHead(title: "Nearby", figure: "\(stores.count)")
                            ForEach(stores) { store in
                                Button {
                                    Task { await choose(store) }
                                } label: {
                                    IndexEntry(title: store.name, subtitle: store.address, figure: "Choose", figureColor: Theme.accent)
                                }
                                .buttonStyle(.plain)
                                DashedDivider()
                            }
                        }
                    }

                    byLink
                }
                .padding(.top, Theme.spacingSM)
                .page()
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: zipCode) { _, value in
            let digits = String(value.filter(\.isNumber).prefix(5))
            if digits != value { zipCode = digits }
            if digits.count == 5 { Task { await search() } }
        }
    }

    private func search() async {
        guard zipCode.count == 5 else { return }
        isSearching = true
        error = nil
        do {
            stores = try await KrogerService.shared.stores(near: zipCode)
            if stores.isEmpty { error = "No Kroger stores near \(zipCode)." }
        } catch {
            self.error = error.localizedDescription
        }
        isSearching = false
    }

    /// The other way in: the store's page on kroger.com, which carries its ID.
    private var byLink: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Or paste your store's link")
            Text("On kroger.com, open your store's page and copy its address.")
                .font(.setting(13))
                .foregroundColor(Theme.ink2)
            HStack(alignment: .bottom, spacing: Theme.spacingSM) {
                FieldLine(label: "Store page or ID", text: $storeLink, prompt: "kroger.com/stores/…")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit { Task { await useLink() } }
                MarginButton("Use") { Task { await useLink() } }
                    .disabled(storeLink.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.bottom, 10)
            }
            if let linkError {
                Text(linkError).font(.setting(13)).foregroundColor(Theme.error)
            }
        }
        .padding(.top, Theme.spacingSM)
    }

    private func useLink() async {
        guard let store = KrogerStoreLink.parse(storeLink) else {
            linkError = "That doesn't look like a Kroger store page. It should end in two numbers, like …/014/00943."
            return
        }
        linkError = nil
        await choose(KrogerStore(id: store.id, name: store.name, chain: "KROGER", address: ""))
    }

    private func choose(_ store: KrogerStore) async {
        do {
            try await UserService.shared.setKrogerStore(id: store.id, name: store.name)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - The shelves

/// One line at Kroger: what you've picked for it, and the shelves to pick
/// something else — or, for a new line, the shelves to add from.
struct KrogerShelf: View {
    enum Mode: Identifiable {
        /// A line already on the list.
        case line(ShoppingItem)
        /// Something typed into "Add anything" — what you pick is added as a new line.
        case newLine(String)

        var id: String {
            switch self {
            case .line(let item): return item.id
            case .newLine(let text): return "new:" + text
            }
        }
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = ShoppingListService.shared
    @State private var term = ""
    @State private var products: [KrogerProduct] = []
    @State private var isSearching = false
    @State private var error: String?

    /// The line as it stands now — re-read from the list so a new pick shows at once.
    private var item: ShoppingItem? {
        guard case .line(let original) = mode else { return nil }
        return service.list?.items.first { $0.id == original.id } ?? original
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    header

                    if let item, item.isMatchedAtKroger {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHead(title: "Your pick")
                            NavigationLink(value: item.chosenProduct) {
                                productLine(item.chosenProduct, chosen: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        SectionHead(title: item?.isMatchedAtKroger == true ? "Something else" : "On the shelves")
                        SearchLine(placeholder: "Search the shelves", text: $term)
                            .onSubmit { Task { await search() } }
                    }

                    results

                    if let item, item.isMatchedAtKroger {
                        Button("No Kroger product for this") {
                            Task {
                                await service.choose(nil, for: item)
                                dismiss()
                            }
                        }
                        .buttonStyle(.pressOutline)
                    }
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Close") { dismiss() }
                }
            }
            .navigationDestination(for: KrogerProduct.self) { product in
                KrogerProductPage(
                    product: product,
                    isChosen: product.productId == item?.krogerProductId,
                    actionTitle: {
                        if case .newLine = mode { return "Add to the list" }
                        return "Choose this"
                    }(),
                    onChoose: { await pick(product) }
                )
            }
        }
        .task { await begin() }
    }

    // MARK: Pieces

    @ViewBuilder
    private var header: some View {
        let store = UserService.shared.currentUser?.krogerStoreName ?? "Kroger"
        switch mode {
        case .newLine(let text):
            PlateHeader(title: text.capitalized, subtitle: "Add from \(store)")
        case .line:
            if let item {
                PlateHeader(
                    title: item.shoppingName.capitalized,
                    subtitle: [item.printedAmount.isEmpty ? nil : item.printedAmount, "at \(store)"]
                        .compactMap { $0 }.joined(separator: " · ")
                )
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if isSearching {
            ProgressView().tint(Theme.ink3).frame(maxWidth: .infinity)
        }
        if let error {
            Text(error).font(.setting(13)).foregroundColor(Theme.error)
        }
        VStack(alignment: .leading, spacing: 0) {
            // What's already picked is shown above, not again in the results.
            ForEach(products.filter { $0.productId != item?.krogerProductId }) { product in
                NavigationLink(value: product) {
                    productLine(product, chosen: false)
                }
                .buttonStyle(.plain)
                DashedDivider()
            }
        }
    }

    private func productLine(_ product: KrogerProduct, chosen: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PhotoPlate(url: product.imageURL, height: 56, placeholder: "")
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.setting(15, chosen ? .semibold : .regular))
                    .foregroundColor(Theme.ink)
                    .lineLimit(2)
                Text([product.size, product.aisle?.label].compactMap { $0 }.joined(separator: " · "))
                    .font(.setting(12))
                    .foregroundColor(Theme.ink3)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if let price = product.price {
                    Text(price.formatted(.currency(code: "USD")))
                        .font(.figure(13, .semibold))
                        .foregroundColor(chosen ? Theme.accent : Theme.ink)
                }
                if product.isOnSale {
                    Text("Sale".uppercased())
                        .smallCaps(8, weight: .bold, tracking: 1.0)
                        .foregroundColor(Theme.accent)
                }
                if !product.inStock {
                    Text("Out".uppercased())
                        .smallCaps(8, weight: .bold, tracking: 1.0)
                        .foregroundColor(Theme.ink3)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.ink3)
                .padding(.top, 3)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: Actions

    private func begin() async {
        switch mode {
        case .newLine(let text): term = text
        case .line(let item): term = item.shoppingName
        }
        await search()
    }

    private func pick(_ product: KrogerProduct) async {
        switch mode {
        case .newLine(let text):
            if let user = UserService.shared.currentUser {
                await service.addByHand(text, product: product, author: user)
            }
        case .line:
            if let item { await service.choose(product, for: item) }
        }
        dismiss()
    }

    private func search() async {
        guard let locationId = UserService.shared.currentUser?.krogerLocationId else { return }
        let query = term.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else {
            products = []
            return
        }
        isSearching = true
        error = nil
        do {
            products = try await KrogerService.shared.search(query, at: locationId)
            if products.isEmpty { error = "Nothing on the shelves for \"\(query)\"." }
        } catch {
            self.error = error.localizedDescription
        }
        isSearching = false
    }
}

// MARK: - A product's own page

/// One Kroger product, set large before you choose it: its photographs,
/// what it costs, where it sits in the store, and the button that makes it
/// this line's pick.
struct KrogerProductPage: View {
    let product: KrogerProduct
    var isChosen: Bool = false
    var actionTitle: String = "Choose this"
    let onChoose: () async -> Void

    @State private var isChoosing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                photographs

                VStack(alignment: .leading, spacing: 0) {
                    DoubleRule()
                        .padding(.bottom, 10)
                    Text(product.name)
                        .font(.plate(26))
                        .foregroundColor(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand.uppercased())
                            .smallCaps(10, weight: .medium, tracking: 1.4)
                            .foregroundColor(Theme.ink2)
                            .padding(.top, 6)
                    }
                }

                price

                VStack(alignment: .leading, spacing: 0) {
                    if let size = product.size {
                        IndexEntry(title: "Size", figure: size, figureColor: Theme.ink)
                        DashedDivider()
                    }
                    if let aisle = product.aisle {
                        IndexEntry(title: "Aisle", figure: aisle.label, figureColor: Theme.ink)
                        DashedDivider()
                    }
                    if let spot = product.shelfLocation {
                        IndexEntry(title: "On the aisle", figure: spot, figureColor: Theme.ink)
                        DashedDivider()
                    }
                    IndexEntry(
                        title: "At this store",
                        figure: product.inStock ? "In stock" : "Out of stock",
                        figureColor: product.inStock ? Theme.herb : Theme.ink3
                    )
                    if let category = product.categories.first {
                        DashedDivider()
                        IndexEntry(title: "Kind", figure: category, figureColor: Theme.ink)
                    }
                }
                .plate()

                if isChosen {
                    Button("Your pick") {}
                        .buttonStyle(.pressOutline)
                        .disabled(true)
                } else {
                    Button {
                        isChoosing = true
                        Task {
                            await onChoose()
                            isChoosing = false
                        }
                    } label: {
                        if isChoosing {
                            ProgressView().tint(Theme.paper)
                        } else {
                            Text(actionTitle)
                        }
                    }
                    .buttonStyle(.press)
                    .disabled(isChoosing)
                }
            }
            .padding(.top, Theme.spacingSM)
            .padding(.bottom, Theme.spacingXL)
            .page()
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .backLeaf()
    }

    /// Every photograph Kroger has, swiped through; one plate when there's only one.
    @ViewBuilder
    private var photographs: some View {
        let urls = product.largeImageURLs.isEmpty ? [product.imageURL].compactMap { $0 } : product.largeImageURLs
        if urls.count > 1 {
            TabView {
                ForEach(urls, id: \.self) { url in
                    PhotoPlate(url: url, height: 300, fit: true)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 300)
        } else {
            PhotoPlate(url: urls.first, height: 300, placeholder: "No photograph", fit: true)
        }
    }

    /// Today's price large; on sale, the regular price struck through beside it.
    private var price: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
            if let price = product.price {
                Text(price.formatted(.currency(code: "USD")))
                    .font(.figure(28, .semibold))
                    .foregroundColor(Theme.accent)
                if product.isOnSale, let regular = product.regularPrice {
                    Text("Sale".uppercased())
                        .smallCaps(10, weight: .bold, tracking: 1.2)
                        .foregroundColor(Theme.accent)
                    Text(regular.formatted(.currency(code: "USD")))
                        .font(.figure(14, .medium))
                        .foregroundColor(Theme.ink3)
                        .strikethrough(true, color: Theme.ink3)
                }
            } else {
                Text("Not priced at this store")
                    .font(.setting(15).italic())
                    .foregroundColor(Theme.ink3)
            }
        }
    }
}

#Preview {
    ShoppingListView()
}
