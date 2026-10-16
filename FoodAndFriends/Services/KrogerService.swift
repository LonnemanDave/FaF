import Foundation
import FirebaseFunctions

// MARK: - What Kroger sends back

struct KrogerStore: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let chain: String
    let address: String
}

struct KrogerAisle: Codable, Hashable {
    /// As the store signs it: "Aisle 12", "Meat", "Produce".
    let label: String
    let number: Int?
}

struct KrogerProduct: Codable, Identifiable, Hashable {
    let productId: String
    let name: String
    let brand: String?
    let size: String?
    /// Today's price, sale price when there is one. Nil when this store doesn't price it.
    let price: Double?
    let regularPrice: Double?
    let aisle: KrogerAisle?
    let imageURL: String?
    let inStock: Bool
    /// Every photo Kroger has, largest size, the featured one first — for the product's own page.
    var largeImageURLs: [String] = []
    var categories: [String] = []
    /// Where on the aisle: "Left side · shelf 3 · bay 13".
    var shelfLocation: String?

    var id: String { productId }
    var isOnSale: Bool {
        guard let price, let regularPrice else { return false }
        return price < regularPrice
    }
}

/// The Kroger connection.
///
/// Kroger's firewall turns away product and store requests from Google
/// Cloud's network, so the app calls Kroger itself, from the phone. What it
/// can't hold is the client secret — so it asks its own Cloud Function for
/// a short-lived access token (about half an hour, one kind of request) and
/// uses that. Every token request needs a signed-in user.
@MainActor
final class KrogerService {
    static let shared = KrogerService()

    enum API: String { case products, locations }

    private lazy var functions = Functions.functions(region: "us-central1")
    private var tokens: [API: (token: String, apiBase: String, expiresAt: Date)] = [:]

    private init() {}

    // MARK: Calls

    /// Kroger stores near a five-digit ZIP code.
    func stores(near zipCode: String) async throws -> [KrogerStore] {
        #if DEBUG
        if DesignHarness.isOn { return DesignHarness.krogerStores }
        #endif
        let json: KrogerReading.Envelope<KrogerReading.RawLocation> = try await get(
            .locations, "/locations",
            ["filter.zipCode.near": zipCode, "filter.limit": "10"]
        )
        return (json.data ?? []).compactMap(KrogerReading.store)
    }

    /// Products on a store's shelves for a search.
    func search(_ term: String, at locationId: String, limit: Int = 12) async throws -> [KrogerProduct] {
        #if DEBUG
        if DesignHarness.isOn { return DesignHarness.krogerProducts(for: term) }
        #endif
        let query = term.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else { return [] }
        let json: KrogerReading.Envelope<KrogerReading.RawProduct> = try await get(
            .products, "/products",
            ["filter.term": String(query.prefix(80)), "filter.locationId": locationId, "filter.limit": String(limit)]
        )
        return (json.data ?? []).compactMap(KrogerReading.product)
    }

    /// The likeliest product for each line, keyed by line ID — a few
    /// searches at a time. Lines Kroger couldn't place are left out.
    func match(_ items: [ShoppingItem], at locationId: String) async throws -> [String: KrogerProduct] {
        guard !items.isEmpty else { return [:] }
        #if DEBUG
        if DesignHarness.isOn {
            return Dictionary(uniqueKeysWithValues: items.compactMap { item in
                DesignHarness.krogerProducts(for: item.shoppingName).first.map { (item.id, $0) }
            })
        }
        #endif
        // Fetch the token once up front, so a refusal surfaces as an error rather than a page of misses.
        _ = try await token(for: .products)

        var found: [String: KrogerProduct] = [:]
        for start in stride(from: 0, to: items.count, by: 4) {
            let batch = Array(items[start..<min(start + 4, items.count)])
            let results = await withTaskGroup(of: (String, KrogerProduct?).self) { group in
                for item in batch {
                    group.addTask {
                        let term = KrogerReading.searchTerm(item.shoppingName)
                        let products = (try? await self.search(term, at: locationId, limit: 8)) ?? []
                        return (item.id, KrogerReading.bestMatch(products))
                    }
                }
                var collected: [(String, KrogerProduct?)] = []
                for await result in group { collected.append(result) }
                return collected
            }
            for (id, product) in results {
                if let product { found[id] = product }
            }
        }
        return found
    }

    // MARK: Talking to Kroger

    private struct TokenRequest: Encodable { let api: String }
    private struct TokenReply: Decodable { let accessToken: String; let expiresIn: Int; let apiBase: String }

    /// A token for one kind of request, reused until a minute before it lapses.
    private func token(for api: API) async throws -> (token: String, apiBase: String) {
        if let cached = tokens[api], cached.expiresAt > Date().addingTimeInterval(60) {
            return (cached.token, cached.apiBase)
        }
        let call = functions.httpsCallable("krogerToken", requestAs: TokenRequest.self, responseAs: TokenReply.self)
        let reply = try await call.call(TokenRequest(api: api.rawValue))
        tokens[api] = (reply.accessToken, reply.apiBase, Date().addingTimeInterval(TimeInterval(reply.expiresIn)))
        return (reply.accessToken, reply.apiBase)
    }

    /// A GET to Kroger with a fresh-enough token; one retry with a new token if Kroger says it's stale.
    private func get<T: Decodable>(_ api: API, _ path: String, _ params: [String: String]) async throws -> T {
        for attempt in 0..<2 {
            let (token, apiBase) = try await token(for: api)
            var components = URLComponents(string: apiBase + path)
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = components?.url else { throw KrogerServiceError.badRequest }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401, attempt == 0 {
                tokens[api] = nil // stale — sign in again and retry once
                continue
            }
            guard (200..<300).contains(status) else { throw KrogerServiceError.refused(status: status, api: api) }
            return try JSONDecoder().decode(T.self, from: data)
        }
        throw KrogerServiceError.refused(status: 401, api: api)
    }
}

enum KrogerServiceError: LocalizedError {
    case badRequest
    case refused(status: Int, api: KrogerService.API)

    var errorDescription: String? {
        switch self {
        case .badRequest:
            return "Couldn't build that Kroger search."
        case .refused(let status, let api) where status == 401 || status == 403:
            return "Kroger turned down the \(api == .locations ? "store" : "product") search (\(status)). Check that the app has the \(api == .locations ? "Locations" : "Products") API at developer.kroger.com."
        case .refused(let status, _):
            return "Kroger isn't answering right now (\(status)). Try again in a minute."
        }
    }
}

// MARK: - Reading Kroger's replies

/// Pure functions over Kroger's JSON: what to search for, which result a
/// line means, and how prices, aisles and stores read. Kept apart from the
/// network so they can be tested.
enum KrogerReading {

    struct Envelope<T: Decodable>: Decodable { let data: [T]? }

    struct RawProduct: Decodable {
        struct Aisle: Decodable {
            let description: String?
            let number: String?
            let side: String?
            let shelfNumber: String?
            let bayNumber: String?
        }
        struct Image: Decodable {
            struct Size: Decodable { let size: String?; let url: String? }
            let perspective: String?
            let featured: Bool?
            let sizes: [Size]?
        }
        struct Item: Decodable {
            struct Price: Decodable { let regular: Double?; let promo: Double? }
            struct Inventory: Decodable { let stockLevel: String? }
            let size: String?
            let price: Price?
            let inventory: Inventory?
        }
        let productId: String?
        let description: String?
        let brand: String?
        let categories: [String]?
        let aisleLocations: [Aisle]?
        let images: [Image]?
        let items: [Item]?
    }

    struct RawLocation: Decodable {
        struct Address: Decodable { let addressLine1: String?; let city: String?; let state: String?; let zipCode: String? }
        let locationId: String?
        let name: String?
        let chain: String?
        let address: Address?
    }

    /// What to type into Kroger's search for a line: "bacon or pancetta" → "bacon",
    /// "fresh thyme (or 1 tsp dried)" → "fresh thyme".
    static func searchTerm(_ name: String) -> String {
        var term = name.lowercased()
        while let open = term.firstIndex(of: "("), let close = term[open...].firstIndex(of: ")") {
            term.replaceSubrange(open...close, with: " ")
        }
        term = term.components(separatedBy: ",")[0]
        term = term.components(separatedBy: " or ")[0]
        let allowed = term.map { $0.isLetter || $0.isNumber || " &'-".contains($0) ? $0 : " " }
        return String(allowed).split(separator: " ").prefix(6).joined(separator: " ")
    }

    /// "AISLE 12" → Aisle 12 (12); "MEAT" → Meat.
    static func aisle(description: String?, number: String?) -> KrogerAisle? {
        guard let description = description?.trimmingCharacters(in: .whitespaces), !description.isEmpty else { return nil }
        let label = description.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        let parsed = number.flatMap { Int($0) } ?? Int(description.filter(\.isNumber))
        return KrogerAisle(label: label, number: parsed)
    }

    static func product(_ raw: RawProduct) -> KrogerProduct? {
        guard let id = raw.productId, let name = raw.description else { return nil }
        let item = raw.items?.first
        let regular = item?.price?.regular.flatMap { $0 > 0 ? $0 : nil }
        let promo = item?.price?.promo.flatMap { $0 > 0 ? $0 : nil }
        let image = raw.images?.first { $0.featured == true } ?? raw.images?.first { $0.perspective == "front" } ?? raw.images?.first
        let sizes = image?.sizes ?? []
        let url = ["medium", "small", "thumbnail", "large", "xlarge"]
            .lazy.compactMap { wanted in sizes.first { $0.size == wanted }?.url }.first ?? sizes.first?.url
        let ordered = (raw.images ?? []).sorted { ($0.featured == true ? 0 : 1) < ($1.featured == true ? 0 : 1) }
        let large = ordered.compactMap { image in
            ["xlarge", "large", "medium"].lazy.compactMap { wanted in image.sizes?.first { $0.size == wanted }?.url }.first
        }
        let place = raw.aisleLocations?.first
        return KrogerProduct(
            productId: id, name: name, brand: raw.brand, size: item?.size,
            price: promo ?? regular, regularPrice: regular,
            aisle: aisle(description: place?.description, number: place?.number),
            imageURL: url,
            inStock: item?.inventory?.stockLevel != "TEMPORARILY_OUT_OF_STOCK",
            largeImageURLs: large,
            categories: raw.categories ?? [],
            shelfLocation: shelfLocation(side: place?.side, shelf: place?.shelfNumber, bay: place?.bayNumber)
        )
    }

    /// "L", "3", "13" → "Left side · shelf 3 · bay 13". Nil when Kroger says nothing.
    static func shelfLocation(side: String?, shelf: String?, bay: String?) -> String? {
        var parts: [String] = []
        switch side?.uppercased() {
        case "L": parts.append("Left side")
        case "R": parts.append("Right side")
        default: break
        }
        if let shelf, !shelf.isEmpty { parts.append("shelf \(shelf)") }
        if let bay, !bay.isEmpty { parts.append("bay \(bay)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Among Kroger's first few, the one this store prices and has on the shelf.
    static func bestMatch(_ products: [KrogerProduct]) -> KrogerProduct? {
        let top = products.prefix(5)
        return top.first { $0.price != nil && $0.inStock } ?? top.first { $0.price != nil } ?? top.first
    }

    static func store(_ raw: RawLocation) -> KrogerStore? {
        guard let id = raw.locationId else { return nil }
        let a = raw.address
        let stateZip = [a?.state, a?.zipCode].compactMap { $0 }.joined(separator: " ")
        let address = [a?.addressLine1, a?.city, stateZip.isEmpty ? nil : stateZip].compactMap { $0 }.joined(separator: ", ")
        return KrogerStore(id: id, name: raw.name ?? "Kroger", chain: raw.chain ?? "KROGER", address: address)
    }
}

// MARK: - A list line's Kroger product

extension ShoppingItem {
    /// Files a Kroger product against this line, in the fields the earlier
    /// version of the app wrote. Nil takes the product off.
    mutating func setKrogerProduct(_ product: KrogerProduct?) {
        krogerProductId = product?.productId
        krogerProductName = product?.name
        krogerProductAisle = product?.aisle?.label
        krogerProductSize = product?.size
        krogerProductPrice = product?.price
        krogerProductImageURL = product?.imageURL
        krogerProductQuantity = product == nil ? nil : (krogerProductQuantity ?? 1)
    }

    var isMatchedAtKroger: Bool { krogerProductId != nil }

    /// The product chosen for this line, rebuilt from what's stored on it.
    var chosenProduct: KrogerProduct {
        KrogerProduct(
            productId: krogerProductId ?? "",
            name: krogerProductName ?? shoppingName,
            brand: nil,
            size: krogerProductSize,
            price: krogerProductPrice,
            regularPrice: nil,
            aisle: krogerProductAisle.map { label in
                KrogerAisle(label: label, number: Int(label.filter(\.isNumber)))
            },
            imageURL: krogerProductImageURL,
            inStock: true
        )
    }

    /// What this line should cost at Kroger — price × packages.
    var krogerCost: Double? {
        krogerProductPrice.map { $0 * Double(krogerProductQuantity ?? 1) }
    }
}

// MARK: - A store from its kroger.com link

/// Reads a Kroger store out of what's pasted: its page on kroger.com (or a
/// sister banner's site), or the bare store ID. A store's ID is its
/// three-digit division and five-digit store number run together —
/// `…/hyde-park/014/00943` is `01400943` — which is all the Products API
/// needs, so a store can be chosen without the Locations API.
enum KrogerStoreLink {
    static func parse(_ text: String) -> (id: String, name: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // A bare ID: "01400943", or with a separator, "014-00943".
        let digits = trimmed.filter(\.isNumber)
        if trimmed.allSatisfy({ $0.isNumber || $0 == "-" || $0 == " " || $0 == "/" }), digits.count == 8 {
            return (digits, "Kroger store \(digits)")
        }

        // A link: the division and store number are the last two numeric parts of the path.
        let path = URL(string: trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")?.path ?? trimmed
        let parts = path.split(separator: "/").map(String.init)
        guard let storeIndex = parts.lastIndex(where: { $0.count == 5 && $0.allSatisfy(\.isNumber) }),
              storeIndex > 0,
              parts[storeIndex - 1].count == 3, parts[storeIndex - 1].allSatisfy(\.isNumber)
        else { return nil }
        let id = parts[storeIndex - 1] + parts[storeIndex]

        // The part before the numbers names the store: "hyde-park" → "Kroger Hyde Park".
        let slugIndex = storeIndex - 2
        guard slugIndex >= 0, !["details", "grocery", "stores"].contains(parts[slugIndex]) else {
            return (id, "Kroger store \(id)")
        }
        let words = parts[slugIndex].split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }
        let name = words.joined(separator: " ")
        return (id, name.lowercased().contains("kroger") ? name : "Kroger \(name)")
    }
}
