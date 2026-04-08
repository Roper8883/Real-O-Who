import MapKit
import SwiftUI

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
    @State private var selectedTab: AppTab
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
                selectedConversationID: $selectedConversationID
            )
            .tabItem {
                Label("Browse", systemImage: "house.fill")
            }
            .tag(AppTab.browse)

            SavedView(
                selectedTab: $selectedTab,
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

            MessagesView(selectedConversationID: $selectedConversationID)
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
    }
}

private struct BrowseView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    @Binding var selectedTab: AppTab
    @Binding var selectedConversationID: UUID?

    @State private var filters = SearchFilters()
    @State private var selectedListing: PropertyListing?
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
            .sheet(item: $selectedListing) { listing in
                ListingDetailView(
                    listingID: listing.id,
                    onOpenMessages: { conversationID in
                        selectedConversationID = conversationID
                        selectedTab = .messages
                    }
                )
                .environmentObject(store)
                .environmentObject(messaging)
            }
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
    @Binding var selectedConversationID: UUID?

    @State private var selectedListing: PropertyListing?

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
            .sheet(item: $selectedListing) { listing in
                ListingDetailView(
                    listingID: listing.id,
                    onOpenMessages: { conversationID in
                        selectedConversationID = conversationID
                        selectedTab = .messages
                    }
                )
                .environmentObject(store)
                .environmentObject(messaging)
            }
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
                ConversationThreadView(threadID: selectedConversationID)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Account",
                        subtitle: "Manage the local account that unlocks the private-sale journey on this device."
                    )

                    brandPromise
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

                Text(
                    store.currentUser.role == .seller
                        ? "Seller tools are unlocked, so you can create listings and manage offers."
                        : "Buyer tools are unlocked, so you can shortlist homes, plan inspections, and message owners."
                )
                .foregroundStyle(.secondary)
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
}

private struct ListingDetailView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService
    @Environment(\.dismiss) private var dismiss

    let listingID: UUID
    let onOpenMessages: (UUID) -> Void

    @State private var isShowingOfferSheet = false
    @State private var notice: ListingNotice?

    private var listing: PropertyListing? {
        store.listing(id: listingID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let listing {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ListingHero(listing: listing)
                            summaryCard(for: listing)
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
                    .sheet(isPresented: $isShowingOfferSheet) {
                        OfferSheet(listing: listing) { amount, conditions in
                            guard let buyer = store.user(id: store.currentUserID),
                                  let seller = store.user(id: listing.sellerID),
                                  let conversation = store.submitOffer(
                                    listingID: listing.id,
                                    buyerID: buyer.id,
                                    amount: amount,
                                    conditions: conditions
                                  ).map({ _ in
                                      messaging.ensureConversation(listing: listing, buyer: buyer, seller: seller)
                                  }) else {
                                return
                            }

                            messaging.sendOfferSummary(
                                listing: listing,
                                buyer: buyer,
                                seller: seller,
                                amount: amount,
                                conditions: conditions
                            )
                            notice = ListingNotice(message: "Offer sent securely to the seller.")
                            onOpenMessages(conversation.id)
                            dismiss()
                        }
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

    private func summaryCard(for listing: PropertyListing) -> some View {
        let seller = store.user(id: listing.sellerID)
        let isOwnerView = store.currentUserID == listing.sellerID

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
                    Text("Owner view: manage this listing from Sell.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Message Seller") {
                        openConversation(for: listing)
                    }
                    .buttonStyle(.borderedProminent)

                    if store.currentUser.role == .buyer {
                        Button("Make Offer") {
                            isShowingOfferSheet = true
                        }
                        .buttonStyle(.bordered)
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

    private func openConversation(for listing: PropertyListing) {
        guard let currentUser = store.user(id: store.currentUserID),
              let seller = store.user(id: listing.sellerID) else { return }

        let thread = messaging.ensureConversation(listing: listing, buyer: currentUser, seller: seller)
        onOpenMessages(thread.id)
        dismiss()
    }
}

private struct ConversationThreadView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    let threadID: UUID

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
                                    isCurrentUser: message.senderID == currentUser.id
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
    let onSubmit: (Int, String) -> Void

    @State private var amountText = ""
    @State private var conditions = "Subject to building and pest inspection."

    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    Text(listing.title)
                    Text(currencyString(listing.askingPrice))
                        .foregroundStyle(.secondary)
                }

                Section("Offer") {
                    TextField("Offer amount", text: $amountText)
                        .keyboardType(.numberPad)
                    TextEditor(text: $conditions)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Make Offer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        if let amount = Int(amountText.filter(\.isNumber)) {
                            onSubmit(amount, conditions)
                            dismiss()
                        }
                    }
                    .disabled(Int(amountText.filter(\.isNumber)) == nil)
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
    let message: EncryptedMessage
    let sender: UserProfile?
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 6) {
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bubbleColor)
            )

            if !isCurrentUser { Spacer(minLength: 44) }
        }
    }

    private var bubbleColor: Color {
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
