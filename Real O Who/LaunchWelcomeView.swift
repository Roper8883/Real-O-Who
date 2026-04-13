import SwiftUI

struct LaunchWelcomeView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    let onComplete: () -> Void
    @State private var authMode: AuthMode? = nil
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                actionCards
                dataCallout

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.94, blue: 0.94))
                        )
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.98, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .sheet(item: $authMode) { mode in
            AuthenticationView(
                canDismiss: true,
                initialMode: mode
            ) {
                onComplete()
            }
                .environmentObject(store)
                .environmentObject(messaging)
        }
        .task {
            if let inbound = store.inboundLegalInviteCode,
               !inbound.isEmpty {
                authMode = .signIn
                // invite code is prefilled in AuthenticationView via store binding
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            Text("Welcome to Real O Who")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color(red: 0.03, green: 0.23, blue: 0.33))

            Text(
                "Buy and sell privately in Australia without paying a full agent commission. Create your own account, or start with a local starter profile to use all workflows now on this device."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .foregroundStyle(.white)
    }

    private var actionCards: some View {
        VStack(spacing: 12) {
            Button(action: {
                onComplete()
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start now")
                        .font(.headline)
                    Text("Browse listings, message a seller, and review workflow sections immediately.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.white)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button("Sign in") {
                    authMode = .signIn
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("Create account") {
                    authMode = .createAccount
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var dataCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Getting started")
                .font(.subheadline.weight(.bold))
            Text("This app is fully usable without a backend by using your local starter profile. Sign in or create an account to save your own data.")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
    }

}
