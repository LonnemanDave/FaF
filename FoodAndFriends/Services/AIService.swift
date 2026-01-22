import Foundation

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case rateLimited
    case decodingError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your Claude API key in Settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .rateLimited:
            return "Rate limited. Please try again in a moment."
        case .decodingError:
            return "Failed to parse AI response. Please try again."
        case .invalidResponse:
            return "Invalid response from AI. Please try again."
        }
    }
}

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let modelId = "claude-3-haiku-20240307"
    private let apiVersion = "2023-06-01"

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasValidAPIKey = false

    private init() {
        hasValidAPIKey = KeychainManager.shared.hasAPIKey()
    }

    // MARK: - API Key Management

    func validateAndStoreAPIKey(_ apiKey: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Test the API key with a simple request
        let testMessage = ClaudeMessage(role: "user", content: "Say 'ok' and nothing else.")
        let request = ClaudeRequest(model: modelId, maxTokens: 10, messages: [testMessage])

        do {
            _ = try await makeRequest(request, apiKey: apiKey)
            try KeychainManager.shared.storeAPIKey(apiKey)
            hasValidAPIKey = true
        } catch {
            hasValidAPIKey = false
            throw error
        }
    }

    func removeAPIKey() {
        try? KeychainManager.shared.deleteAPIKey()
        hasValidAPIKey = false
    }

    func refreshAPIKeyStatus() {
        hasValidAPIKey = KeychainManager.shared.hasAPIKey()
    }

    // MARK: - Recipe Generation

    func generateRecipe(
        name: String,
        servings: Int? = nil,
        dietaryRestrictions: [DietaryRestriction] = []
    ) async throws -> GeneratedRecipe {
        guard let apiKey = KeychainManager.shared.retrieveAPIKey() else {
            throw AIServiceError.noAPIKey
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var prompt = """
        Generate a recipe for: \(name)

        """

        if let servings = servings {
            prompt += "Servings: \(servings)\n"
        }

        if !dietaryRestrictions.isEmpty {
            let restrictions = dietaryRestrictions.map { $0.displayName }.joined(separator: ", ")
            prompt += "Dietary restrictions: \(restrictions)\n"
        }

        prompt += """

        Return ONLY a valid JSON object with this exact structure (no markdown, no code blocks, just JSON):
        {
          "title": "Recipe Name",
          "description": "A brief appetizing description of the dish",
          "servings": 4,
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [
            {"name": "ingredient name", "quantity": "2", "unit": "cups"}
          ],
          "steps": [
            {"instruction": "Detailed step instruction", "ingredientNames": ["ingredient name used in this step"]}
          ],
          "tags": ["dinner", "easy", "healthy"]
        }

        Important:
        - ingredientNames in each step should reference exact ingredient names from the ingredients array
        - Include all ingredients needed for the recipe
        - Make steps detailed and clear
        - Tags should be relevant and lowercase
        """

        let message = ClaudeMessage(role: "user", content: prompt)
        let request = ClaudeRequest(model: modelId, maxTokens: 2000, messages: [message])

        let response = try await makeRequest(request, apiKey: apiKey)
        return try parseRecipeResponse(response)
    }

    // MARK: - Meal Plan Generation

    func generateMealPlan(
        preferences: MealPlanPreferences,
        startDate: Date,
        endDate: Date,
        specialRequests: String? = nil
    ) async throws -> GeneratedMealPlan {
        guard let apiKey = KeychainManager.shared.retrieveAPIKey() else {
            throw AIServiceError.noAPIKey
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)

        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let dayCount = days + 1

        var prompt = """
        Create a \(dayCount)-day meal plan from \(startDateStr) to \(endDateStr).

        Preferences:
        """

        if !preferences.dietaryRestrictions.isEmpty {
            let restrictions = preferences.dietaryRestrictions.map { $0.displayName }.joined(separator: ", ")
            prompt += "\n- Dietary restrictions: \(restrictions)"
        }

        if !preferences.cuisinePreferences.isEmpty {
            prompt += "\n- Cuisine preferences: \(preferences.cuisinePreferences.joined(separator: ", "))"
        }

        if let calorieGoal = preferences.calorieGoal {
            prompt += "\n- Calorie goal: \(calorieGoal.displayName)"
        }

        if !preferences.allergens.isEmpty {
            prompt += "\n- Allergens to AVOID: \(preferences.allergens.joined(separator: ", "))"
        }

        prompt += "\n- Cooking skill level: \(preferences.cookingSkillLevel.displayName)"

        let mealTypeNames = preferences.mealTypes.map { $0.displayName.lowercased() }
        prompt += "\n- Meals to plan: \(mealTypeNames.joined(separator: ", "))"

        if preferences.quickMealsPreferred {
            prompt += "\n- Prefer quick meals (under 30 minutes)"
        }

        if let specialRequests = specialRequests, !specialRequests.isEmpty {
            prompt += "\n\nSpecial requests from user:\n\(specialRequests)"
        }

        prompt += """


        Return ONLY a valid JSON object with this exact structure (no markdown, no code blocks, just JSON):
        {
          "name": "Descriptive plan name",
          "description": "Brief description of the meal plan theme",
          "meals": [
            {
              "date": "2024-01-15",
              "mealType": "breakfast",
              "recipeName": "Specific recipe name",
              "notes": "Optional brief note"
            }
          ]
        }

        Important:
        - Include one entry per meal type per day
        - mealType must be one of: breakfast, lunch, dinner, snack
        - Use real, specific recipe names (not generic like "healthy breakfast")
        - Dates must be in YYYY-MM-DD format
        - Ensure variety across days
        """

        let message = ClaudeMessage(role: "user", content: prompt)
        let request = ClaudeRequest(model: modelId, maxTokens: 4000, messages: [message])

        let response = try await makeRequest(request, apiKey: apiKey)
        return try parseMealPlanResponse(response)
    }

    // MARK: - Private Methods

    private func makeRequest(_ request: ClaudeRequest, apiKey: String) async throws -> ClaudeResponse {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(ClaudeResponse.self, from: data)
            } catch {
                throw AIServiceError.decodingError(error)
            }

        case 401:
            throw AIServiceError.invalidAPIKey

        case 429:
            throw AIServiceError.rateLimited

        default:
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw AIServiceError.apiError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.error.message
                )
            }
            throw AIServiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: "Unknown error"
            )
        }
    }

    private func parseRecipeResponse(_ response: ClaudeResponse) throws -> GeneratedRecipe {
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw AIServiceError.invalidResponse
        }

        // Clean up the response - remove any markdown code blocks if present
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonText.hasPrefix("```json") {
            jsonText = String(jsonText.dropFirst(7))
        } else if jsonText.hasPrefix("```") {
            jsonText = String(jsonText.dropFirst(3))
        }
        if jsonText.hasSuffix("```") {
            jsonText = String(jsonText.dropLast(3))
        }
        jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(GeneratedRecipe.self, from: jsonData)
        } catch {
            throw AIServiceError.decodingError(error)
        }
    }

    private func parseMealPlanResponse(_ response: ClaudeResponse) throws -> GeneratedMealPlan {
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw AIServiceError.invalidResponse
        }

        // Clean up the response
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonText.hasPrefix("```json") {
            jsonText = String(jsonText.dropFirst(7))
        } else if jsonText.hasPrefix("```") {
            jsonText = String(jsonText.dropFirst(3))
        }
        if jsonText.hasSuffix("```") {
            jsonText = String(jsonText.dropLast(3))
        }
        jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(GeneratedMealPlan.self, from: jsonData)
        } catch {
            throw AIServiceError.decodingError(error)
        }
    }
}

// MARK: - Recipe Conversion Helpers

extension AIService {
    /// Convert a GeneratedRecipe to the app's Recipe model
    func convertToRecipe(_ generated: GeneratedRecipe, authorId: String) -> Recipe {
        // Create ingredients with IDs
        let ingredients = generated.ingredients.map { gen in
            Ingredient(name: gen.name, quantity: gen.quantity, unit: gen.unit)
        }

        // Create steps with ingredient references
        let steps = generated.steps.enumerated().map { index, gen in
            // Find ingredient IDs that match the names in this step
            let ingredientIds = gen.ingredientNames.compactMap { name -> String? in
                ingredients.first { $0.name.lowercased() == name.lowercased() }?.id
            }
            return RecipeStep(
                instruction: gen.instruction,
                ingredientIds: ingredientIds,
                orderIndex: index
            )
        }

        return Recipe(
            authorId: authorId,
            title: generated.title,
            description: generated.description,
            ingredients: ingredients,
            steps: steps,
            isPublic: false,
            servings: generated.servings,
            prepTimeMinutes: generated.prepTimeMinutes,
            cookTimeMinutes: generated.cookTimeMinutes,
            tags: generated.tags
        )
    }
}
