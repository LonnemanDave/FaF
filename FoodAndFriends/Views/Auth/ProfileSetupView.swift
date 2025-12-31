import SwiftUI
import CoreLocation

struct ProfileSetupView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var userService = UserService.shared
    @StateObject private var locationManager = LocationManager()

    @State private var username = ""
    @State private var location = ""
    @State private var isCheckingUsername = false
    @State private var usernameAvailable: Bool?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let usernameDebouncer = Debouncer(delay: 0.5)

    var body: some View {
        VStack(spacing: FAFSpacing.xl) {
            // Header
            VStack(spacing: FAFSpacing.sm) {
                FAFIcon(.profile, size: 48, color: .fafCoral)
                Text("Complete Your Profile")
                    .font(FAFTypography.h1)
                    .foregroundColor(.fafTextPrimary)
                Text("Choose a unique username and set your location")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, FAFSpacing.xl)

            Spacer()

            // Form
            VStack(spacing: FAFSpacing.lg) {
                // Username Field
                VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                    Text("Username")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    HStack {
                        Text("@")
                            .font(FAFTypography.body)
                            .foregroundColor(.fafGray)
                        TextField("username", text: $username)
                            .font(FAFTypography.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: username) { _, newValue in
                                usernameAvailable = nil
                                let cleaned = newValue.lowercased().replacingOccurrences(of: " ", with: "_")
                                if cleaned != newValue {
                                    username = cleaned
                                }
                                checkUsernameAvailability()
                            }

                        if isCheckingUsername {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let available = usernameAvailable {
                            FAFIcon(
                                available ? .check : .close,
                                size: 18,
                                color: available ? .fafSage : .fafCoral
                            )
                        }
                    }
                    .padding(FAFSpacing.md)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(usernameFieldBorderColor, lineWidth: 1)
                    )

                    if let available = usernameAvailable, !available {
                        Text("This username is already taken")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafCoral)
                    } else if !username.isEmpty && !userService.isValidUsername(username) {
                        Text("3-20 characters, letters, numbers, underscores only")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafCoral)
                    }
                }

                // Location Field
                VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                    Text("Location")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)

                    HStack {
                        FAFIcon(.location, size: 18, color: .fafGray)
                        TextField("City, State", text: $location)
                            .font(FAFTypography.body)

                        if locationManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button {
                                requestLocation()
                            } label: {
                                Text("Detect")
                                    .font(FAFTypography.caption)
                                    .foregroundColor(.fafCoral)
                            }
                        }
                    }
                    .padding(FAFSpacing.md)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafGrayXLight, lineWidth: 1)
                    )

                    if let error = locationManager.errorMessage {
                        Text(error)
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafCoral)
                    }
                }
            }

            Spacer()

            // Submit Button
            FAFButton(
                title: "Continue",
                style: .primary,
                isLoading: isLoading
            ) {
                Task {
                    await createProfile()
                }
            }
            .disabled(!isFormValid)

            // Skip for now (optional)
            Button("I'll do this later") {
                // Could implement skip logic if needed
            }
            .font(FAFTypography.caption)
            .foregroundColor(.fafGray)
            .padding(.bottom, FAFSpacing.lg)
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafBackground)
        .onTapGesture {
            dismissKeyboard()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: locationManager.cityState) { _, newValue in
            if let cityState = newValue {
                location = cityState
            }
        }
    }

    private var isFormValid: Bool {
        userService.isValidUsername(username) &&
        usernameAvailable == true &&
        !location.isEmpty
    }

    private var usernameFieldBorderColor: Color {
        if username.isEmpty {
            return .fafGrayXLight
        }
        if let available = usernameAvailable {
            return available ? .fafSage : .fafCoral
        }
        return .fafGrayXLight
    }

    private func checkUsernameAvailability() {
        guard userService.isValidUsername(username) else {
            usernameAvailable = nil
            return
        }

        usernameDebouncer.debounce { [username] in
            Task { @MainActor in
                isCheckingUsername = true
                do {
                    usernameAvailable = try await userService.isUsernameAvailable(username)
                } catch {
                    usernameAvailable = nil
                }
                isCheckingUsername = false
            }
        }
    }

    private func requestLocation() {
        locationManager.requestLocation()
    }

    private func createProfile() async {
        guard let userId = authManager.firebaseUser?.uid,
              let email = authManager.firebaseUser?.email else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        isLoading = true

        do {
            try await userService.createUser(
                userId: userId,
                email: email,
                username: username,
                location: location
            )
            authManager.authState = .signedIn
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var cityState: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        errorMessage = nil
        isLoading = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Location access denied. Please enable in Settings."
        @unknown default:
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isLoading = false
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""
                    self?.cityState = "\(city), \(state)"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        errorMessage = "Could not determine location"
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - Debouncer

class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let workItem = DispatchWorkItem(block: action)
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

#Preview {
    ProfileSetupView()
}
