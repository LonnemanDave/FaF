import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.foodandfriends.app"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let recipes = Logger(subsystem: subsystem, category: "recipes")
    static let mealPlans = Logger(subsystem: subsystem, category: "mealPlans")
    static let friends = Logger(subsystem: subsystem, category: "friends")
    static let feed = Logger(subsystem: subsystem, category: "feed")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
