import SwiftUI
import CoreLocation

struct ProfileSetupView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var userService = UserService.shared
    @StateObject private var locationManager = LocationManager()

    @State private var username = ""
    @State private var termsAccepted = false
    @State private var location = ""
    @State private var isCheckingUsername = false
    @State private var usernameAvailable: Bool?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let usernameDebouncer = Debouncer(delay: 0.5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingXL) {
                PlateHeader(title: "Your page", subtitle: "The first entry in your journal")
                    .padding(.top, 40)

                Text("Choose the name friends will find you by, and where you cook.")
                    .font(.setting(15))
                    .foregroundColor(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                // Username
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Username".uppercased())
                            .smallCaps(10, weight: .semibold, tracking: 1.4)
                            .foregroundColor(Theme.ink2)
                        Spacer()
                        usernameMark
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("@")
                            .font(.setting(17))
                            .foregroundColor(Theme.ink3)
                        TextField(text: $username, prompt: Text("username").foregroundColor(Theme.ink3)) { Text("Username") }
                            .font(.setting(17))
                            .foregroundColor(Theme.ink)
                            .tint(Theme.accent)
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
                    }
                    Rule(color: usernameFieldBorderColor)

                    if let available = usernameAvailable, !available {
                        Text("Someone already goes by that.")
                            .font(.setting(12).italic())
                            .foregroundColor(Theme.error)
                    } else if !username.isEmpty && !userService.isValidUsername(username) {
                        Text("3–20 letters, numbers or underscores.")
                            .font(.setting(12).italic())
                            .foregroundColor(Theme.ink3)
                    }
                }

                // Location
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: Theme.spacingSM) {
                        FieldLine(label: "Where you cook", text: $location, prompt: "City, State")
                        if locationManager.isLoading {
                            ProgressView().tint(Theme.ink3).padding(.bottom, 10)
                        } else {
                            MarginButton("Find me") { requestLocation() }
                                .padding(.bottom, 10)
                        }
                    }
                    if let error = locationManager.errorMessage {
                        Text(error)
                            .font(.setting(12).italic())
                            .foregroundColor(Theme.ink3)
                    }
                }

                termsLine

                Button {
                    Task { await createProfile() }
                } label: {
                    if isLoading {
                        ProgressView().tint(Theme.paper)
                    } else {
                        Text("Open the journal")
                    }
                }
                .buttonStyle(.press)
                .disabled(!isFormValid || !termsAccepted || isLoading)
            }
            .padding(.bottom, Theme.spacingXL)
            .page()
        }
        .background(Theme.paper)
        .scrollDismissesKeyboard(.interactively)
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

    /* Guideline 1.2: before anyone can write or read what others share,
     * they agree to the terms — including that abuse isn't tolerated. Every
     * new account comes through this page, whichever way it signed in. */
    private var termsLine: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Button {
                termsAccepted.toggle()
            } label: {
                HStack(alignment: .top, spacing: Theme.spacingSM) {
                    TickBox(ticked: termsAccepted)
                        .padding(.top, 2)
                    Text("I agree to the Terms of use and the Privacy policy. There's no place here for abusive or objectionable content, or for people who post it.")
                        .font(.setting(14))
                        .foregroundColor(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(termsAccepted ? .isSelected : [])

            HStack(spacing: Theme.spacingLG) {
                Link(destination: LegalLinks.terms) {
                    Text("Read the terms".uppercased())
                        .smallCaps(10, weight: .semibold, tracking: 1.3)
                        .foregroundColor(Theme.accent)
                }
                Link(destination: LegalLinks.privacy) {
                    Text("Privacy policy".uppercased())
                        .smallCaps(10, weight: .semibold, tracking: 1.3)
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.leading, 17 + Theme.spacingSM)
        }
    }

    /// Checking, free, or taken — set small at the end of the label line.
    @ViewBuilder
    private var usernameMark: some View {
        if isCheckingUsername {
            ProgressView().tint(Theme.ink3).scaleEffect(0.7)
        } else if let available = usernameAvailable {
            Text((available ? "Free" : "Taken").uppercased())
                .smallCaps(9, weight: .bold, tracking: 1.2)
                .foregroundColor(available ? Theme.herb : Theme.error)
        }
    }

    private var isFormValid: Bool {
        userService.isValidUsername(username) &&
        usernameAvailable == true &&
        !location.isEmpty
    }

    private var usernameFieldBorderColor: Color {
        if username.isEmpty {
            return Theme.rule
        }
        if let available = usernameAvailable {
            return available ? Theme.herb : Theme.error
        }
        return Theme.rule
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
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLoading { manager.requestLocation() }
        case .denied, .restricted:
            // Refused at the prompt: stop the spinner rather than leave it turning.
            if isLoading {
                isLoading = false
                errorMessage = "Location is off for Food & Friends — type your city instead."
            }
        default:
            break
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
