import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case createAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn:
            return "Sign In"
        case .createAccount:
            return "Create Account"
        }
    }
}

private enum AuthLinks {
    static let privacy = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/privacy-policy/")!
    static let terms = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/terms-of-use/")!
    static let support = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/support/")!
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: MarketplaceStore

    @State private var mode: AuthMode = .createAccount
    @State private var signInEmail = ""
    @State private var signInPassword = ""

    @State private var createName = ""
    @State private var createEmail = ""
    @State private var createPassword = ""
    @State private var createSuburb = "Brisbane"
    @State private var createRole: UserRole = .seller

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    modePicker

                    if let errorMessage {
                        errorCard(message: errorMessage)
                    }

                    if mode == .signIn {
                        signInCard
                    } else {
                        createAccountCard
                    }

                    storageCard
                    legalLinks
                }
                .padding(20)
            }
            .background(authBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var authBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.98, blue: 1.0),
                Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Real O Who")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Private property, no agent-sized commission.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Create a simple local account and we’ll remember this device. It’s enough for launch now, and we can swap in a full backend later.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                authTag("Buy directly")
                authTag("Sell privately")
                authTag("Stored locally")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.22, blue: 0.32),
                            Color(red: 0.10, green: 0.58, blue: 0.57),
                            Color(red: 0.39, green: 0.80, blue: 0.93)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .foregroundStyle(.white)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(AuthMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            errorMessage = nil
        }
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome back")
                .font(.headline)

            VStack(spacing: 12) {
                authField(
                    title: "Email",
                    text: $signInEmail,
                    prompt: "you@example.com",
                    keyboard: .emailAddress,
                    autocapitalization: .never,
                    disableAutocorrection: true
                )

                SecureField("Password", text: $signInPassword)
                    .textContentType(.password)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
            }

            Button("Sign In") {
                do {
                    try store.signIn(email: signInEmail, password: signInPassword)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(signInEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || signInPassword.isEmpty)

            Text("Only accounts created on this device will sign in for now.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(authPanel)
    }

    private var createAccountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your launch account")
                .font(.headline)

            VStack(spacing: 12) {
                authField(
                    title: "Full name",
                    text: $createName,
                    prompt: "First and last name",
                    keyboard: .default,
                    autocapitalization: .words,
                    disableAutocorrection: false
                )

                authField(
                    title: "Email",
                    text: $createEmail,
                    prompt: "you@example.com",
                    keyboard: .emailAddress,
                    autocapitalization: .never,
                    disableAutocorrection: true
                )

                SecureField("Password (8+ characters)", text: $createPassword)
                    .textContentType(.newPassword)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )

                authField(
                    title: "Suburb",
                    text: $createSuburb,
                    prompt: "Brisbane",
                    keyboard: .default,
                    autocapitalization: .words,
                    disableAutocorrection: false
                )

                Picker("I want to", selection: $createRole) {
                    Text("Buy property").tag(UserRole.buyer)
                    Text("Sell property").tag(UserRole.seller)
                }
                .pickerStyle(.segmented)
            }

            Button("Create Account") {
                do {
                    try store.createAccount(
                        name: createName,
                        email: createEmail,
                        password: createPassword,
                        role: createRole,
                        suburb: createSuburb
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                createName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                createEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                createPassword.isEmpty ||
                createSuburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(authPanel)
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Launch-ready storage")
                .font(.headline)
            Text("For this first version, account details and your signed-in session are saved only on this device. That keeps the launch flow working now without making us wait on backend infrastructure.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(authPanel)
    }

    private var legalLinks: some View {
        HStack(spacing: 14) {
            Link("Privacy", destination: AuthLinks.privacy)
            Link("Terms", destination: AuthLinks.terms)
            Link("Support", destination: AuthLinks.support)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private var authPanel: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(red: 0.98, green: 0.99, blue: 1.0))
    }

    private func errorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.39, blue: 0.35))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(authPanel)
    }

    private func authField(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType,
        autocapitalization: TextInputAutocapitalization,
        disableAutocorrection: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                )
        }
    }

    private func authTag(_ label: String) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.16))
            )
    }
}
