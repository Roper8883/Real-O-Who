import SwiftUI

enum AuthMode: String, CaseIterable, Identifiable {
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

private enum DemoAccessAccount: String, CaseIterable, Identifiable {
    case buyer
    case seller

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buyer:
            return "Demo Buyer"
        case .seller:
            return "Demo Seller"
        }
    }

    var subtitle: String {
        switch self {
        case .buyer:
            return "Noah Chen"
        case .seller:
            return "Mason Wright"
        }
    }

    var email: String {
        switch self {
        case .buyer:
            return "noah@realowho.app"
        case .seller:
            return "mason@realowho.app"
        }
    }

    var password: String {
        "HouseDeal123!"
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService
    @Environment(\.dismiss) private var dismiss
    private let onComplete: (() -> Void)?
    private let canDismiss: Bool
    private let initialMode: AuthMode

    init(
        canDismiss: Bool = false,
        initialMode: AuthMode = .createAccount,
        onComplete: (() -> Void)? = nil
    ) {
        self.canDismiss = canDismiss
        self.initialMode = initialMode
        self.onComplete = onComplete
    }

    @State private var mode: AuthMode = .createAccount
    @State private var signInEmail = ""
    @State private var signInPassword = ""

    @State private var createName = ""
    @State private var createEmail = ""
    @State private var createPassword = ""
    @State private var createSuburb = "Brisbane"
    @State private var createRole: UserRole = .seller
    @State private var legalInviteCode = ""

    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isOpeningInvite = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    modePicker
                    demoAccessCard
                    legalWorkspaceInviteCard

                    if let lifecycleNotice = store.authLifecycleNotice {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account updated")
                                .font(.headline)
                            Text(lifecycleNotice)
                            Text("You can create a new launch account or sign in again at any time.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(authPanel)
                    }

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
            .navigationTitle("Start")
            .toolbar {
                if canDismiss {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                mode = initialMode
                if let inviteCode = store.inboundLegalInviteCode, !inviteCode.isEmpty {
                    legalInviteCode = inviteCode
                }
                if let message = store.inboundLegalInviteErrorMessage, !message.isEmpty {
                    errorMessage = message
                }
            }
            .onChange(of: store.inboundLegalInviteCode) { _, inviteCode in
                guard let inviteCode, !inviteCode.isEmpty else { return }
                legalInviteCode = inviteCode
            }
            .onChange(of: store.inboundLegalInviteErrorMessage) { _, message in
                guard let message, !message.isEmpty else { return }
                errorMessage = message
            }
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

            Text("Create a simple account, or open a legal workspace invite if you’re the conveyancer or solicitor handling the sale.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                authTag("Buy directly")
                authTag("Sell privately")
                authTag("Legal workspace")
                authTag("Backend ready")
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
                    prompt: "you@realowho.app",
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

            Button(isSubmitting ? "Signing In..." : "Sign In") {
                Task {
                    await signIn()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isSubmitting ||
                signInEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                signInPassword.isEmpty
            )

            Text("Backend accounts work when the local server is running. Otherwise, device-only accounts still work.")
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
                    prompt: "you@realowho.app",
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

            Button(isSubmitting ? "Creating..." : "Create Account") {
                Task {
                    await createAccount()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isSubmitting ||
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
            Text("When `backend/server.mjs` is running, sign-in and create-account use the local API. If it is offline, the app falls back to on-device storage so launch is never blocked.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(authPanel)
    }

    private var demoAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick demo access")
                .font(.headline)

            Text("Use the seeded buyer or seller account when the local backend is running. Both use the password `HouseDeal123!`.")
                .foregroundStyle(.secondary)

            ForEach(DemoAccessAccount.allCases) { account in
                Button {
                    applyDemoAccount(account)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: account == .buyer ? "person.crop.circle.badge.checkmark" : "house.circle")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.08, green: 0.49, blue: 0.55))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(account.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(account.email)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Use")
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.90, green: 0.97, blue: 0.97))
                            )
                            .foregroundStyle(Color(red: 0.05, green: 0.34, blue: 0.39))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(authPanel)
    }

    private var legalWorkspaceInviteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Legal workspace invite")
                .font(.headline)

            Text("Conveyancers and solicitors can open the limited legal workspace with the invite code shared from the sale. Invite codes activate on first use and expire after 30 days.")
                .foregroundStyle(.secondary)

            Text("Deep links in the shared invite can open this workspace directly. If the app falls back here, the invite code will already be filled in for you.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            authField(
                title: "Invite code",
                text: $legalInviteCode,
                prompt: "ROW-BUY-1A2B3C4D5E",
                keyboard: .asciiCapable,
                autocapitalization: .characters,
                disableAutocorrection: true
            )

            Button(isOpeningInvite ? "Opening..." : "Open Legal Workspace") {
                Task {
                    await openLegalWorkspace()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isOpeningInvite ||
                legalInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            Text("This opens a restricted legal-only workspace with the shared contract and sale documents.")
                .font(.footnote)
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

    @MainActor
    private func signIn() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await store.signIn(email: signInEmail, password: signInPassword)
            await messaging.activateSession(for: store.currentUserID)
            onComplete?()
            if canDismiss {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func createAccount() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await store.createAccount(
                name: createName,
                email: createEmail,
                password: createPassword,
                role: createRole,
                suburb: createSuburb
            )
            await messaging.activateSession(for: store.currentUserID)
            onComplete?()
            if canDismiss {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openLegalWorkspace() async {
        errorMessage = nil
        store.clearInboundLegalInviteError()
        isOpeningInvite = true
        defer { isOpeningInvite = false }

        do {
            let didOpen = try await store.openLegalWorkspace(inviteCode: legalInviteCode)
            if !didOpen {
                errorMessage = "That legal workspace invite could not be found yet."
            }
            onComplete?()
            if canDismiss {
                dismiss()
            }
        } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
            errorMessage = "The invite could not be loaded right now. Check the backend or try again on the device that already has the sale cached."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyDemoAccount(_ account: DemoAccessAccount) {
        mode = .signIn
        errorMessage = nil
        signInEmail = account.email
        signInPassword = account.password
    }
}
