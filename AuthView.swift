import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct AuthView: View {
    @EnvironmentObject private var authState: AuthState
    @State private var pinCode = ""
    @State private var didTapGoogleSignIn = false
    @State private var isAuthenticating = false
    @State private var errorMessage: String? = nil

    private var isFormValid: Bool {
        didTapGoogleSignIn && pinCode.count == 4
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Authenticate to continue")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Sign in with Google and enter your PIN code to access the Lista dos Funcionários e Municípios da SECID/PR.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: signInWithGoogleTapped) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .semibold))
                        Text(didTapGoogleSignIn ? "Signed in with Google" : "Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(didTapGoogleSignIn ? Color.green.opacity(0.12) : Color.gray.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("PIN code")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                    SecureField("Enter 4-digit PIN", text: $pinCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.gray.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: pinCode) { newValue in
                            pinCode = filteredPin(from: newValue)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: authenticate) {
                    HStack(spacing: 10) {
                        if isAuthenticating {
                            ProgressView()
                        }
                        Text("Continue")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isFormValid ? Color.blue : Color.gray.opacity(0.3))
                    )
                    .foregroundColor(.white)
                }
                .disabled(!isFormValid || isAuthenticating)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 420)
        }
    }

    private func signInWithGoogleTapped() {
        didTapGoogleSignIn = true
    }

    private func authenticate() {
        guard isFormValid else { return }

        isAuthenticating = true
        errorMessage = nil

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            }
        }
        #endif

        #if canImport(FirebaseAuth)
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                Task { @MainActor in
                    isAuthenticating = false
                    if let error = error {
                        errorMessage = "Authentication failed: \(error.localizedDescription)"
                        return
                    }
                    print("[FirebaseAuth] Signed in anonymously: \(result?.user.uid ?? "?")")
                    authState.isAuthenticated = true
                }
            }
        } else {
            isAuthenticating = false
            authState.isAuthenticated = true
        }
        #else
        isAuthenticating = false
        authState.isAuthenticated = true
        #endif
    }

    private func filteredPin(from value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return String(digits.prefix(4))
    }
}
