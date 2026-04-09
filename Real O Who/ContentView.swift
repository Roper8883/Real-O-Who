import MapKit
import SwiftUI
import UIKit

private enum AppTab: Hashable {
    case browse
    case saved
    case sell
    case messages
    case account

    init?(launchValue: String) {
        switch launchValue.lowercased() {
        case "browse":
            self = .browse
        case "saved":
            self = .saved
        case "sell":
            self = .sell
        case "messages":
            self = .messages
        case "account":
            self = .account
        default:
            return nil
        }
    }
}

private struct SearchFilters {
    var query = ""
    var suburb = ""
    var minimumBedrooms = 2
    var maximumPrice: Int? = 1_600_000
    var propertyTypes: Set<PropertyType> = []
    var sortOrder: ListingSortOrder = .featured
}

private enum LegalLinks {
    static let home = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/")!
    static let privacy = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/privacy-policy/")!
    static let terms = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/terms-of-use/")!
    static let support = URL(string: "https://roper8883.github.io/Real-O-Who/real-o-who/support/")!
    static let mail = URL(string: "mailto:aroper8@hotmail.com")!
}

private enum BrandPalette {
    static let navy = Color(red: 0.04, green: 0.22, blue: 0.32)
    static let teal = Color(red: 0.10, green: 0.58, blue: 0.57)
    static let sky = Color(red: 0.39, green: 0.80, blue: 0.93)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.30)
    static let coral = Color(red: 1.0, green: 0.39, blue: 0.35)
    static let background = Color(red: 0.95, green: 0.98, blue: 1.0)
    static let panel = Color(red: 0.98, green: 0.99, blue: 1.0)
    static let pill = Color(red: 0.91, green: 0.96, blue: 0.98)
    static let selection = Color(red: 0.88, green: 0.95, blue: 0.98)
}

struct ContentView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService
    @EnvironmentObject private var reminders: SaleReminderService

    @State private var selectedTab: AppTab
    @State private var selectedListing: PropertyListing?
    @State private var focusedSaleReminderTarget: SaleReminderNavigationTarget?
    @State private var selectedConversationID: UUID?

    init() {
        if let rawValue = AppLaunchConfiguration.shared.initialTabRawValue,
           let launchTab = AppTab(launchValue: rawValue) {
            _selectedTab = State(initialValue: launchTab)
        } else {
            _selectedTab = State(initialValue: .browse)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            BrowseView(
                selectedTab: $selectedTab,
                selectedListing: $selectedListing,
                selectedConversationID: $selectedConversationID
            )
            .tabItem {
                Label("Browse", systemImage: "house.fill")
            }
            .tag(AppTab.browse)

            SavedView(
                selectedTab: $selectedTab,
                selectedListing: $selectedListing,
                selectedConversationID: $selectedConversationID
            )
            .tabItem {
                Label("Saved", systemImage: "bookmark.fill")
            }
            .tag(AppTab.saved)

            SellView()
                .tabItem {
                    Label("Sell", systemImage: "key.horizontal.fill")
                }
                .tag(AppTab.sell)

            MessagesView(
                selectedConversationID: $selectedConversationID,
                onOpenSaleTask: { target in
                    guard let listing = store.listing(id: target.listingID) else { return }
                    selectedListing = listing
                    focusedSaleReminderTarget = target
                }
            )
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(AppTab.messages)

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.account)
        }
        .tint(.accentColor)
        .sheet(item: $selectedListing, onDismiss: {
            focusedSaleReminderTarget = nil
        }) { listing in
            ListingDetailView(
                listingID: listing.id,
                reminderTarget: focusedSaleReminderTarget,
                onOpenMessages: { conversationID in
                    selectedConversationID = conversationID
                    selectedTab = .messages
                },
                onResolveReminderTarget: { target in
                    guard focusedSaleReminderTarget?.routingKey == target.routingKey else {
                        return
                    }
                    focusedSaleReminderTarget = nil
                }
            )
            .environmentObject(store)
            .environmentObject(messaging)
            .environmentObject(reminders)
        }
        .task(id: store.currentUserID) {
            guard store.isAuthenticated else { return }
            await store.refreshListings()
            await store.refreshMarketplaceState()
            await store.refreshOffers()
            await messaging.activateSession(for: store.currentUserID)
        }
        .task(id: store.inboundSaleReminderTarget?.routingKey) {
            guard let target = store.inboundSaleReminderTarget,
                  let listing = store.listing(id: target.listingID) else {
                return
            }

            selectedTab = .browse
            selectedListing = listing
            focusedSaleReminderTarget = target
            store.consumeInboundSaleReminderTarget()
        }
    }
}

private struct BrowseView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    @Binding var selectedTab: AppTab
    @Binding var selectedListing: PropertyListing?
    @Binding var selectedConversationID: UUID?

    @State private var filters = SearchFilters()
    @State private var isShowingSaveSearchSheet = false

    private var results: [PropertyListing] {
        store.listings(
            query: filters.query,
            suburb: filters.suburb,
            minimumBedrooms: filters.minimumBedrooms,
            propertyTypes: filters.propertyTypes,
            maximumPrice: filters.maximumPrice,
            sortOrder: filters.sortOrder
        )
    }

    var body: some View {
        NavigationStack {
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    searchPanel
                    featuredStrip
                    resultsSection
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Real O Who")
            .sheet(isPresented: $isShowingSaveSearchSheet) {
                SaveSearchSheet(
                    filters: filters,
                    onSave: { title in
                        store.createSavedSearch(
                            title: title,
                            suburb: filters.suburb,
                            minimumPrice: 0,
                            maximumPrice: filters.maximumPrice ?? 0,
                            minimumBedrooms: filters.minimumBedrooms,
                            propertyTypes: filters.propertyTypes
                        )
                    }
                )
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                BrandLockup(inverse: true)
                Spacer(minLength: 12)
                Text("No % commission")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandPalette.navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                    )
            }

            Text("Sell smart. Keep more of your sale.")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("A private property app for everyday homeowners: browse, shortlist, message directly, run inspections, and negotiate without handing away a big agent fee.")
                .foregroundStyle(Color.white.opacity(0.88))

            HStack(spacing: 12) {
                MetricBadge(title: "Listings", value: "\(store.activeListings.count)")
                MetricBadge(title: "Saved", value: "\(store.currentUserSavedListings.count)")
                MetricBadge(title: "Planned", value: "\(store.currentUserPlannedInspections.count)")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrandPalette.navy,
                            BrandPalette.teal,
                            BrandPalette.sky
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search")
                .font(.headline)

            TextField("Street, suburb, feature or school catchment", text: $filters.query)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                )

            HStack(spacing: 12) {
                TextField("Suburb", text: $filters.suburb)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white)
                    )

                Menu {
                    Picker("Sort", selection: $filters.sortOrder) {
                        ForEach(ListingSortOrder.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    FilterPill(title: filters.sortOrder.title, systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            HStack(spacing: 12) {
                Menu {
                    Picker("Bedrooms", selection: $filters.minimumBedrooms) {
                        ForEach(1..<6) { count in
                            Text("\(count)+ beds").tag(count)
                        }
                    }
                } label: {
                    FilterPill(title: "\(filters.minimumBedrooms)+ beds", systemImage: "bed.double.fill")
                }

                Menu {
                    Button("Up to $900k") { filters.maximumPrice = 900_000 }
                    Button("Up to $1.2m") { filters.maximumPrice = 1_200_000 }
                    Button("Up to $1.6m") { filters.maximumPrice = 1_600_000 }
                    Button("Any price") { filters.maximumPrice = nil }
                } label: {
                    FilterPill(
                        title: filters.maximumPrice.map { "Up to \(currencyString($0))" } ?? "Any price",
                        systemImage: "dollarsign.circle.fill"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Property types")
                    .font(.subheadline.weight(.semibold))

                AdaptiveTagGrid(minimum: 120) {
                    ForEach(PropertyType.allCases) { type in
                        Button {
                            if filters.propertyTypes.contains(type) {
                                filters.propertyTypes.remove(type)
                            } else {
                                filters.propertyTypes.insert(type)
                            }
                        } label: {
                            SelectableChip(
                                title: type.title,
                                isSelected: filters.propertyTypes.contains(type)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Save This Search") {
                isShowingSaveSearchSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private var featuredStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(store.featuredListings) { listing in
                        Button {
                            selectedListing = listing
                        } label: {
                            FeaturedListingCard(
                                listing: listing,
                                seller: store.user(id: listing.sellerID)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                Text("\(results.count) matches")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(results) { listing in
                Button {
                    selectedListing = listing
                } label: {
                    ListingCard(
                        listing: listing,
                        seller: store.user(id: listing.sellerID),
                        isFavorite: store.isFavorite(listingID: listing.id),
                        onFavoriteToggle: {
                            store.toggleFavorite(listingID: listing.id)
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SavedView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    @Binding var selectedTab: AppTab
    @Binding var selectedListing: PropertyListing?
    @Binding var selectedConversationID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Saved",
                        subtitle: "Shortlist homes, watch suburbs, and keep inspections in one place while you buy without agent friction."
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Saved listings")
                            .font(.headline)

                        if store.currentUserSavedListings.isEmpty {
                            EmptyPanel(message: "Save a property from Browse to start a shortlist.")
                        } else {
                            ForEach(store.currentUserSavedListings) { listing in
                                Button {
                                    selectedListing = listing
                                } label: {
                                    ListingCard(
                                        listing: listing,
                                        seller: store.user(id: listing.sellerID),
                                        isFavorite: store.isFavorite(listingID: listing.id),
                                        onFavoriteToggle: {
                                            store.toggleFavorite(listingID: listing.id)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Saved searches")
                            .font(.headline)

                        ForEach(store.savedSearches) { search in
                            SavedSearchCard(
                                search: search,
                                onToggleAlerts: {
                                    store.toggleSavedSearchAlerts(id: search.id)
                                }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inspection planner")
                            .font(.headline)

                        if store.currentUserPlannedInspections.isEmpty {
                            EmptyPanel(message: "Add an inspection from a listing to build your planner.")
                        } else {
                            ForEach(store.currentUserPlannedInspections, id: \.slot.id) { item in
                                InspectionPlannerCard(listing: item.listing, slot: item.slot)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Watchlist")
        }
    }
}

private struct SellView: View {
    @EnvironmentObject private var store: MarketplaceStore

    @State private var isShowingCreateListing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Seller Hub",
                        subtitle: "Run a private sale with owner tools, direct offers, and more money staying in your pocket."
                    )

                    if store.currentUser.role != .seller {
                        EmptyPanel(message: "Switch to a seller profile in Account to create and manage private listings.")
                    } else {
                        sellerStats
                        ownerInsights
                        sellerListings
                    }
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Sell Privately")
            .toolbar {
                if store.currentUser.role == .seller {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New Listing") {
                            isShowingCreateListing = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateListing) {
                CreateListingSheet { draft in
                    store.createListing(from: draft, sellerID: store.currentUserID)
                }
            }
        }
    }

    private var sellerStats: some View {
        let stats = store.sellerDashboardStats

        return AdaptiveTagGrid(minimum: 150) {
            StatPanel(title: "Active", value: "\(stats.activeListings)", subtitle: "Private listings live")
            StatPanel(title: "Drafts", value: "\(stats.draftListings)", subtitle: "Listings in progress")
            StatPanel(title: "Offers", value: "\(stats.totalOffers)", subtitle: "Offer records received")
            StatPanel(title: "Demand", value: "\(stats.averageDemandScore)", subtitle: "Average buyer demand score")
        }
    }

    private var ownerInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Owner market snapshot")
                .font(.headline)

            let ownedListings = store.sellerListings(for: store.currentUserID)
            let demandAverage = ownedListings.isEmpty ? 0 : ownedListings.map(\.marketPulse.buyerDemandScore).reduce(0, +) / ownedListings.count

            HighlightInformationCard(
                title: "Architecture inspired by the market leaders",
                message: "Search-led discovery, value estimates, suburb insight, inspection planning, offers, and direct messaging are surfaced in the same decision order buyers expect.",
                supporting: "Your current portfolio demand score averages \(demandAverage)."
            )
        }
    }

    private var sellerListings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your listings")
                .font(.headline)

            ForEach(store.sellerListings(for: store.currentUserID)) { listing in
                SellerListingCard(
                    listing: listing,
                    offerCount: store.offers.filter { $0.listingID == listing.id }.count
                )
            }
        }
    }
}

private struct MessagesView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    @Binding var selectedConversationID: UUID?
    let onOpenSaleTask: (SaleReminderNavigationTarget) -> Void

    private var threads: [EncryptedConversation] {
        messaging.threads(for: store.currentUserID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedConversationID) {
                if threads.isEmpty {
                    Text("No conversations yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(threads) { thread in
                        ConversationRow(
                            thread: thread,
                            listing: store.listing(id: thread.listingID),
                            currentUserID: store.currentUserID,
                            counterpart: counterpart(for: thread)
                        )
                        .tag(Optional(thread.id))
                    }
                }
            }
            .navigationTitle("Secure Messages")
        } detail: {
            if let selectedConversationID,
               messaging.thread(id: selectedConversationID) != nil {
                ConversationThreadView(
                    threadID: selectedConversationID,
                    onOpenSaleTask: onOpenSaleTask
                )
                    .environmentObject(store)
                    .environmentObject(messaging)
            } else {
                EmptyPanel(message: "Open a listing and tap Message Seller to start a secure conversation.")
                    .padding()
            }
        }
    }

    private func counterpart(for thread: EncryptedConversation) -> UserProfile? {
        let participant = thread.participantIDs.first { $0 != store.currentUserID }
        return participant.flatMap { store.user(id: $0) }
    }
}

private struct AccountView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    @State private var switchNotice: String?
    @State private var isSwitchingDemo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Account",
                        subtitle: "Manage the local account that unlocks the private-sale journey on this device."
                    )

                    brandPromise
                    if let switchNotice {
                        HighlightInformationCard(
                            title: "Account updated",
                            message: switchNotice,
                            supporting: "The shared demo sale is ready in Browse and Secure Messages."
                        )
                    }
                    currentAccountCard
                    marketplaceArchitecture
                    legalLinks
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Account")
        }
    }

    private var brandPromise: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandLockup()
            Text("Built for regular people selling a home privately and wanting the relationship, the negotiation, and the upside to stay direct.")
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                InfoPill(label: "Owner-first")
                InfoPill(label: "Direct buyer chat")
                InfoPill(label: "Keep more")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, BrandPalette.panel],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var currentAccountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signed in account")
                .font(.headline)

            PersonaCard(user: store.currentUser, isSelected: true)

            VStack(alignment: .leading, spacing: 8) {
                if let account = store.currentAccount {
                    Text(account.redactedEmail)
                        .font(.subheadline.weight(.semibold))
                }

                Text(store.storageModeSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.07, green: 0.45, blue: 0.49))

                Text(store.backendEndpointSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(
                    store.currentUser.role == .seller
                        ? "Seller tools are unlocked, so you can create listings and manage offers."
                        : "Buyer tools are unlocked, so you can shortlist homes, plan inspections, and message owners."
                )
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick demo switching")
                    .font(.subheadline.weight(.semibold))

                Text("Jump between the seeded buyer and seller accounts without typing credentials again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    demoSwitchButton(
                        title: "Use Demo Buyer",
                        subtitle: "Noah Chen",
                        account: .buyer
                    )

                    demoSwitchButton(
                        title: "Use Demo Seller",
                        subtitle: "Mason Wright",
                        account: .seller
                    )
                }
            }

            Button("Sign Out") {
                store.signOut()
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func demoSwitchButton(
        title: String,
        subtitle: String,
        account: AccountDemoAccessAccount
    ) -> some View {
        Button {
            Task {
                await switchToDemoAccount(account)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BrandPalette.panel)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSwitchingDemo)
    }

    private var marketplaceArchitecture: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is built into this architecture")
                .font(.headline)

            AdaptiveTagGrid(minimum: 160) {
                FeatureTile(
                    title: "Search-first browse",
                    subtitle: "Filters, suburb watchlists, property types, and featured ranking."
                )
                FeatureTile(
                    title: "Due diligence surfaces",
                    subtitle: "Value estimate ranges, comparable sales, school catchment, and demand score."
                )
                FeatureTile(
                    title: "Inspection planning",
                    subtitle: "Buyers can save inspection slots into a personal planner."
                )
                FeatureTile(
                    title: "Private seller workflow",
                    subtitle: "Owner-managed listings, direct offers, and seller performance cards."
                )
                FeatureTile(
                    title: "Secure messaging",
                    subtitle: "Buyer-seller threads are persisted in an encrypted local vault."
                )
                FeatureTile(
                    title: "Service boundary",
                    subtitle: "Listings and messaging are isolated so a hosted E2EE backend can be dropped in later."
                )
                FeatureTile(
                    title: "Local launch auth",
                    subtitle: "Sign-in state and account details are persisted locally until a hosted auth backend is added."
                )
            }
        }
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support and legal")
                .font(.headline)

            LinkRow(title: "Website", destination: LegalLinks.home)
            LinkRow(title: "Privacy Policy", destination: LegalLinks.privacy)
            LinkRow(title: "Terms of Use", destination: LegalLinks.terms)
            LinkRow(title: "Support", destination: LegalLinks.support)
            LinkRow(title: "Email Support", destination: LegalLinks.mail)
        }
    }

    @MainActor
    private func switchToDemoAccount(_ account: AccountDemoAccessAccount) async {
        switchNotice = nil
        isSwitchingDemo = true
        defer { isSwitchingDemo = false }

        do {
            try await store.signIn(email: account.email, password: account.password)
            await messaging.activateSession(for: store.currentUserID)
            switchNotice = "Signed in as \(account.subtitle)."
        } catch {
            switchNotice = error.localizedDescription
        }
    }
}

private enum AccountDemoAccessAccount {
    case buyer
    case seller

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

    var subtitle: String {
        switch self {
        case .buyer:
            return "Noah Chen"
        case .seller:
            return "Mason Wright"
        }
    }
}

private struct ListingDetailView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService
    @EnvironmentObject private var reminders: SaleReminderService
    @Environment(\.dismiss) private var dismiss

    let listingID: UUID
    let reminderTarget: SaleReminderNavigationTarget?
    let onOpenMessages: (UUID) -> Void
    let onResolveReminderTarget: (SaleReminderNavigationTarget) -> Void

    @State private var offerComposer: OfferComposerContext?
    @State private var legalSearchContext: LegalSearchContext?
    @State private var shareInviteContext: SaleInviteShareContext?
    @State private var inviteTaskContext: SaleInviteTaskContext?
    @State private var contractSigningContext: ContractSigningTaskContext?
    @State private var preparedDocument: PreparedSaleDocument?
    @State private var autoPresentedFocusedActionKey: String?
    @State private var notice: ListingNotice?

    private var listing: PropertyListing? {
        store.listing(id: listingID)
    }

    private var relevantOffer: OfferRecord? {
        store.relevantOffer(for: listingID, userID: store.currentUserID)
    }

    private static func saleChecklistScrollID(for itemID: String) -> String {
        "sale-workspace-checklist:\(itemID)"
    }

    private enum SaleInviteTaskPreferredAction {
        case share
        case regenerate
    }

    private struct SaleInviteTaskContext: Identifiable {
        let listingID: UUID
        let offerID: UUID
        let role: LegalInviteRole
        let preferredAction: SaleInviteTaskPreferredAction

        var id: String {
            "\(offerID.uuidString)-\(role.rawValue)-\(preferredAction)"
        }
    }

    private struct ContractSigningTaskContext: Identifiable {
        let listingID: UUID
        let offerID: UUID

        var id: UUID {
            offerID
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let listing {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ListingHero(listing: listing)
                                summaryCard(for: listing)
                                if let offer = relevantOffer {
                                    saleWorkspaceCard(for: listing, offer: offer)
                                    legalCoordinationCard(for: listing, offer: offer)
                                }
                                inspectionCard(for: listing)
                                marketCard(for: listing)
                                mapCard(for: listing)
                                comparablesCard(for: listing)
                            }
                            .padding(20)
                        }
                        .background(BrandPalette.background.ignoresSafeArea())
                        .navigationTitle(listing.address.suburb)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { dismiss() }
                            }
                        }
                        .task(id: listing.id) {
                            await store.refreshSale(for: listing.id)
                        }
                        .task(id: reminderTarget?.routingKey) {
                            guard let reminderTarget,
                                  reminderTarget.listingID == listing.id,
                                  let offer = relevantOffer,
                                  offer.id == reminderTarget.offerID else {
                                return
                            }

                            try? await Task.sleep(for: .milliseconds(250))
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                proxy.scrollTo(
                                    Self.saleChecklistScrollID(for: reminderTarget.checklistItemID),
                                    anchor: .center
                                )
                            }

                            if let prompt = focusedReminderPrompt(for: listing, offer: offer),
                               autoPresentedFocusedActionKey != reminderTarget.routingKey {
                                autoPresentedFocusedActionKey = reminderTarget.routingKey

                                switch prompt.action {
                                case let .chooseLegalRep(role):
                                    legalSearchContext = LegalSearchContext(
                                        offerID: offer.id,
                                        role: role
                                    )
                                case .signContract:
                                    contractSigningContext = ContractSigningTaskContext(
                                        listingID: listing.id,
                                        offerID: offer.id
                                    )
                                case let .shareInvite(role):
                                    if let invite = latestInvite(for: offer, role: role) {
                                        shareInviteContext = SaleInviteShareContext(
                                            listingID: listing.id,
                                            offerID: offer.id,
                                            role: invite.role,
                                            title: invite.role.title,
                                            shareMessage: invite.shareMessage
                                        )
                                    }
                                case let .regenerateInvite(role):
                                    if latestInvite(for: offer, role: role) != nil {
                                        inviteTaskContext = SaleInviteTaskContext(
                                            listingID: listing.id,
                                            offerID: offer.id,
                                            role: role,
                                            preferredAction: .regenerate
                                        )
                                    }
                                case .openMessages:
                                    break
                                }
                            }
                        }
                    }
                    .sheet(item: $offerComposer) { composer in
                        OfferSheet(
                            listing: listing,
                            title: composer.title,
                            amountLabel: composer.amountLabel,
                            conditionsLabel: composer.conditionsLabel,
                            submitTitle: composer.submitTitle,
                            initialAmount: composer.amount,
                            initialConditions: composer.conditions
                        ) { amount, conditions in
                            switch composer.mode {
                            case .buyer:
                                handleBuyerOfferSubmission(
                                    listing: listing,
                                    amount: amount,
                                    conditions: conditions
                                )
                            case let .seller(action):
                                handleSellerOfferSubmission(
                                    listing: listing,
                                    offer: composer.offer,
                                    action: action,
                                    amount: amount,
                                    conditions: conditions
                                )
                            }
                        }
                    }
                    .sheet(item: $legalSearchContext) { context in
                        LegalSearchSheet(
                            listing: listing,
                            actingRole: context.role,
                            currentSelection: store.offer(id: context.offerID).flatMap {
                                context.role == .buyer ? $0.buyerLegalSelection?.professional : $0.sellerLegalSelection?.professional
                            },
                            onSelect: { professional in
                                guard let outcome = store.selectLegalProfessional(
                                    offerID: context.offerID,
                                    userID: store.currentUserID,
                                    professional: professional
                                ),
                                let updatedOffer = store.offer(id: context.offerID),
                                let buyer = store.user(id: updatedOffer.buyerID),
                                let seller = store.user(id: updatedOffer.sellerID) else {
                                    return
                                }

                                if let packet = outcome.contractPacket {
                                    messaging.sendContractPacket(
                                        listing: listing,
                                        offerID: updatedOffer.id,
                                        buyer: buyer,
                                        seller: seller,
                                        packet: packet,
                                        triggeredBy: store.currentUser
                                    )
                                    notice = ListingNotice(message: "Both legal representatives are set. Contract packet sent to both parties in secure messages.")
                                } else {
                                    notice = ListingNotice(message: "Your legal representative has been saved for this sale.")
                                }

                                resolveReminderIfMatching(
                                    offerID: updatedOffer.id,
                                    itemIDs: [
                                        "buyer-representative",
                                        "seller-representative",
                                        "contract-packet"
                                    ],
                                    actionTitle: "Legal representative selected"
                                )
                            }
                        )
                        .environmentObject(store)
                    }
                    .sheet(item: $inviteTaskContext) { context in
                        if let offer = store.offer(id: context.offerID),
                           let invite = latestInvite(for: offer, role: context.role) {
                            ReminderInviteManagementSheet(
                                invite: invite,
                                prefersRegeneration: context.preferredAction == .regenerate,
                                onShare: {
                                    let shareContext = SaleInviteShareContext(
                                        listingID: listing.id,
                                        offerID: offer.id,
                                        role: invite.role,
                                        title: invite.role.title,
                                        shareMessage: invite.shareMessage
                                    )
                                    inviteTaskContext = nil
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(150))
                                        shareInviteContext = shareContext
                                    }
                                },
                                onRegenerate: {
                                    handleSaleInviteManagement(
                                        listing: listing,
                                        offer: offer,
                                        invite: invite,
                                        action: .regenerate
                                    )
                                    inviteTaskContext = nil
                                },
                                onRevoke: {
                                    handleSaleInviteManagement(
                                        listing: listing,
                                        offer: offer,
                                        invite: invite,
                                        action: .revoke
                                    )
                                    inviteTaskContext = nil
                                }
                            )
                        } else {
                            EmptyPanel(message: "That legal workspace invite is no longer available.")
                                .padding()
                        }
                    }
                    .sheet(item: $contractSigningContext) { context in
                        if let offer = store.offer(id: context.offerID),
                           let packet = offer.contractPacket {
                            ContractSigningTaskSheet(
                                offer: offer,
                                packet: packet,
                                currentUserID: store.currentUserID,
                                onSign: {
                                    handleContractSigning(listing: listing, offer: offer)
                                    contractSigningContext = nil
                                },
                                onOpenMessages: {
                                    openConversation(for: listing, offer: offer)
                                    contractSigningContext = nil
                                }
                            )
                        } else {
                            EmptyPanel(message: "This contract packet is no longer available.")
                                .padding()
                        }
                    }
                    .sheet(item: $shareInviteContext) { context in
                        TrackedShareSheet(
                            title: context.title,
                            items: [context.shareMessage]
                        ) { completed in
                            if completed {
                                handleSaleInviteShare(
                                    listingID: context.listingID,
                                    offerID: context.offerID,
                                    role: context.role
                                )
                            }
                        }
                    }
                    .sheet(item: $preparedDocument) { document in
                        SaleDocumentPreviewSheet(document: document)
                    }
                    .alert(item: $notice) { notice in
                        Alert(title: Text("Updated"), message: Text(notice.message), dismissButton: .default(Text("OK")))
                    }
                } else {
                    EmptyPanel(message: "Listing unavailable.")
                        .padding()
                }
            }
        }
    }

    private enum FocusedReminderAction {
        case chooseLegalRep(UserRole)
        case signContract
        case shareInvite(LegalInviteRole)
        case regenerateInvite(LegalInviteRole)
        case openMessages
    }

    private struct FocusedReminderPrompt {
        let title: String
        let message: String
        let buttonTitle: String
        let action: FocusedReminderAction
    }

    private func focusedReminderPrompt(
        for listing: PropertyListing,
        offer: OfferRecord
    ) -> FocusedReminderPrompt? {
        guard let reminderTarget,
              reminderTarget.offerID == offer.id,
              let item = offer.settlementChecklist.first(where: { $0.id == reminderTarget.checklistItemID }) else {
            return nil
        }

        let message = item.nextActionSummary ?? item.reminderSummary ?? item.detail
        let defaultPrompt = FocusedReminderPrompt(
            title: item.title,
            message: message,
            buttonTitle: "Open secure thread",
            action: .openMessages
        )

        switch item.id {
        case "buyer-representative":
            guard offer.buyerID == store.currentUserID,
                  offer.buyerLegalSelection == nil else {
                return defaultPrompt
            }

            return FocusedReminderPrompt(
                title: item.title,
                message: message,
                buttonTitle: "Choose buyer legal rep",
                action: .chooseLegalRep(.buyer)
            )
        case "seller-representative":
            guard offer.sellerID == store.currentUserID,
                  offer.sellerLegalSelection == nil else {
                return defaultPrompt
            }

            return FocusedReminderPrompt(
                title: item.title,
                message: message,
                buttonTitle: "Choose seller legal rep",
                action: .chooseLegalRep(.seller)
            )
        case "contract-packet":
            if offer.buyerID == store.currentUserID && offer.buyerLegalSelection == nil {
                return FocusedReminderPrompt(
                    title: item.title,
                    message: message,
                    buttonTitle: "Choose buyer legal rep",
                    action: .chooseLegalRep(.buyer)
                )
            }

            if offer.sellerID == store.currentUserID && offer.sellerLegalSelection == nil {
                return FocusedReminderPrompt(
                    title: item.title,
                    message: message,
                    buttonTitle: "Choose seller legal rep",
                    action: .chooseLegalRep(.seller)
                )
            }

            return defaultPrompt
        case "workspace-invites", "workspace-active":
            let role: LegalInviteRole = store.currentUserID == offer.buyerID ? .buyerRepresentative : .sellerRepresentative
            guard let invite = latestInvite(for: offer, role: role) else {
                return defaultPrompt
            }

            if invite.isUnavailable {
                return FocusedReminderPrompt(
                    title: item.title,
                    message: message,
                    buttonTitle: "Regenerate invite",
                    action: .regenerateInvite(role)
                )
            }

            return FocusedReminderPrompt(
                title: item.title,
                message: message,
                buttonTitle: invite.hasBeenShared ? "Resend invite" : "Share invite",
                action: .shareInvite(role)
            )
        case "contract-signatures":
            if let packet = offer.contractPacket,
               offer.status == .accepted,
               packet.signedAt(for: store.currentUserID) == nil,
               !packet.isFullySigned {
                return FocusedReminderPrompt(
                    title: item.title,
                    message: message,
                    buttonTitle: "Sign contract packet",
                    action: .signContract
                )
            }

            return defaultPrompt
        case "legal-review-pack", "settlement-statement":
            return defaultPrompt
        default:
            return defaultPrompt
        }
    }

    private func latestInvite(
        for offer: OfferRecord,
        role: LegalInviteRole
    ) -> SaleWorkspaceInvite? {
        offer.invites
            .filter { $0.role == role }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func performFocusedReminderAction(
        _ action: FocusedReminderAction,
        listing: PropertyListing,
        offer: OfferRecord
    ) {
        switch action {
        case let .chooseLegalRep(role):
            legalSearchContext = LegalSearchContext(
                offerID: offer.id,
                role: role
            )
        case .signContract:
            contractSigningContext = ContractSigningTaskContext(
                listingID: listing.id,
                offerID: offer.id
            )
        case let .shareInvite(role):
            guard let invite = latestInvite(for: offer, role: role) else {
                notice = ListingNotice(message: "That legal workspace invite is no longer available.")
                return
            }

            shareInviteContext = SaleInviteShareContext(
                listingID: listing.id,
                offerID: offer.id,
                role: invite.role,
                title: invite.role.title,
                shareMessage: invite.shareMessage
            )
        case let .regenerateInvite(role):
            guard let invite = latestInvite(for: offer, role: role) else {
                notice = ListingNotice(message: "That legal workspace invite is no longer available.")
                return
            }

            inviteTaskContext = SaleInviteTaskContext(
                listingID: listing.id,
                offerID: offer.id,
                role: invite.role,
                preferredAction: .regenerate
            )
        case .openMessages:
            openConversation(for: listing, offer: offer)
        }
    }

    private func resolveReminderIfMatching(
        offerID: UUID,
        itemIDs: Set<String>,
        actionTitle: String
    ) {
        guard let reminderTarget,
              reminderTarget.offerID == offerID,
              itemIDs.contains(reminderTarget.checklistItemID) else {
            return
        }

        if let outcome = store.recordReminderTimelineActivity(
            offerID: offerID,
            checklistItemID: reminderTarget.checklistItemID,
            actionTitle: actionTitle,
            triggeredBy: store.currentUserID
        ),
        let listing = store.listing(id: outcome.offer.listingID),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) {
            let sender = store.currentUserID == buyer.id ? buyer : seller
            let recipient = sender.id == buyer.id ? seller : buyer
            messaging.sendMessage(
                listing: listing,
                from: sender,
                to: recipient,
                body: outcome.threadMessage,
                isSystem: true,
                saleTaskTarget: reminderTarget
            )
        }
        onResolveReminderTarget(reminderTarget)
        Task {
            await reminders.clearReminder(
                for: reminderTarget,
                actionTitle: actionTitle
            )
        }
    }

    private func snoozeFocusedReminder() {
        guard let reminderTarget else { return }
        let snoozedUntil = Date().addingTimeInterval(60 * 60 * 24)
        if let outcome = store.recordReminderTimelineActivity(
            offerID: reminderTarget.offerID,
            checklistItemID: reminderTarget.checklistItemID,
            actionTitle: "Snoozed for 24 hours",
            snoozedUntil: snoozedUntil,
            triggeredBy: store.currentUserID
        ),
        let listing = store.listing(id: outcome.offer.listingID),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) {
            let sender = store.currentUserID == buyer.id ? buyer : seller
            let recipient = sender.id == buyer.id ? seller : buyer
            messaging.sendMessage(
                listing: listing,
                from: sender,
                to: recipient,
                body: outcome.threadMessage,
                isSystem: true,
                saleTaskTarget: reminderTarget
            )
        }
        onResolveReminderTarget(reminderTarget)
        Task {
            await reminders.snoozeReminder(
                for: reminderTarget,
                duration: 60 * 60 * 24
            )
        }
        notice = ListingNotice(message: "Reminder snoozed for 24 hours.")
    }

    @ViewBuilder
    private func focusedReminderActionCard(
        _ prompt: FocusedReminderPrompt,
        listing: PropertyListing,
        offer: OfferRecord
    ) -> some View {
        let activity = reminderTarget.map(reminders.reminderActivity(for:)) ?? []
        let snoozedUntil = reminderTarget.flatMap(reminders.snoozedUntil(for:))

        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder shortcut")
                .font(.headline)
            Text(prompt.title)
                .font(.subheadline.weight(.semibold))
            Text(prompt.message)
                .foregroundStyle(.secondary)

            if let snoozedUntil {
                Text("Snoozed until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.teal)
            }

            Button(prompt.buttonTitle) {
                performFocusedReminderAction(prompt.action, listing: listing, offer: offer)
            }
            .buttonStyle(.borderedProminent)

            if reminderTarget != nil {
                Button("Snooze 24 hours") {
                    snoozeFocusedReminder()
                }
                .buttonStyle(.bordered)
            }

            if !activity.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder activity")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(activity.prefix(3))) { entry in
                        Text("\(entry.title) • \(relativeDateString(entry.createdAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 1.0, green: 0.97, blue: 0.91))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(BrandPalette.coral.opacity(0.75), lineWidth: 1.5)
        )
    }

    private func summaryCard(for listing: PropertyListing) -> some View {
        let seller = store.user(id: listing.sellerID)
        let isOwnerView = store.currentUserID == listing.sellerID
        let currentOffer = relevantOffer

        return VStack(alignment: .leading, spacing: 14) {
            Text(currencyString(listing.askingPrice))
                .font(.system(.title, design: .rounded, weight: .bold))

            Text(listing.primaryFactLine)
                .font(.headline)

            Text(listing.summary)
                .foregroundStyle(.secondary)

            if let seller {
                Label("\(seller.name) • \(seller.verificationNote)", systemImage: "checkmark.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            AdaptiveTagGrid(minimum: 120) {
                ForEach(listing.features, id: \.self) { feature in
                    SelectableChip(title: feature, isSelected: true)
                }
            }

            HStack(spacing: 12) {
                Button(store.isFavorite(listingID: listing.id) ? "Saved" : "Save") {
                    store.toggleFavorite(listingID: listing.id)
                }
                .buttonStyle(.bordered)

                if isOwnerView {
                    Text(currentOffer == nil ? "Owner view: manage this listing from Sell." : "Owner view: the live negotiation workspace is ready below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Message Seller") {
                        openConversation(for: listing)
                    }
                    .buttonStyle(.borderedProminent)

                    if store.currentUser.role == .buyer {
                        if currentOffer?.contractPacket?.isFullySigned == true {
                            Text("Sale complete. The listing is now marked sold.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if currentOffer?.status == .accepted {
                            Text("Offer accepted. Finish the legal handoff in the live sale workspace below.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(buyerOfferButtonTitle(for: currentOffer)) {
                                presentBuyerOfferComposer(using: currentOffer)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func saleWorkspaceCard(for listing: PropertyListing, offer: OfferRecord) -> some View {
        let isBuyerView = offer.buyerID == store.currentUserID

        return VStack(alignment: .leading, spacing: 14) {
            Text("Live sale workspace")
                .font(.headline)

            Text(
                isBuyerView
                    ? "Your offer, seller responses, and contract handoff stay together here."
                    : "Accept the offer, request changes, or send a counteroffer without leaving the private-sale workspace."
            )
            .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: "Ask \(currencyString(listing.askingPrice))")
                InfoPill(label: "Offer \(currencyString(offer.amount))")
                InfoPill(label: offer.status.title)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current terms")
                    .font(.subheadline.weight(.semibold))
                Text(offer.conditions)
                .foregroundStyle(.secondary)
                Text("Updated \(relativeDateString(offer.createdAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let prompt = focusedReminderPrompt(for: listing, offer: offer) {
                focusedReminderActionCard(prompt, listing: listing, offer: offer)
            }

            if isBuyerView {
                buyerSaleWorkspaceActions(for: offer)
            } else {
                sellerSaleWorkspaceActions(for: listing, offer: offer)
            }

            Divider()
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 12) {
                Text("Settlement checklist")
                    .font(.headline)

                Text("Everyone in the deal sees the same milestones from legal rep selection through to settlement.")
                    .foregroundStyle(.secondary)

                SaleChecklistContent(
                    items: offer.settlementChecklist,
                    scrollIDPrefix: "sale-workspace-checklist",
                    focusedItemID: reminderTarget?.offerID == offer.id ? reminderTarget?.checklistItemID : nil
                )
            }

            if !offer.updates.isEmpty {
                SaleUpdatesCard(offer: offer)
            }

            Button("Open secure thread") {
                openConversation(for: listing, offer: offer)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    @ViewBuilder
    private func buyerSaleWorkspaceActions(for offer: OfferRecord) -> some View {
        if offer.contractPacket?.isFullySigned == true {
            HighlightInformationCard(
                title: "Sale complete",
                message: "Both buyer and seller have signed the contract packet. This listing is now marked sold.",
                supporting: "Secure messages still hold the signed-sale timeline."
            )
        } else {
            switch offer.status {
            case .accepted:
                HighlightInformationCard(
                    title: "Offer accepted",
                    message: "The seller has accepted these terms. Next step: finish legal coordination and contract exchange.",
                    supporting: "Move into the legal handoff below to keep the sale moving."
                )
            case .countered:
                HighlightInformationCard(
                    title: "Counteroffer received",
                    message: "The seller has replied with a counteroffer. Review the updated amount and terms, then respond with your next move.",
                    supporting: "You can revise your offer from this workspace."
                )
                Button("Respond to Counteroffer") {
                    presentBuyerOfferComposer(using: offer)
                }
                .buttonStyle(.borderedProminent)
            case .changesRequested:
                HighlightInformationCard(
                    title: "Seller requested changes",
                    message: "The seller wants updated terms before accepting. Adjust the offer amount or conditions and send your response.",
                    supporting: "Your updated offer will sync back into the shared sale workspace."
                )
                Button("Send Updated Terms") {
                    presentBuyerOfferComposer(using: offer)
                }
                .buttonStyle(.borderedProminent)
            case .underOffer:
                HighlightInformationCard(
                    title: "Offer sent",
                    message: "Your offer is live with the seller. You can still refine the amount or conditions if the conversation moves.",
                    supporting: "Updates from either side stay attached to this sale."
                )
                Button("Update Offer") {
                    presentBuyerOfferComposer(using: offer)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func sellerSaleWorkspaceActions(for listing: PropertyListing, offer: OfferRecord) -> some View {
        if offer.contractPacket?.isFullySigned == true {
            HighlightInformationCard(
                title: "Sale complete",
                message: "Both sides have signed the contract packet and the listing is now marked sold.",
                supporting: "Use the secure thread for any final settlement notes."
            )
        } else {
            HighlightInformationCard(
                title: offer.status == .accepted ? "Offer accepted" : "Seller controls",
                message: offer.status == .accepted
                    ? "The current terms have been accepted. You can still open the secure thread and finish the legal handoff."
                    : "Choose whether to accept the current terms, request changes, or send a counteroffer back to the buyer.",
                supporting: "Any seller response is posted into secure messages automatically."
            )

            Button(SellerOfferAction.accept.title) {
                handleSellerOfferSubmission(
                    listing: listing,
                    offer: offer,
                    action: .accept,
                    amount: offer.amount,
                    conditions: offer.conditions
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(offer.status == .accepted)

            Button(SellerOfferAction.requestChanges.title) {
                offerComposer = OfferComposerContext(
                    mode: .seller(.requestChanges),
                    offer: offer,
                    amount: offer.amount,
                    conditions: offer.conditions
                )
            }
            .buttonStyle(.bordered)
            .disabled(offer.status == .accepted)

            Button(SellerOfferAction.counter.title) {
                offerComposer = OfferComposerContext(
                    mode: .seller(.counter),
                    offer: offer,
                    amount: offer.amount,
                    conditions: offer.conditions
                )
            }
            .buttonStyle(.bordered)
            .disabled(offer.status == .accepted)
        }
    }

    private func legalCoordinationCard(for listing: PropertyListing, offer: OfferRecord) -> some View {
        let actingRole: UserRole = offer.buyerID == store.currentUserID ? .buyer : .seller
        let mySelection = actingRole == .buyer ? offer.buyerLegalSelection : offer.sellerLegalSelection

        return VStack(alignment: .leading, spacing: 14) {
            Text("Legal coordination")
                .font(.headline)

            Text("Search nearby conveyancers, solicitors, and property lawyers around the listing area, then lock in one representative for each side of the sale.")
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: "Offer \(currencyString(offer.amount))")
                InfoPill(label: offer.status.title)
                if offer.contractPacket != nil {
                    InfoPill(label: "Contract ready")
                }
            }

            LegalSelectionStatusRow(
                title: "Buyer representative",
                subtitle: offer.buyerID == store.currentUserID ? "Your selection" : "Buyer selection",
                selection: offer.buyerLegalSelection
            )

            LegalSelectionStatusRow(
                title: "Seller representative",
                subtitle: offer.sellerID == store.currentUserID ? "Your selection" : "Seller selection",
                selection: offer.sellerLegalSelection
            )

            if let packet = offer.contractPacket {
                ContractSigningStatusRow(
                    title: "Buyer sign-off",
                    subtitle: offer.buyerID == store.currentUserID ? "Your contract signature" : "Buyer contract signature",
                    signedAt: packet.buyerSignedAt
                )

                ContractSigningStatusRow(
                    title: "Seller sign-off",
                    subtitle: offer.sellerID == store.currentUserID ? "Your contract signature" : "Seller contract signature",
                    signedAt: packet.sellerSignedAt
                )

                if packet.isFullySigned {
                    HighlightInformationCard(
                        title: "Sale complete",
                        message: "Both buyer and seller have signed the contract packet. This listing is now marked sold.",
                        supporting: "Issued \(shortDateString(packet.generatedAt))"
                    )
                } else if offer.status == .accepted {
                    HighlightInformationCard(
                        title: "Ready for signatures",
                        message: packet.summary,
                        supporting: packet.signedAt(for: store.currentUserID) == nil
                            ? "Your contract sign-off is now available."
                            : "Your sign-off is recorded. Waiting for the other side."
                    )
                } else {
                    HighlightInformationCard(
                        title: "Contract packet sent",
                        message: packet.summary,
                        supporting: "The seller needs to accept the offer before signing begins."
                    )
                }
            } else {
                HighlightInformationCard(
                    title: "Contract not sent yet",
                    message: "Once both sides choose their legal representative, the contract packet is sent to both parties in the secure conversation thread.",
                    supporting: "Current step: \(mySelection == nil ? "choose your legal representative" : "waiting for the other side to choose theirs")"
                )
            }

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Settlement checklist")
                    .font(.headline)

                Text("Track the shared legal, contract, and settlement milestones without leaving the sale workspace.")
                    .foregroundStyle(.secondary)

                SaleChecklistContent(items: offer.settlementChecklist)
            }

            HStack(spacing: 12) {
                Button(mySelection == nil ? "Choose my legal rep" : "Change my legal rep") {
                    legalSearchContext = LegalSearchContext(
                        offerID: offer.id,
                        role: actingRole
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(offer.contractPacket?.isFullySigned == true)

                if let packet = offer.contractPacket,
                   offer.status == .accepted,
                   packet.signedAt(for: store.currentUserID) == nil,
                   !packet.isFullySigned {
                    Button("Sign contract packet") {
                        handleContractSigning(listing: listing, offer: offer)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Open secure thread") {
                    openConversation(for: listing, offer: offer)
                }
                .buttonStyle(.bordered)
            }

            if !offer.invites.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Legal representative access")
                        .font(.headline)

                    Text("Share the workspace invite with the chosen conveyancer or solicitor so they can work from the current contract, rates, ID, and settlement documents.")
                        .foregroundStyle(.secondary)

                    ForEach(store.saleInvites(for: offer.id)) { invite in
                        SaleInviteRow(
                            invite: invite,
                            onShare: {
                                shareInviteContext = SaleInviteShareContext(
                                    listingID: listing.id,
                                    offerID: offer.id,
                                    role: invite.role,
                                    title: invite.role.title,
                                    shareMessage: invite.shareMessage
                                )
                            },
                            onRegenerate: {
                                handleSaleInviteManagement(
                                    listing: listing,
                                    offer: offer,
                                    invite: invite,
                                    action: .regenerate
                                )
                            },
                            onRevoke: {
                                handleSaleInviteManagement(
                                    listing: listing,
                                    offer: offer,
                                    invite: invite,
                                    action: .revoke
                                )
                            }
                        )
                    }
                }
            }

            if !offer.documents.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Shared sale documents")
                        .font(.headline)

                    Text("Contract, rates, ID, and settlement PDFs stay attached to this sale so both sides and their legal reps can work from the same latest documents.")
                        .foregroundStyle(.secondary)

                    ForEach(store.saleDocuments(for: offer.id)) { document in
                        SaleDocumentRow(document: document) {
                            handleDocumentPreview(listing: listing, offer: offer, document: document)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func inspectionCard(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspections")
                .font(.headline)

            ForEach(listing.inspectionSlots) { slot in
                VStack(alignment: .leading, spacing: 8) {
                    Text(dateRangeString(start: slot.startsAt, end: slot.endsAt))
                        .font(.subheadline.weight(.semibold))
                    Text(slot.note)
                        .foregroundStyle(.secondary)

                    if store.currentUser.role == .buyer {
                        Button(store.isInspectionPlanned(slotID: slot.id) ? "Remove from planner" : "Add to planner") {
                            store.toggleInspection(slotID: slot.id)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.panel)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func marketCard(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market and research")
                .font(.headline)

            AdaptiveTagGrid(minimum: 150) {
                StatPanel(
                    title: "Value estimate",
                    value: "\(currencyString(listing.marketPulse.valueEstimateLow)) - \(currencyString(listing.marketPulse.valueEstimateHigh))",
                    subtitle: "Modeled owner estimate"
                )
                StatPanel(
                    title: "Suburb median",
                    value: currencyString(listing.marketPulse.suburbMedian),
                    subtitle: "Current local median"
                )
                StatPanel(
                    title: "Demand",
                    value: "\(listing.marketPulse.buyerDemandScore)",
                    subtitle: "Buyer demand score"
                )
                StatPanel(
                    title: "Days on market",
                    value: "\(listing.marketPulse.averageDaysOnMarket)",
                    subtitle: "Average time to secure a buyer"
                )
            }

            HighlightInformationCard(
                title: listing.marketPulse.schoolInsight.catchmentName,
                message: "School catchment insight included because both market leaders surface school-aware discovery and local research.",
                supporting: "\(listing.marketPulse.schoolInsight.walkMinutes) min walk • score \(listing.marketPulse.schoolInsight.score)"
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func mapCard(for listing: PropertyListing) -> some View {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)

            Map(initialPosition: .region(region)) {
                Marker(listing.address.shortLine, coordinate: CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude))
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text(listing.address.fullLine)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func comparablesCard(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparable sales")
                .font(.headline)

            if listing.comparableSales.isEmpty {
                EmptyPanel(message: "Comparable sales will appear here as local data becomes available.")
            } else {
                ForEach(listing.comparableSales) { sale in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sale.address)
                                .font(.subheadline.weight(.semibold))
                            Text("\(sale.bedrooms) beds • Sold \(shortDateString(sale.soldAt))")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(currencyString(sale.soldPrice))
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BrandPalette.panel)
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }

    private func openConversation(for listing: PropertyListing, offer: OfferRecord? = nil) {
        guard let seller = store.user(id: listing.sellerID) else { return }

        let buyer: UserProfile?
        if let offer {
            buyer = store.user(id: offer.buyerID)
        } else if store.currentUser.role == .buyer {
            buyer = store.user(id: store.currentUserID)
        } else {
            buyer = nil
        }

        guard let buyer else { return }

        let thread = messaging.ensureConversation(listing: listing, buyer: buyer, seller: seller)
        onOpenMessages(thread.id)
        dismiss()
    }

    private func buyerOfferButtonTitle(for offer: OfferRecord?) -> String {
        guard let offer else { return "Make Offer" }

        switch offer.status {
        case .countered:
            return "Respond to Counteroffer"
        case .changesRequested:
            return "Send Updated Terms"
        case .accepted:
            return "Offer Accepted"
        case .underOffer:
            return "Update Offer"
        }
    }

    private func presentBuyerOfferComposer(using offer: OfferRecord?) {
        offerComposer = OfferComposerContext(
            mode: .buyer,
            offer: offer,
            amount: offer?.amount,
            conditions: offer?.conditions ?? "Subject to building and pest inspection."
        )
    }

    private func handleBuyerOfferSubmission(
        listing: PropertyListing,
        amount: Int,
        conditions: String
    ) {
        guard let buyer = store.user(id: store.currentUserID),
              let seller = store.user(id: listing.sellerID),
              let outcome = store.submitOffer(
                listingID: listing.id,
                buyerID: buyer.id,
                amount: amount,
                conditions: conditions
              ) else {
            notice = ListingNotice(message: "Could not send the offer right now.")
            return
        }

        let conversation = messaging.ensureConversation(listing: listing, buyer: buyer, seller: seller)
        messaging.sendOfferSummary(
            listing: listing,
            buyer: buyer,
            seller: seller,
            amount: amount,
            conditions: conditions
        )

        if let packet = outcome.contractPacket {
            messaging.sendContractPacket(
                listing: listing,
                offerID: outcome.offer.id,
                buyer: buyer,
                seller: seller,
                packet: packet,
                triggeredBy: buyer
            )
        }

        notice = ListingNotice(
            message: outcome.contractPacket == nil
                ? (outcome.isRevision ? "Offer updated and synced to the shared sale workspace." : "Offer sent securely to the seller.")
                : "Offer synced and the contract packet was refreshed in secure messages."
        )
        onOpenMessages(conversation.id)
        dismiss()
    }

    private func handleSellerOfferSubmission(
        listing: PropertyListing,
        offer: OfferRecord?,
        action: SellerOfferAction,
        amount: Int,
        conditions: String
    ) {
        guard let offer,
              let outcome = store.respondToOffer(
            offerID: offer.id,
            userID: store.currentUserID,
            action: action,
            amount: amount,
            conditions: conditions
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            notice = ListingNotice(message: "Could not send the seller response right now.")
            return
        }

        messaging.sendMessage(
            listing: listing,
            from: seller,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let packet = outcome.contractPacket {
            messaging.sendContractPacket(
                listing: listing,
                offerID: outcome.offer.id,
                buyer: buyer,
                seller: seller,
                packet: packet,
                triggeredBy: seller
            )
            notice = ListingNotice(message: "\(outcome.noticeMessage) Contract packet refreshed in secure messages.")
        } else {
            notice = ListingNotice(message: outcome.noticeMessage)
        }
    }

    private func handleContractSigning(
        listing: PropertyListing,
        offer: OfferRecord
    ) {
        guard let outcome = store.signContractPacket(
            offerID: offer.id,
            userID: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            notice = ListingNotice(message: "Could not record the contract sign-off right now.")
            return
        }

        let sender = store.currentUserID == buyer.id ? buyer : seller
        let recipient = sender.id == buyer.id ? seller : buyer

        messaging.sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: outcome.threadMessage,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: outcome.offer.id,
                checklistItemID: "contract-signatures"
            )
        )

        notice = ListingNotice(message: outcome.noticeMessage)
        resolveReminderIfMatching(
            offerID: outcome.offer.id,
            itemIDs: ["contract-signatures"],
            actionTitle: "Contract signed"
        )
    }

    private func handleSaleInviteManagement(
        listing: PropertyListing,
        offer: OfferRecord,
        invite: SaleWorkspaceInvite,
        action: SaleInviteManagementAction
    ) {
        guard let outcome = store.manageSaleInvite(
            offerID: offer.id,
            role: invite.role,
            action: action,
            triggeredBy: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            notice = ListingNotice(message: "Could not update the legal workspace invite right now.")
            return
        }

        let sender = store.currentUserID == buyer.id ? buyer : seller
        let recipient = sender.id == buyer.id ? seller : buyer

        messaging.sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: outcome.threadMessage,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: outcome.offer.id,
                checklistItemID: "workspace-invites"
            )
        )

        notice = ListingNotice(message: outcome.noticeMessage)
        resolveReminderIfMatching(
            offerID: outcome.offer.id,
            itemIDs: ["workspace-invites", "workspace-active"],
            actionTitle: "Invite updated"
        )
    }

    private func handleSaleInviteShare(
        listingID: UUID,
        offerID: UUID,
        role: LegalInviteRole
    ) {
        guard let listing = store.listing(id: listingID),
              let outcome = store.recordSaleInviteShare(
                offerID: offerID,
                role: role,
                triggeredBy: store.currentUserID
              ),
              let buyer = store.user(id: outcome.offer.buyerID),
              let seller = store.user(id: outcome.offer.sellerID) else {
            notice = ListingNotice(message: "Could not track the invite resend right now.")
            return
        }

        let sender = store.currentUserID == buyer.id ? buyer : seller
        let recipient = sender.id == buyer.id ? seller : buyer

        messaging.sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: outcome.threadMessage,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: outcome.offer.id,
                checklistItemID: "workspace-invites"
            )
        )

        notice = ListingNotice(message: outcome.noticeMessage)
        resolveReminderIfMatching(
            offerID: outcome.offer.id,
            itemIDs: ["workspace-invites", "workspace-active"],
            actionTitle: "Invite shared"
        )
    }

    private func handleDocumentPreview(
        listing: PropertyListing,
        offer: OfferRecord,
        document: SaleDocument
    ) {
        guard let buyer = store.user(id: offer.buyerID),
              let seller = store.user(id: offer.sellerID) else {
            notice = ListingNotice(message: "This sale document is not ready to open yet.")
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.render(
                document: document,
                listing: listing,
                offer: offer,
                buyer: buyer,
                seller: seller
            )
        } catch {
            notice = ListingNotice(message: "Could not prepare the PDF preview right now.")
        }
    }
}

private struct ConversationThreadView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    let threadID: UUID
    let onOpenSaleTask: (SaleReminderNavigationTarget) -> Void

    @State private var draft = ""

    var body: some View {
        if let thread = messaging.thread(id: threadID) {
            let listing = store.listing(id: thread.listingID)
            let currentUser = store.currentUser
            let counterpart = thread.participantIDs.first { $0 != currentUser.id }.flatMap { store.user(id: $0) }

            VStack(spacing: 0) {
                if let listing {
                    ConversationHeader(listing: listing, counterpart: counterpart, encryptionLabel: thread.encryptionLabel)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(thread.messages) { message in
                                MessageBubble(
                                    message: message,
                                    sender: store.user(id: message.senderID),
                                    isCurrentUser: message.senderID == currentUser.id,
                                    onOpenSaleTask: onOpenSaleTask
                                )
                                .id(message.id)
                            }
                        }
                        .padding(20)
                    }
                    .background(BrandPalette.background)
                    .onAppear {
                        proxy.scrollTo(thread.messages.last?.id, anchor: .bottom)
                    }
                }

                Divider()

                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Message buyer or seller", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button("Send") {
                        guard let listing,
                              let counterpart else { return }

                        _ = messaging.sendMessage(
                            listing: listing,
                            from: currentUser,
                            to: counterpart,
                            body: draft
                        )
                        draft = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(.white)
            }
            .navigationTitle(counterpart?.name ?? "Conversation")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            EmptyPanel(message: "Conversation unavailable.")
                .padding()
        }
    }
}

private struct SaveSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let filters: SearchFilters
    let onSave: (String) -> Void

    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name this search") {
                    TextField("Example: Paddington family homes", text: $title)
                }

                Section("Current filters") {
                    Text(filters.suburb.isEmpty ? "Any suburb" : filters.suburb)
                    Text("\(filters.minimumBedrooms)+ bedrooms")
                    Text(filters.maximumPrice.map(currencyString) ?? "Any price")
                    Text(filters.propertyTypes.isEmpty ? "Any property type" : filters.propertyTypes.map(\.title).joined(separator: ", "))
                }
            }
            .navigationTitle("Save Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct OfferSheet: View {
    @Environment(\.dismiss) private var dismiss

    let listing: PropertyListing
    let title: String
    let amountLabel: String
    let conditionsLabel: String
    let submitTitle: String
    let onSubmit: (Int, String) -> Void

    @State private var amountText: String
    @State private var conditions: String

    init(
        listing: PropertyListing,
        title: String,
        amountLabel: String,
        conditionsLabel: String,
        submitTitle: String,
        initialAmount: Int?,
        initialConditions: String,
        onSubmit: @escaping (Int, String) -> Void
    ) {
        self.listing = listing
        self.title = title
        self.amountLabel = amountLabel
        self.conditionsLabel = conditionsLabel
        self.submitTitle = submitTitle
        self.onSubmit = onSubmit
        _amountText = State(initialValue: initialAmount.map(String.init) ?? "")
        _conditions = State(initialValue: initialConditions)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    Text(listing.title)
                    Text(currencyString(listing.askingPrice))
                        .foregroundStyle(.secondary)
                }

                Section(title) {
                    TextField(amountLabel, text: $amountText)
                        .keyboardType(.numberPad)
                    TextEditor(text: $conditions)
                        .frame(minHeight: 120)
                    Text(conditionsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle) {
                        if let amount = Int(amountText.filter(\.isNumber)) {
                            onSubmit(amount, conditions)
                            dismiss()
                        }
                    }
                    .disabled(
                        Int(amountText.filter(\.isNumber)) == nil ||
                        conditions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

private struct LegalSearchSheet: View {
    @EnvironmentObject private var store: MarketplaceStore
    @Environment(\.dismiss) private var dismiss

    let listing: PropertyListing
    let actingRole: UserRole
    let currentSelection: LegalProfessional?
    let onSelect: (LegalProfessional) -> Void

    @State private var results: [LegalProfessional] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && results.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Searching local conveyancers and property lawyers near \(listing.address.suburb).")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HighlightInformationCard(
                                title: actingRole == .buyer ? "Buyer legal representative" : "Seller legal representative",
                                message: "Results are pulled through the backend from local Google listings when available, with an offline local directory fallback so the workflow still works in development.",
                                supporting: listing.address.fullLine
                            )

                            if let currentSelection {
                                LegalProfessionalResultCard(
                                    professional: currentSelection,
                                    isSelected: true,
                                    actionTitle: "Selected for this sale",
                                    onSelect: {}
                                )
                            }

                            if let errorMessage {
                                EmptyPanel(message: errorMessage)
                            }

                            if results.isEmpty {
                                EmptyPanel(message: "No nearby legal professionals were found for this suburb yet.")
                            } else {
                                ForEach(results.filter { $0.id != currentSelection?.id }) { professional in
                                    LegalProfessionalResultCard(
                                        professional: professional,
                                        isSelected: currentSelection?.id == professional.id,
                                        actionTitle: "Choose for this sale",
                                        onSelect: {
                                            onSelect(professional)
                                            dismiss()
                                        }
                                    )
                                }
                            }
                        }
                        .padding(20)
                    }
                    .background(BrandPalette.background.ignoresSafeArea())
                }
            }
            .navigationTitle("Legal Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refresh") {
                        Task { await loadResults() }
                    }
                }
            }
        }
        .task {
            await loadResults()
        }
    }

    @MainActor
    private func loadResults() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            results = try await store.searchLegalProfessionals(for: listing)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }

        isLoading = false
    }
}

private struct ReminderInviteManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    let invite: SaleWorkspaceInvite
    let prefersRegeneration: Bool
    let onShare: () -> Void
    let onRegenerate: () -> Void
    let onRevoke: () -> Void

    private var primaryButtonTitle: String {
        if prefersRegeneration {
            return "Regenerate invite"
        } else {
            return invite.hasBeenShared ? "Resend invite" : "Share invite"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HighlightInformationCard(
                        title: "Legal workspace invite",
                        message: invite.isUnavailable
                            ? "This invite needs attention before the legal rep can open the workspace again."
                            : "Use this screen to resend, regenerate, or revoke the legal workspace access for the selected representative.",
                        supporting: invite.professionalName
                    )

                    SaleInviteRow(
                        invite: invite,
                        onShare: {
                            onShare()
                        },
                        onRegenerate: {
                            onRegenerate()
                        },
                        onRevoke: {
                            onRevoke()
                        }
                    )

                    Button(primaryButtonTitle) {
                        if prefersRegeneration {
                            onRegenerate()
                        } else {
                            onShare()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!prefersRegeneration && invite.isUnavailable)

                    if !invite.isRevoked {
                        Button("Revoke invite") {
                            onRevoke()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Invite access")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct ContractSigningTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    let offer: OfferRecord
    let packet: ContractPacket
    let currentUserID: UUID
    let onSign: () -> Void
    let onOpenMessages: () -> Void

    private var canCurrentUserSign: Bool {
        offer.status == .accepted &&
            packet.signedAt(for: currentUserID) == nil &&
            !packet.isFullySigned
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HighlightInformationCard(
                        title: packet.isFullySigned ? "Sale complete" : "Contract signing",
                        message: packet.isFullySigned
                            ? "Both sides have signed the contract packet and the listing is now marked sold."
                            : packet.summary,
                        supporting: "Issued \(shortDateString(packet.generatedAt))"
                    )

                    ContractSigningStatusRow(
                        title: "Buyer sign-off",
                        subtitle: "Contract signature status",
                        signedAt: packet.buyerSignedAt
                    )

                    ContractSigningStatusRow(
                        title: "Seller sign-off",
                        subtitle: "Contract signature status",
                        signedAt: packet.sellerSignedAt
                    )

                    if canCurrentUserSign {
                        Button("Sign contract packet") {
                            onSign()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Open secure thread") {
                            onOpenMessages()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Contract signing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct CreateListingSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ListingDraft()
    let onCreate: (ListingDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Overview") {
                    TextField("Listing title", text: $draft.title)
                    TextField("Headline", text: $draft.headline)
                    TextField("Summary", text: $draft.summary, axis: .vertical)
                }

                Section("Address") {
                    TextField("Street", text: $draft.street)
                    TextField("Suburb", text: $draft.suburb)
                    TextField("State", text: $draft.state)
                    TextField("Postcode", text: $draft.postcode)
                }

                Section("Property details") {
                    Picker("Property type", selection: $draft.propertyType) {
                        ForEach(PropertyType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Asking price", text: $draft.priceText)
                        .keyboardType(.numberPad)
                    Stepper("Bedrooms: \(draft.bedrooms)", value: $draft.bedrooms, in: 1...8)
                    Stepper("Bathrooms: \(draft.bathrooms)", value: $draft.bathrooms, in: 1...6)
                    Stepper("Parking: \(draft.parkingSpaces)", value: $draft.parkingSpaces, in: 0...6)
                    TextField("Land size", text: $draft.landSizeText)
                    TextField("Features (comma separated)", text: $draft.featuresText)
                }
            }
            .navigationTitle("Create Listing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        onCreate(draft)
                        dismiss()
                    }
                    .disabled(!draft.canSubmit)
                }
            }
        }
    }
}

private struct LegalProfessionalResultCard: View {
    let professional: LegalProfessional
    let isSelected: Bool
    let actionTitle: String
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(professional.name)
                        .font(.headline)
                    Text(professional.primarySpecialty)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandPalette.teal)
                    Text(professional.address)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let rating = professional.rating {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(rating.formatted(.number.precision(.fractionLength(1))))
                            .font(.headline.weight(.bold))
                        Text(professional.reviewCount.map { "\($0) reviews" } ?? "Local listing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AdaptiveTagGrid(minimum: 140) {
                ForEach(professional.specialties, id: \.self) { specialty in
                    InfoPill(label: specialty)
                }
                InfoPill(label: professional.sourceLine)
            }

            Text(professional.searchSummary)
                .foregroundStyle(.secondary)

            if let phoneNumber = professional.phoneNumber {
                Label(phoneNumber, systemImage: "phone.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if isSelected {
                    Button("Selected") {}
                        .buttonStyle(.bordered)
                        .disabled(true)
                } else {
                    Button(actionTitle) {
                        onSelect()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let websiteURL = professional.websiteURL {
                    Link("Website", destination: websiteURL)
                        .buttonStyle(.bordered)
                }

                if let mapsURL = professional.mapsURL {
                    Link("Maps", destination: mapsURL)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct ListingCard: View {
    let listing: PropertyListing
    let seller: UserProfile?
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ListingHero(listing: listing, compact: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(listing.address.fullLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? Color.red : .secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }

                Text(currencyString(listing.askingPrice))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(listing.primaryFactLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let seller {
                    Text("Private seller: \(seller.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(listing.headline)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    InfoPill(label: listing.propertyType.title)
                    InfoPill(label: "Demand \(listing.marketPulse.buyerDemandScore)")
                    InfoPill(label: listing.marketPulse.schoolInsight.catchmentName)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
    }
}

private struct FeaturedListingCard: View {
    let listing: PropertyListing
    let seller: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ListingHero(listing: listing, compact: true)
                .frame(width: 320)

            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(currencyString(listing.askingPrice))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(listing.address.suburb)
                    .foregroundStyle(.secondary)
                if let seller {
                    Text("Sold privately by \(seller.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 320, alignment: .leading)
    }
}

private struct SellerListingCard: View {
    let listing: PropertyListing
    let offerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.headline)
                    Text(listing.address.fullLine)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(listing.status.title)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(BrandPalette.selection)
                    )
            }

            HStack(spacing: 10) {
                InfoPill(label: currencyString(listing.askingPrice))
                InfoPill(label: "\(offerCount) offers")
                InfoPill(label: "Demand \(listing.marketPulse.buyerDemandScore)")
            }

            Text(listing.headline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct SavedSearchCard: View {
    let search: SavedSearch
    let onToggleAlerts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(search.title)
                        .font(.headline)
                    Text(search.suburb.isEmpty ? "Any suburb" : search.suburb)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(search.alertsEnabled ? "Alerts On" : "Alerts Off") {
                    onToggleAlerts()
                }
                .buttonStyle(.bordered)
            }

            Text(
                "\(currencyString(search.minimumPrice)) - \(currencyString(search.maximumPrice)) • \(search.minimumBedrooms)+ beds"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(search.propertyTypes.isEmpty ? "Any property type" : search.propertyTypes.map(\.title).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct InspectionPlannerCard: View {
    let listing: PropertyListing
    let slot: InspectionSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(listing.title)
                .font(.headline)
            Text(dateRangeString(start: slot.startsAt, end: slot.endsAt))
                .font(.subheadline.weight(.semibold))
            Text(slot.note)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct PersonaCard: View {
    let user: UserProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isSelected ? BrandPalette.navy : Color.white)
                    .frame(width: 52, height: 52)
                Text(user.initials)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                Text("\(user.role.title) • \(user.suburb)")
                    .foregroundStyle(.secondary)
                Text(user.verificationNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? BrandPalette.selection : .white)
        )
    }
}

private struct ConversationRow: View {
    let thread: EncryptedConversation
    let listing: PropertyListing?
    let currentUserID: UUID
    let counterpart: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(counterpart?.name ?? "Conversation")
                    .font(.headline)
                Spacer()
                Text(relativeDateString(thread.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(listing?.title ?? "Property enquiry")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(thread.lastMessagePreview)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

private struct LegalSelectionStatusRow: View {
    let title: String
    let subtitle: String
    let selection: LegalSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selection {
                Text(selection.professional.name)
                    .font(.headline)
                Text(selection.professional.primarySpecialty)
                    .foregroundStyle(BrandPalette.teal)
                Text(selection.professional.address)
                    .foregroundStyle(.secondary)
                Text("Chosen \(relativeDateString(selection.selectedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not selected yet")
                    .font(.headline)
                Text("This side still needs to choose a conveyancer, solicitor, or property lawyer.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct ContractSigningStatusRow: View {
    let title: String
    let subtitle: String
    let signedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let signedAt {
                Text("Signed")
                    .font(.headline)
                Text("Recorded \(relativeDateString(signedAt))")
                    .foregroundStyle(BrandPalette.teal)
            } else {
                Text("Waiting for signature")
                    .font(.headline)
                Text("This party still needs to review and sign the contract packet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct SaleDocumentRow: View {
    let document: SaleDocument
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: document.kind.symbolName)
                    .font(.headline)
                    .foregroundStyle(BrandPalette.navy)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(BrandPalette.panel)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.subheadline.weight(.semibold))
                    Text(document.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(document.fileName) • Added \(shortDateString(document.createdAt)) by \(document.uploadedByName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Button("Preview PDF", action: onOpen)
                .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct SaleInviteRow: View {
    let invite: SaleWorkspaceInvite
    let onShare: () -> Void
    let onRegenerate: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: invite.role.symbolName)
                    .font(.headline)
                    .foregroundStyle(BrandPalette.navy)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(BrandPalette.panel)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.role.title)
                        .font(.subheadline.weight(.semibold))
                    Text(invite.professionalName)
                        .font(.headline)
                    Text(invite.professionalSpecialty)
                        .foregroundStyle(BrandPalette.teal)
                    Text("Invite code \(invite.shareCode) • Created \(shortDateString(invite.createdAt)) by \(invite.generatedByName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let revokedAt = invite.revokedAt {
                        Text("Revoked \(shortDateString(revokedAt))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    } else if invite.isExpired {
                        Text("Expired \(shortDateString(invite.expiresAt))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    } else {
                        Text("Valid until \(shortDateString(invite.expiresAt))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let acknowledgedAt = invite.acknowledgedAt {
                        Text("Acknowledged \(shortDateString(acknowledgedAt))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandPalette.teal)
                    }
                    if let lastSharedAt = invite.lastSharedAt {
                        Text("Last sent \(relativeDateString(lastSharedAt)) • \(invite.shareCount)x shared")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not yet sent from the sale workspace")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let activatedAt = invite.activatedAt {
                        Text("Opened \(relativeDateString(activatedAt))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandPalette.teal)
                    } else if invite.needsFollowUp {
                        Text("Follow up recommended. It has not been opened within 48 hours.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    onShare()
                } label: {
                    Label("Resend invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(invite.isUnavailable)

                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    onRevoke()
                } label: {
                    Label("Revoke", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(invite.isRevoked)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct SaleUpdatesCard: View {
    @EnvironmentObject private var store: MarketplaceStore

    let offer: OfferRecord

    private var currentViewerID: String? {
        if let session = store.legalWorkspaceSession, session.offerID == offer.id {
            return SaleTaskSnapshotSyncStore.viewerID(forInvite: session.inviteID)
        }

        if store.isAuthenticated {
            return SaleTaskSnapshotSyncStore.viewerID(forUser: store.currentUserID)
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Secure sale updates")
                .font(.subheadline.weight(.semibold))

            ForEach(offer.updates.prefix(6)) { update in
                VStack(alignment: .leading, spacing: 6) {
                    SaleUpdateBadge(
                        update: update,
                        snapshot: update.checklistItemID.flatMap { offer.liveTaskSnapshot(for: $0) },
                        taskID: update.checklistItemID.flatMap { offer.taskSnapshotID(for: $0) },
                        audience: offer.taskSnapshotAudienceMembers
                    )
                    Text(update.title)
                        .font(.subheadline.weight(.semibold))
                    Text(update.body)
                        .foregroundStyle(.secondary)
                    if let checklistItemID = update.checklistItemID,
                       let liveSnapshot = offer.liveTaskSnapshot(for: checklistItemID) {
                        SaleTaskAudienceStatusRow(
                            snapshot: liveSnapshot,
                            messageID: nil,
                            taskID: offer.taskSnapshotID(for: checklistItemID),
                            audience: offer.taskSnapshotAudienceMembers,
                            currentViewerID: currentViewerID,
                            markAsSeenOnAppear: true
                        )
                    }
                    Text(relativeDateString(update.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.panel)
                )
            }
        }
    }
}

private struct SaleUpdateBadge: View {
    let update: SaleUpdateMessage
    var snapshot: SaleTaskLiveSnapshot? = nil
    var taskID: String? = nil
    var audience: [SaleTaskSnapshotAudienceMember] = []

    private var fillColor: Color {
        update.kind == .reminder ? Color.orange.opacity(0.14) : BrandPalette.teal.opacity(0.14)
    }

    private var tintColor: Color {
        update.kind == .reminder ? .orange : BrandPalette.teal
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: update.kind.symbolName)
                Text(update.kind.badgeTitle)
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor)
            )
            .foregroundStyle(tintColor)

            if let snapshot, !audience.isEmpty {
                SaleTaskAudienceCompactBadge(
                    snapshot: snapshot,
                    messageID: nil,
                    taskID: taskID,
                    audience: audience
                )
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ConversationHeader: View {
    let listing: PropertyListing
    let counterpart: UserProfile?
    let encryptionLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                Text(listing.title)
                    .font(.headline)
                Text(counterpart.map { "Talking with \($0.name)" } ?? "Secure property conversation")
                    .foregroundStyle(.secondary)
                Label(encryptionLabel, systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }
}

private struct MessageBubble: View {
    private struct SaleTaskTheme {
        let accent: Color
        let background: Color
        let badgeBackground: Color
        let badgeText: Color
        let stageLabel: String
    }

    private struct SaleTaskStatus {
        let label: String
        let symbolName: String
        let tint: Color
        let background: Color
    }

    private struct SaleTaskLiveStyle {
        let tint: Color
        let background: Color
        let symbolName: String
    }

    private struct AnimatedSaleTaskLiveSnapshotBadge: View {
        let snapshot: SaleTaskLiveSnapshot
        let style: SaleTaskLiveStyle
        let messageID: String
        let viewerID: String?
        let taskID: String?

        @EnvironmentObject private var taskSnapshots: SaleTaskSnapshotSyncStore

        @State private var highlightChange = false

        private struct AnimationProfile {
            let scale: CGFloat
            let strokeOpacity: Double
            let shadowOpacity: Double
            let shadowRadius: CGFloat
            let shadowYOffset: CGFloat
            let highlightDuration: Double
            let highlightHoldMilliseconds: Int
            let settleResponse: Double
            let settleDamping: Double
        }

        private var animationKey: String {
            "\(snapshot.tone.rawValue)|\(snapshot.summary)"
        }

        private var shouldEmphasizeUrgentSnapshot: Bool {
            taskSnapshots.shouldEmphasizeUrgentSnapshot(
                snapshot,
                messageID: messageID,
                viewerID: viewerID,
                taskID: taskID
            )
        }

        private var animationProfile: AnimationProfile {
            if shouldEmphasizeUrgentSnapshot {
                return AnimationProfile(
                    scale: 1.045,
                    strokeOpacity: 0.38,
                    shadowOpacity: 0.24,
                    shadowRadius: 14,
                    shadowYOffset: 6,
                    highlightDuration: 0.16,
                    highlightHoldMilliseconds: 420,
                    settleResponse: 0.38,
                    settleDamping: 0.76
                )
            }

            if snapshot.tone == .warning || isUrgentSnapshot {
                return AnimationProfile(
                    scale: 1.03,
                    strokeOpacity: 0.28,
                    shadowOpacity: 0.2,
                    shadowRadius: 11,
                    shadowYOffset: 5,
                    highlightDuration: 0.17,
                    highlightHoldMilliseconds: 360,
                    settleResponse: 0.34,
                    settleDamping: 0.8
                )
            }

            return AnimationProfile(
                scale: 1.018,
                strokeOpacity: 0.18,
                shadowOpacity: 0.14,
                shadowRadius: 8,
                shadowYOffset: 3,
                highlightDuration: 0.18,
                highlightHoldMilliseconds: 280,
                settleResponse: 0.3,
                settleDamping: 0.84
            )
        }

        private var isUrgentSnapshot: Bool {
            let normalizedSummary = snapshot.summary.lowercased()
            return snapshot.tone == .critical
                || normalizedSummary.contains("overdue")
                || normalizedSummary.contains("follow-up")
                || normalizedSummary.contains("follow up")
        }

        @MainActor
        private func triggerUrgentFeedback() {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

            if UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Urgent sale update. \(snapshot.summary)"
                )
            }
        }

        var body: some View {
            Label(snapshot.summary, systemImage: style.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.tint)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(style.background)
                )
                .scaleEffect(highlightChange ? animationProfile.scale : 1.0)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style.tint.opacity(highlightChange ? animationProfile.strokeOpacity : 0), lineWidth: 1)
                }
                .shadow(
                    color: style.tint.opacity(highlightChange ? animationProfile.shadowOpacity : 0),
                    radius: highlightChange ? animationProfile.shadowRadius : 0,
                    y: highlightChange ? animationProfile.shadowYOffset : 0
                )
                .contentTransition(.opacity)
                .task(id: animationKey) {
                    let shouldTriggerUrgentFeedback = shouldEmphasizeUrgentSnapshot
                    highlightChange = false

                    if isUrgentSnapshot && !shouldTriggerUrgentFeedback {
                        return
                    }

                    if shouldTriggerUrgentFeedback {
                        triggerUrgentFeedback()
                    }
                    withAnimation(.easeOut(duration: animationProfile.highlightDuration)) {
                        highlightChange = true
                    }
                    try? await Task.sleep(for: .milliseconds(animationProfile.highlightHoldMilliseconds))
                    withAnimation(.spring(response: animationProfile.settleResponse, dampingFraction: animationProfile.settleDamping)) {
                        highlightChange = false
                    }
                    if shouldTriggerUrgentFeedback {
                        taskSnapshots.markUrgentSnapshotSeen(
                            snapshot,
                            messageID: messageID,
                            viewerID: viewerID,
                            taskID: taskID
                        )
                    }
                }
        }
    }

    @EnvironmentObject private var store: MarketplaceStore

    let message: EncryptedMessage
    let sender: UserProfile?
    let isCurrentUser: Bool
    let onOpenSaleTask: (SaleReminderNavigationTarget) -> Void

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 6) {
                if let saleTaskTarget = message.saleTaskTarget, message.isSystem {
                    saleTaskCard(for: saleTaskTarget)
                } else {
                    if !message.isSystem {
                        Text(sender?.name ?? "Unknown")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(message.body)
                        .foregroundStyle(messageTextColor)

                    Text(timeString(message.sentAt))
                        .font(.caption2)
                        .foregroundStyle(message.isSystem ? .secondary : (isCurrentUser ? Color.white.opacity(0.8) : .secondary))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bubbleColor)
            )

            if !isCurrentUser { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private func saleTaskCard(for target: SaleReminderNavigationTarget) -> some View {
        let theme = saleTaskTheme(for: target)
        let status = saleTaskStatus(for: target)
        let relatedOffer = store.offer(id: target.offerID)
        let taskSnapshotID = relatedOffer?.taskSnapshotID(for: target.checklistItemID)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(theme.stageLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.badgeText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(theme.badgeBackground)
                    )

                if let relatedOffer,
                   let liveSnapshot = liveTaskSnapshot(for: target, now: .now) {
                    SaleTaskAudienceCompactBadge(
                        snapshot: liveSnapshot,
                        messageID: message.id.uuidString,
                        taskID: taskSnapshotID,
                        audience: relatedOffer.taskSnapshotAudienceMembers
                    )
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(theme.accent.opacity(0.16))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: saleTaskSymbolName(for: target))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(saleTaskTitle(for: target))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)

                    taskStatusBadge(status)

                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        if let liveSnapshot = liveTaskSnapshot(for: target, now: context.date) {
                            taskLiveSnapshotBadge(
                                liveSnapshot,
                                messageID: message.id.uuidString,
                                viewerID: taskSnapshotViewerID,
                                taskID: taskSnapshotID
                            )

                            if let relatedOffer {
                                SaleTaskAudienceStatusRow(
                                    snapshot: liveSnapshot,
                                    messageID: message.id.uuidString,
                                    taskID: taskSnapshotID,
                                    audience: relatedOffer.taskSnapshotAudienceMembers,
                                    currentViewerID: taskSnapshotViewerID
                                )
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(messageDetailLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(theme.accent.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)

                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Text(timeString(message.sentAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(saleTaskButtonTitle(for: target)) {
                    onOpenSaleTask(target)
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.accent)
            }
        }
    }

    @ViewBuilder
    private func taskStatusBadge(_ status: SaleTaskStatus) -> some View {
        Label(status.label, systemImage: status.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(status.background)
            )
    }

    @ViewBuilder
    private func taskLiveSnapshotBadge(
        _ snapshot: SaleTaskLiveSnapshot,
        messageID: String,
        viewerID: String?,
        taskID: String?
    ) -> some View {
        let style = liveTaskStyle(for: snapshot)

        AnimatedSaleTaskLiveSnapshotBadge(
            snapshot: snapshot,
            style: style,
            messageID: messageID,
            viewerID: viewerID,
            taskID: taskID
        )
    }

    private var taskSnapshotViewerID: String? {
        if store.isAuthenticated {
            return SaleTaskSnapshotSyncStore.viewerID(forUser: store.currentUserID)
        }

        if let session = store.legalWorkspaceSession {
            return SaleTaskSnapshotSyncStore.viewerID(forInvite: session.inviteID)
        }

        return nil
    }

    private var messageDetailLines: [String] {
        message.body
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var bubbleColor: Color {
        if message.isSystem, let saleTaskTarget = message.saleTaskTarget {
            return saleTaskTheme(for: saleTaskTarget).background
        }

        if message.isSystem {
            return BrandPalette.pill
        }

        return isCurrentUser ? BrandPalette.navy : .white
    }

    private var messageTextColor: Color {
        if message.isSystem {
            return .secondary
        }

        return isCurrentUser ? .white : .primary
    }

    private func saleTaskTheme(for target: SaleReminderNavigationTarget) -> SaleTaskTheme {
        switch target.checklistItemID {
        case "buyer-representative", "seller-representative":
            SaleTaskTheme(
                accent: BrandPalette.teal,
                background: Color(red: 0.90, green: 0.97, blue: 0.95),
                badgeBackground: BrandPalette.teal.opacity(0.16),
                badgeText: BrandPalette.teal,
                stageLabel: "LEGAL SETUP"
            )
        case "contract-packet":
            SaleTaskTheme(
                accent: BrandPalette.navy,
                background: Color(red: 0.92, green: 0.96, blue: 0.99),
                badgeBackground: BrandPalette.navy.opacity(0.14),
                badgeText: BrandPalette.navy,
                stageLabel: "CONTRACT ISSUED"
            )
        case "workspace-invites":
            SaleTaskTheme(
                accent: BrandPalette.gold,
                background: Color(red: 1.0, green: 0.97, blue: 0.90),
                badgeBackground: BrandPalette.gold.opacity(0.22),
                badgeText: Color(red: 0.55, green: 0.38, blue: 0.05),
                stageLabel: "INVITE DELIVERY"
            )
        case "workspace-active":
            SaleTaskTheme(
                accent: BrandPalette.sky,
                background: Color(red: 0.92, green: 0.97, blue: 1.0),
                badgeBackground: BrandPalette.sky.opacity(0.22),
                badgeText: BrandPalette.navy,
                stageLabel: "WORKSPACE LIVE"
            )
        case "legal-review-pack":
            SaleTaskTheme(
                accent: BrandPalette.coral,
                background: Color(red: 1.0, green: 0.94, blue: 0.93),
                badgeBackground: BrandPalette.coral.opacity(0.18),
                badgeText: Color(red: 0.68, green: 0.22, blue: 0.20),
                stageLabel: "LEGAL REVIEW"
            )
        case "contract-signatures":
            SaleTaskTheme(
                accent: BrandPalette.gold,
                background: Color(red: 1.0, green: 0.96, blue: 0.88),
                badgeBackground: BrandPalette.gold.opacity(0.24),
                badgeText: Color(red: 0.55, green: 0.38, blue: 0.05),
                stageLabel: "SIGNING"
            )
        case "settlement-statement":
            SaleTaskTheme(
                accent: BrandPalette.teal,
                background: Color(red: 0.91, green: 0.98, blue: 0.95),
                badgeBackground: BrandPalette.teal.opacity(0.16),
                badgeText: BrandPalette.teal,
                stageLabel: "SETTLEMENT"
            )
        default:
            SaleTaskTheme(
                accent: BrandPalette.navy,
                background: BrandPalette.pill,
                badgeBackground: BrandPalette.navy.opacity(0.14),
                badgeText: BrandPalette.navy,
                stageLabel: "SALE TASK"
            )
        }
    }

    private func liveTaskSnapshot(for target: SaleReminderNavigationTarget, now: Date) -> SaleTaskLiveSnapshot? {
        store.offer(id: target.offerID)?.liveTaskSnapshot(for: target.checklistItemID, now: now)
    }

    private func liveTaskStyle(for snapshot: SaleTaskLiveSnapshot) -> SaleTaskLiveStyle {
        switch snapshot.tone {
        case .info:
            return SaleTaskLiveStyle(
                tint: BrandPalette.navy,
                background: BrandPalette.navy.opacity(0.10),
                symbolName: "scope"
            )
        case .warning:
            return SaleTaskLiveStyle(
                tint: BrandPalette.gold,
                background: BrandPalette.gold.opacity(0.20),
                symbolName: "exclamationmark.triangle.fill"
            )
        case .critical:
            return SaleTaskLiveStyle(
                tint: BrandPalette.coral,
                background: BrandPalette.coral.opacity(0.15),
                symbolName: "flame.fill"
            )
        case .success:
            return SaleTaskLiveStyle(
                tint: BrandPalette.teal,
                background: BrandPalette.teal.opacity(0.16),
                symbolName: "checkmark.circle.fill"
            )
        }
    }

    private func saleTaskStatus(for target: SaleReminderNavigationTarget) -> SaleTaskStatus {
        let normalizedBody = message.body.lowercased()

        func containsAny(_ fragments: [String]) -> Bool {
            fragments.contains { normalizedBody.contains($0) }
        }

        if containsAny(["revoked", "expired", "no longer valid", "can no longer open"]) {
            return SaleTaskStatus(
                label: "Action needed",
                symbolName: "xmark.octagon.fill",
                tint: BrandPalette.coral,
                background: BrandPalette.coral.opacity(0.16)
            )
        }

        if containsAny(["snoozed follow-up"]) {
            return SaleTaskStatus(
                label: "Snoozed",
                symbolName: "clock.fill",
                tint: BrandPalette.navy,
                background: BrandPalette.sky.opacity(0.22)
            )
        }

        if containsAny(["completed follow-up"]) {
            return SaleTaskStatus(
                label: "Task cleared",
                symbolName: "checkmark.circle.fill",
                tint: BrandPalette.teal,
                background: BrandPalette.teal.opacity(0.16)
            )
        }

        switch target.checklistItemID {
        case "buyer-representative", "seller-representative":
            if containsAny(["selected", "chosen"]) {
                return SaleTaskStatus(
                    label: "Representative set",
                    symbolName: "checkmark.circle.fill",
                    tint: BrandPalette.teal,
                    background: BrandPalette.teal.opacity(0.16)
                )
            }

            return SaleTaskStatus(
                label: "Needs selection",
                symbolName: "hourglass.circle.fill",
                tint: BrandPalette.gold,
                background: BrandPalette.gold.opacity(0.20)
            )
        case "contract-packet":
            if containsAny(["refreshed", "updated"]) {
                return SaleTaskStatus(
                    label: "Packet refreshed",
                    symbolName: "arrow.clockwise.circle.fill",
                    tint: BrandPalette.sky,
                    background: BrandPalette.sky.opacity(0.22)
                )
            }

            return SaleTaskStatus(
                label: "Ready to review",
                symbolName: "doc.text.fill",
                tint: BrandPalette.navy,
                background: BrandPalette.navy.opacity(0.10)
            )
        case "workspace-invites":
            if containsAny(["follow up", "not been opened within 48 hours"]) {
                return SaleTaskStatus(
                    label: "Follow up needed",
                    symbolName: "exclamationmark.triangle.fill",
                    tint: BrandPalette.gold,
                    background: BrandPalette.gold.opacity(0.24)
                )
            }

            if containsAny(["resent", "shared"]) {
                return SaleTaskStatus(
                    label: "Awaiting open",
                    symbolName: "clock.fill",
                    tint: BrandPalette.gold,
                    background: BrandPalette.gold.opacity(0.18)
                )
            }

            if containsAny(["opened", "activated"]) {
                return SaleTaskStatus(
                    label: "Invite opened",
                    symbolName: "checkmark.circle.fill",
                    tint: BrandPalette.teal,
                    background: BrandPalette.teal.opacity(0.16)
                )
            }

            return SaleTaskStatus(
                label: "Invite ready",
                symbolName: "paperplane.fill",
                tint: BrandPalette.gold,
                background: BrandPalette.gold.opacity(0.18)
            )
        case "workspace-active":
            if containsAny(["acknowledged", "opened", "started reviewing"]) {
                return SaleTaskStatus(
                    label: "Workspace live",
                    symbolName: "checkmark.circle.fill",
                    tint: BrandPalette.teal,
                    background: BrandPalette.teal.opacity(0.16)
                )
            }

            return SaleTaskStatus(
                label: "Awaiting first open",
                symbolName: "clock.fill",
                tint: BrandPalette.sky,
                background: BrandPalette.sky.opacity(0.20)
            )
        case "legal-review-pack":
            if containsAny(["uploaded", "reviewed", "settlement adjustment"]) {
                return SaleTaskStatus(
                    label: "Review returned",
                    symbolName: "checkmark.circle.fill",
                    tint: BrandPalette.coral,
                    background: BrandPalette.coral.opacity(0.16)
                )
            }

            return SaleTaskStatus(
                label: "Review pending",
                symbolName: "hourglass.circle.fill",
                tint: BrandPalette.coral,
                background: BrandPalette.coral.opacity(0.12)
            )
        case "contract-signatures":
            if containsAny(["both sides are now signed", "both buyer and seller have signed", "listing is now marked sold"]) {
                return SaleTaskStatus(
                    label: "Fully signed",
                    symbolName: "checkmark.seal.fill",
                    tint: BrandPalette.teal,
                    background: BrandPalette.teal.opacity(0.16)
                )
            }

            if containsAny(["signed the contract packet"]) {
                return SaleTaskStatus(
                    label: "Awaiting countersign",
                    symbolName: "hourglass.circle.fill",
                    tint: BrandPalette.gold,
                    background: BrandPalette.gold.opacity(0.20)
                )
            }

            return SaleTaskStatus(
                label: "Signatures needed",
                symbolName: "exclamationmark.triangle.fill",
                tint: BrandPalette.gold,
                background: BrandPalette.gold.opacity(0.24)
            )
        case "settlement-statement":
            if containsAny(["ready", "uploaded", "shared"]) {
                return SaleTaskStatus(
                    label: "Ready to settle",
                    symbolName: "checkmark.circle.fill",
                    tint: BrandPalette.teal,
                    background: BrandPalette.teal.opacity(0.16)
                )
            }

            return SaleTaskStatus(
                label: "Settlement next",
                symbolName: "clock.fill",
                tint: BrandPalette.navy,
                background: BrandPalette.navy.opacity(0.10)
            )
        default:
            return SaleTaskStatus(
                label: "In progress",
                symbolName: "checklist",
                tint: BrandPalette.navy,
                background: BrandPalette.navy.opacity(0.10)
            )
        }
    }

    private func saleTaskTitle(for target: SaleReminderNavigationTarget) -> String {
        switch target.checklistItemID {
        case "buyer-representative":
            "Buyer legal representative"
        case "seller-representative":
            "Seller legal representative"
        case "contract-packet":
            "Contract packet"
        case "workspace-invites":
            "Legal workspace invite"
        case "workspace-active":
            "Legal workspace activity"
        case "legal-review-pack":
            "Legal review pack"
        case "contract-signatures":
            "Contract signing"
        case "settlement-statement":
            "Settlement statement"
        default:
            "Sale task"
        }
    }

    private func saleTaskSymbolName(for target: SaleReminderNavigationTarget) -> String {
        switch target.checklistItemID {
        case "buyer-representative", "seller-representative":
            "person.crop.circle.badge.checkmark"
        case "contract-packet":
            "doc.text.fill"
        case "workspace-invites":
            "paperplane.fill"
        case "workspace-active":
            "lock.open.fill"
        case "legal-review-pack":
            "doc.badge.gearshape"
        case "contract-signatures":
            "signature"
        case "settlement-statement":
            "doc.plaintext"
        default:
            "checklist"
        }
    }

    private func saleTaskButtonTitle(for target: SaleReminderNavigationTarget) -> String {
        switch target.checklistItemID {
        case "buyer-representative":
            "Choose Buyer Legal Rep"
        case "seller-representative":
            "Choose Seller Legal Rep"
        case "contract-packet":
            "Open Contract Packet"
        case "workspace-invites":
            "Open Invite Step"
        case "workspace-active":
            "Open Legal Workspace"
        case "legal-review-pack":
            "Open Legal Review"
        case "contract-signatures":
            "Open Contract Signing"
        case "settlement-statement":
            "Open Settlement Statement"
        default:
            "Open Sale Task"
        }
    }
}

private struct ListingHero: View {
    let listing: PropertyListing
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: paletteColors(for: listing.palette),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: compact ? 180 : 240)

            VStack(alignment: .leading, spacing: 8) {
                Text(listing.propertyType.title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))

                Text(listing.title)
                    .font(compact ? .title3.weight(.bold) : .largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(listing.address.shortLine)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(22)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                Text("REAL O WHO")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BrandPalette.navy)
                    .tracking(1.1)
            }
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BrandLockup: View {
    var inverse = false

    var body: some View {
        HStack(spacing: 12) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Real O Who")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(inverse ? .white : BrandPalette.navy)

                Text("Private property. More money stays with you.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(inverse ? Color.white.opacity(0.82) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct HighlightInformationCard: View {
    let title: String
    let message: String
    let supporting: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            Text(supporting)
                .font(.subheadline.weight(.semibold))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct FeatureTile: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.9))
        )
    }
}

private struct FilterPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
            )
    }
}

private struct SelectableChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? BrandPalette.teal : Color.white)
            )
    }
}

private struct InfoPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(BrandPalette.pill)
            )
    }
}

private struct StatPanel: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct EmptyPanel: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
            )
    }
}

private struct LinkRow: View {
    let title: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
            )
        }
    }
}

private struct AdaptiveTagGrid<Content: View>: View {
    let minimum: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimum), spacing: 10)],
            alignment: .leading,
            spacing: 10,
            content: content
        )
    }
}

private struct ListingNotice: Identifiable {
    let id = UUID()
    let message: String
}

private enum OfferComposerMode {
    case buyer
    case seller(SellerOfferAction)

    var title: String {
        switch self {
        case .buyer:
            return "Update Offer"
        case let .seller(action):
            switch action {
            case .accept:
                return "Accept Offer"
            case .requestChanges:
                return "Request Changes"
            case .counter:
                return "Counteroffer"
            }
        }
    }

    var amountLabel: String {
        switch self {
        case .buyer:
            return "Offer amount"
        case .seller(.counter):
            return "Counteroffer amount"
        case .seller:
            return "Seller response amount"
        }
    }

    var conditionsLabel: String {
        switch self {
        case .buyer:
            return "Set the updated amount and conditions before sending your response."
        case .seller(.requestChanges):
            return "Explain the terms the buyer needs to revise before you can accept."
        case .seller(.counter):
            return "Set the revised amount and terms you want the buyer to review."
        case .seller(.accept):
            return "Confirm the amount and terms you are accepting."
        }
    }

    var submitTitle: String {
        switch self {
        case .buyer:
            return "Send"
        case let .seller(action):
            return action.title
        }
    }
}

private struct OfferComposerContext: Identifiable {
    let id = UUID()
    let mode: OfferComposerMode
    let offer: OfferRecord?
    let amount: Int?
    let conditions: String

    var title: String {
        switch mode {
        case .buyer:
            return offer == nil ? "Make Offer" : "Update Offer"
        case .seller:
            return mode.title
        }
    }
    var amountLabel: String { mode.amountLabel }
    var conditionsLabel: String { mode.conditionsLabel }
    var submitTitle: String {
        switch mode {
        case .buyer:
            return offer == nil ? "Send" : "Update Offer"
        case .seller:
            return mode.submitTitle
        }
    }
}

private struct LegalSearchContext: Identifiable {
    let offerID: UUID
    let role: UserRole

    var id: String {
        "\(offerID.uuidString)-\(role.rawValue)"
    }
}

private struct SaleInviteShareContext: Identifiable {
    let listingID: UUID
    let offerID: UUID
    let role: LegalInviteRole
    let title: String
    let shareMessage: String

    var id: String {
        "\(offerID.uuidString)-\(role.rawValue)"
    }
}

private func paletteColors(for palette: ListingPalette) -> [Color] {
    switch palette {
    case .ocean:
        return [Color(red: 0.12, green: 0.37, blue: 0.59), Color(red: 0.32, green: 0.62, blue: 0.83)]
    case .sand:
        return [Color(red: 0.74, green: 0.56, blue: 0.35), Color(red: 0.92, green: 0.80, blue: 0.60)]
    case .gumleaf:
        return [Color(red: 0.20, green: 0.43, blue: 0.30), Color(red: 0.58, green: 0.76, blue: 0.57)]
    case .dusk:
        return [Color(red: 0.28, green: 0.29, blue: 0.54), Color(red: 0.66, green: 0.42, blue: 0.68)]
    }
}

private func currencyString(_ value: Int) -> String {
    Currency.aud.string(from: NSNumber(value: value)) ?? "$\(value)"
}

private func shortDateString(_ date: Date) -> String {
    Formatters.shortDate.string(from: date)
}

private func relativeDateString(_ date: Date) -> String {
    Formatters.relative.localizedString(for: date, relativeTo: .now)
}

private func timeString(_ date: Date) -> String {
    Formatters.time.string(from: date)
}

private func dateRangeString(start: Date, end: Date) -> String {
    "\(Formatters.dayTime.string(from: start)) - \(Formatters.time.string(from: end))"
}

private enum Formatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static let dayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
