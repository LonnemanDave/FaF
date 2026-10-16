import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var moderation = ModerationService.shared
    @State private var reportingVariation: ReportSubject?

    // Step photographs — keyed by step id, saved with the recipe's steps.
    @State private var stepPhotos: [String: [String]] = [:]
    @State private var photoStep: RecipeStep?
    @State private var pickerSource: PhotoSource?
    @State private var stepImage: UIImage?
    @State private var uploadingStepId: String?
    @State private var viewingPhoto: ViewedStepPhoto?
    @State private var showError = false
    @State private var errorMessage = ""

    private enum PhotoSource: String, Identifiable {
        case camera, library
        var id: String { rawValue }
    }

    private struct ViewedStepPhoto: Identifiable {
        let url: String
        let stepId: String
        let caption: String
        var id: String { url }
    }
    @ObservedObject var shoppingService = ShoppingListService.shared

    let recipe: Recipe

    @State private var showEditSheet = false
    @State private var showVariationSheet = false
    @State private var variations: [RecipeVariation] = []
    @State private var selectedVariation: RecipeVariation?
    @State private var isLoadingVariations = false

    // Photo upload state
    @State private var selectedImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var currentImageURL: String?
    @State private var showImagePicker = false

    // Variation editing
    @State private var showEditVariationSheet = false

    /// Ingredients crossed off on this page — at the store or at the counter.
    /// The reader's pencil, not the recipe's: not saved.
    @State private var struck: Set<String> = []
    /// "Added 12 to the list" — set after adding, cleared when the marks change.
    @State private var addedNote: String?

    private var isOwner: Bool {
        userService.currentUser?.id == recipe.authorId
    }

    private var isVariationOwner: Bool {
        guard let variation = selectedVariation,
              let userId = userService.currentUser?.id else { return false }
        return variation.authorId == userId
    }

    private var displayedImageURL: String? {
        // Show variation image if viewing a variation that has one, otherwise show recipe image
        if let variation = selectedVariation, let variationImage = variation.imageURL {
            return variationImage
        }
        return currentImageURL
    }

    private var showEditButton: Bool {
        (selectedVariation == nil && isOwner) || isVariationOwner
    }

    private func handleEditTap() {
        if selectedVariation == nil && isOwner {
            showEditSheet = true
        } else if isVariationOwner {
            showEditVariationSheet = true
        }
    }

    private var currentIngredients: [Ingredient] {
        selectedVariation?.ingredients ?? recipe.ingredients
    }

    private var currentSteps: [RecipeStep] {
        selectedVariation?.sortedSteps ?? recipe.sortedSteps
    }

    private func ingredientsForStep(_ step: RecipeStep) -> [Ingredient] {
        let allIngredients = currentIngredients
        return allIngredients.filter { step.ingredientIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                photo

                headerSection

                statsSection

                // Chef selector (only when friends have written variations)
                if !variations.isEmpty {
                    chefSelectorSection
                }

                // The chef's note, when reading a variation
                if let variation = selectedVariation, !variation.notes.isEmpty {
                    variationNotesSection(for: variation)
                }

                ingredientsSection

                instructionsSection

                if !recipe.tags.isEmpty {
                    tagsSection
                }

                // Non-owners who haven't written their own take yet
                if !isOwner && !hasUserVariation {
                    addVariationButton
                }
            }
            .padding(.top, Theme.spacingSM)
            .padding(.bottom, Theme.spacingXL)
            .page()
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .backLeaf()
        .plainToolbar {
            if showEditButton {
                ToolbarItem(placement: .topBarTrailing) {
                    MarginButton("Edit") { handleEditTap() }
                }
            }
            if !isOwner, let recipeId = recipe.id {
                ToolbarItem(placement: .topBarTrailing) {
                    ModerationMenu(
                        subject: ReportSubject(target: .recipe, targetId: recipeId, authorId: recipe.authorId,
                                               authorUsername: recipe.authorUsername, label: recipe.title),
                        onBlocked: { dismiss() }
                    )
                }
            }
        }
        .sheet(item: $reportingVariation) { subject in
            ReportSheet(subject: subject)
        }
        .sheet(isPresented: $showEditSheet) {
            CreateRecipeView(recipeToEdit: recipe, onDelete: {
                dismiss()
            })
        }
        .sheet(isPresented: $showVariationSheet) {
            CreateRecipeView(baseRecipeForVariation: recipe)
        }
        .sheet(isPresented: $showEditVariationSheet) {
            if let variation = selectedVariation {
                CreateRecipeView(
                    baseRecipeForVariation: recipe,
                    variationToEdit: variation,
                    onVariationUpdated: {
                        Task { await loadVariations() }
                    }
                )
            }
        }
        .task {
            await loadVariations()
            currentImageURL = recipe.firstImageURL
            stepPhotos = Dictionary(uniqueKeysWithValues: latestSteps.map { ($0.id, $0.photoURLs ?? []) })
        }
        .confirmationDialog(
            "A photo for this step",
            isPresented: Binding(get: { photoStep != nil && pickerSource == nil }, set: { if !$0 && pickerSource == nil { photoStep = nil } }),
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a photo") { pickerSource = .camera }
            }
            Button("Choose from library") { pickerSource = .library }
            Button("Cancel", role: .cancel) { photoStep = nil }
        }
        .fullScreenCover(item: $pickerSource) { source in
            ImagePickerView(selectedImage: $stepImage, source: source == .camera ? .camera : .photoLibrary)
                .ignoresSafeArea()
        }
        .onChange(of: stepImage) { _, image in
            guard let image, let step = photoStep else { return }
            stepImage = nil
            pickerSource = nil
            photoStep = nil
            Task { await addStepPhoto(image, to: step) }
        }
        .alert("Couldn't save the photo", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $viewingPhoto) { photo in
            StepPhotoViewer(
                url: photo.url,
                caption: photo.caption,
                onRemove: isOwner ? { Task { await removeStepPhoto(photo.url, from: photo.stepId) } } : nil
            )
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task {
                    await uploadRecipePhoto(image)
                    selectedImage = nil
                }
            }
        }
        .onChange(of: selectedVariation?.id) { _, _ in
            // A different chef's list — the pencil marks were for the other one.
            struck = []
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $selectedImage)
        }
    }

    private var hasUserVariation: Bool {
        guard let userId = userService.currentUser?.id else { return false }
        return variations.contains { $0.authorId == userId }
    }

    private func loadVariations() async {
        guard let recipeId = recipe.id else { return }
        isLoadingVariations = true
        do {
            let friendIds = friendService.friends.compactMap { $0.id }
            let allVariations = try await recipeService.fetchVariations(for: recipeId, friendIds: friendIds)
            // Filter out variations from the recipe owner (handles edge case after promotion)
            variations = allVariations.filter {
                $0.authorId != recipe.authorId && !moderation.isBlocked($0.authorId)
            }
        } catch {
            print("Error loading variations: \(error)")
        }
        isLoadingVariations = false
    }

    // MARK: - Chef Selector

    /// The original first, then each friend's version by its author.
    private var chefOptions: [(value: String?, label: String)] {
        var options: [(value: String?, label: String)] = [(value: nil, label: "Original")]
        for variation in variations {
            options.append((value: variation.id, label: "@" + (variation.authorUsername ?? "chef")))
        }
        return options
    }

    private var chefSelection: Binding<String?> {
        Binding(
            get: { selectedVariation?.id },
            set: { id in
                selectedVariation = id == nil ? nil : variations.first { $0.id == id }
            }
        )
    }

    /// Whose version is on the page — the original, or a friend's take on it.
    private var chefSelectorSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Whose version".uppercased())
                .smallCaps(10, weight: .semibold, tracking: 1.4)
                .foregroundColor(Theme.ink2)

            ScrollView(.horizontal, showsIndicators: false) {
                IndexSelector(options: chefOptions, selection: chefSelection)
                    .padding(.vertical, 2)
            }
            // The page's room for the thumb index is for vertical lists, not this row.
            .contentMargins(.bottom, 0, for: .scrollContent)
        }
    }

    /// A friend's note on their version, set as a marginal note: herb rule
    /// down the side, italic, their marks underneath.
    private func variationNotesSection(for variation: RecipeVariation) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("@\(variation.authorUsername ?? "chef")'s note".uppercased())
                .smallCaps(10, weight: .semibold, tracking: 1.4)
                .foregroundColor(Theme.herb)

            Text(variation.notes)
                .font(.setting(15).italic())
                .foregroundColor(Theme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.spacingLG) {
                Button {
                    Task { await likeVariation(variation) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 11, weight: .semibold))
                        Text(variation.likeCount > 0 ? "Like · \(variation.likeCount)" : "Like")
                            .textCase(.uppercase)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                    }
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)

                if variation.authorId != userService.currentUser?.id, let variationId = variation.id {
                    Button {
                        reportingVariation = ReportSubject(
                            target: .variation, targetId: variationId, authorId: variation.authorId,
                            authorUsername: variation.authorUsername,
                            label: "@\(variation.authorUsername ?? "chef")'s \(recipe.title)"
                        )
                    } label: {
                        Text("Report".uppercased())
                            .smallCaps(10, weight: .semibold, tracking: 1.2)
                            .foregroundColor(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                }

                if isOwner {
                    Button {
                        Task { await promoteVariation(variation) }
                    } label: {
                        Text("Make this the original".uppercased())
                            .smallCaps(10, weight: .semibold, tracking: 1.2)
                            .foregroundColor(Theme.herb)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(.leading, Theme.spacingMD)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.herb).frame(width: 2)
        }
    }

    private var addVariationButton: some View {
        Button("Write your own version") {
            showVariationSheet = true
        }
        .buttonStyle(.pressOutline)
        .padding(.top, Theme.spacingSM)
    }

    private func likeVariation(_ variation: RecipeVariation) async {
        guard let recipeId = recipe.id else { return }
        do {
            try await recipeService.likeVariation(variation, recipeId: recipeId)
            await loadVariations()
        } catch {
            print("Error liking variation: \(error)")
        }
    }

    private func promoteVariation(_ variation: RecipeVariation) async {
        guard let user = userService.currentUser else { return }
        do {
            try await recipeService.promoteVariation(variation, recipe: recipe, currentUser: user)
            dismiss()
        } catch {
            print("Error promoting variation: \(error)")
        }
    }

    // MARK: - Photograph

    /// The dish, pasted in. The cook can add or change it; everyone else
    /// just sees it — or no frame at all when there isn't one.
    @ViewBuilder
    private var photo: some View {
        if displayedImageURL != nil || showEditButton {
            PhotoPlate(url: displayedImageURL, height: 240, placeholder: "No photograph yet")
                .overlay {
                    if isUploadingPhoto {
                        ZStack {
                            Theme.paper.opacity(0.7)
                            ProgressView().tint(Theme.ink)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showEditButton && !isUploadingPhoto {
                        Button {
                            showImagePicker = true
                        } label: {
                            Text((displayedImageURL == nil ? "Add photograph" : "Change").uppercased())
                                .smallCaps(9, weight: .semibold, tracking: 1.2)
                                .foregroundColor(Theme.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Theme.paper)
                                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
        }
    }

    // MARK: - Upload Photo

    // MARK: - Step photos

    /// The steps as they are now — after any edit made since this page opened.
    private var latestSteps: [RecipeStep] {
        recipeService.userRecipes.first { $0.id == recipe.id }?.steps ?? recipe.steps
    }

    private func addStepPhoto(_ image: UIImage, to step: RecipeStep) async {
        guard let recipeId = recipe.id else { return }
        uploadingStepId = step.id
        defer { uploadingStepId = nil }
        do {
            // recipe_images/{recipeId}_… — account deletion sweeps that prefix.
            let filename = "\(recipeId)_step_\(step.id)_\(Int(Date().timeIntervalSince1970)).jpg"
            let url = try await StorageService.shared.uploadImage(
                image.resized(toMaxDimension: 1600), path: "recipe_images", filename: filename
            )
            stepPhotos[step.id, default: []].append(url)
            try await saveStepPhotos()
        } catch {
            errorMessage = "The photo didn't save — \(error.localizedDescription)"
            showError = true
        }
    }

    private func removeStepPhoto(_ url: String, from stepId: String) async {
        stepPhotos[stepId]?.removeAll { $0 == url }
        do {
            try await saveStepPhotos()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func saveStepPhotos() async throws {
        guard let recipeId = recipe.id else { return }
        let steps = latestSteps.map { step -> RecipeStep in
            var step = step
            let photos = stepPhotos[step.id] ?? []
            step.photoURLs = photos.isEmpty ? nil : photos
            return step
        }
        try await recipeService.updateSteps(steps, recipeId: recipeId)
    }

    private func uploadRecipePhoto(_ image: UIImage) async {
        guard let recipeId = recipe.id else { return }

        isUploadingPhoto = true

        do {
            let resizedImage = image.resized(toMaxDimension: 1200)

            if let variation = selectedVariation {
                // Upload for variation
                guard let variationId = variation.id else { return }
                let filename = "variation_\(variationId)_\(Date().timeIntervalSince1970).jpg"
                let imageURL = try await StorageService.shared.uploadImage(
                    resizedImage,
                    path: "recipe_images",
                    filename: filename
                )

                // Update the variation with the new image URL
                var updatedVariation = variation
                updatedVariation.imageURL = imageURL
                try await recipeService.updateVariation(updatedVariation, recipeId: recipeId)

                // Update local state
                if let index = variations.firstIndex(where: { $0.id == variationId }) {
                    variations[index].imageURL = imageURL
                }
                selectedVariation?.imageURL = imageURL
            } else {
                // Upload for original recipe
                let filename = "\(recipeId)_\(Date().timeIntervalSince1970).jpg"
                let imageURL = try await StorageService.shared.uploadImage(
                    resizedImage,
                    path: "recipe_images",
                    filename: filename
                )

                // Update the recipe with the new image URL
                var updatedRecipe = recipe
                updatedRecipe.imageURLs = [imageURL]
                try await recipeService.updateRecipe(updatedRecipe)

                // Update local state
                currentImageURL = imageURL
            }

            recipeService.needsRefresh = true
        } catch {
            print("Error uploading photo: \(error)")
        }

        isUploadingPhoto = false
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 10)

            Text(recipe.title)
                .font(.plate(30))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let authorUsername = recipe.authorUsername {
                Text("From the kitchen of @\(authorUsername)".uppercased())
                    .smallCaps(10, weight: .medium, tracking: 1.4)
                    .foregroundColor(Theme.ink2)
                    .padding(.top, 6)
            }

            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.setting(15).italic())
                    .foregroundColor(Theme.ink2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        let items: [(label: String, value: String)] = [
            recipe.prepTimeMinutes.map { (label: "Prep", value: $0.printedMinutes) },
            recipe.cookTimeMinutes.map { (label: "Cook", value: $0.printedMinutes) },
            recipe.servings.map { (label: "Serves", value: "\($0)") },
        ].compactMap { $0 }
        if !items.isEmpty {
            Figures(items: items)
        }
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(
                title: "Ingredients",
                figure: struck.isEmpty
                    ? "\(currentIngredients.count)"
                    : "\(struck.count) of \(currentIngredients.count) crossed off"
            )
            .padding(.bottom, 4)

            ForEach(currentIngredients) { ingredient in
                IngredientLine(ingredient, struck: struck.contains(ingredient.id))
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.12)) {
                            if struck.contains(ingredient.id) {
                                struck.remove(ingredient.id)
                            } else {
                                struck.insert(ingredient.id)
                            }
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Crosses the ingredient off")
            }

            addToListButton
                .padding(.top, Theme.spacingMD)

            HStack {
                Text(struck.isEmpty ? "Cross off what you already have" : "")
                    .font(.setting(11).italic())
                    .foregroundColor(Theme.ink3)
                Spacer()
                if !struck.isEmpty {
                    MarginButton("Clear marks") {
                        withAnimation { struck.removeAll() }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    /// Puts what's still needed on the shopping list — every ingredient, or
    /// only the ones not crossed off as already in the cupboard.
    @ViewBuilder
    private var addToListButton: some View {
        let needed = currentIngredients.filter { !struck.contains($0.id) }
        VStack(alignment: .leading, spacing: 6) {
            Button {
                guard let user = userService.currentUser else { return }
                Task {
                    let count = await shoppingService.add(needed, from: recipe, author: user)
                    addedNote = shoppingService.lastError ?? "Added \(count) to the list"
                }
            } label: {
                Text(struck.isEmpty ? "Add to the list" : "Add the other \(needed.count) to the list")
            }
            .buttonStyle(.pressOutline)
            .disabled(needed.isEmpty || userService.currentUser == nil)

            if let addedNote {
                Text(addedNote.uppercased())
                    .smallCaps(9, weight: .semibold, tracking: 1.3)
                    .foregroundColor(shoppingService.lastError == nil ? Theme.herb : Theme.error)
            } else if shoppingService.contains(recipe) {
                HStack {
                    Text("On your shopping list".uppercased())
                        .smallCaps(9, weight: .semibold, tracking: 1.3)
                        .foregroundColor(Theme.herb)
                    Spacer()
                    MarginButton("Take off the list") {
                        Task {
                            await shoppingService.removeRecipe(titled: recipe.title)
                            addedNote = shoppingService.lastError ?? "Taken off the list"
                        }
                    }
                }
            }
        }
        .onChange(of: struck) { _, _ in addedNote = nil }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            let steps = currentSteps
            let legacy = recipe.instructions ?? []

            SectionHead(
                title: "Method",
                figure: {
                    let count = steps.isEmpty ? legacy.count : steps.count
                    return "\(count) \(count == 1 ? "step" : "steps")"
                }()
            )
            .padding(.bottom, 4)

            if !steps.isEmpty {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    MethodStep(number: index + 1, text: step.instruction, ingredients: ingredientsForStep(step))
                    // Photos belong to the original's steps; a friend's version shows its own text only.
                    if selectedVariation == nil {
                        StepPhotoStrip(
                            photos: stepPhotos[step.id] ?? [],
                            canAdd: isOwner,
                            isUploading: uploadingStepId == step.id,
                            onAdd: { photoStep = step },
                            onOpen: { url in
                                viewingPhoto = ViewedStepPhoto(url: url, stepId: step.id,
                                                               caption: "Step \(index + 1) — \(step.instruction)")
                            }
                        )
                        .padding(.leading, 24 + Theme.spacingMD)
                        .padding(.bottom, Theme.spacingSM)
                    }
                    if index < steps.count - 1 {
                        DashedDivider()
                    }
                }
            } else {
                // Recipes written before steps carried their own ingredients
                ForEach(Array(legacy.enumerated()), id: \.offset) { index, instruction in
                    MethodStep(number: index + 1, text: instruction)
                    if index < legacy.count - 1 {
                        DashedDivider()
                    }
                }
            }
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rule()
            Text(recipe.tags.map { $0.uppercased() }.joined(separator: "  ·  "))
                .smallCaps(10, weight: .medium, tracking: 1.3)
                .foregroundColor(Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe.classicBeefStew(authorId: "123", authorUsername: "david"))
    }
}
