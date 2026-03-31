import SwiftUI

private enum AppTab: Hashable {
    case discover
    case saved
    case sell
    case inbox
    case profile
}

private enum LegalLinks {
    static let home = URL(string: "https://roper8883.github.io/Real-A-Who/")!
    static let privacy = URL(string: "https://roper8883.github.io/Real-A-Who/privacy-policy/")!
    static let terms = URL(string: "https://roper8883.github.io/Real-A-Who/terms-of-use/")!
    static let support = URL(string: "https://roper8883.github.io/Real-A-Who/support/")!
}

struct ContentView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
                .tag(AppTab.discover)

            SavedView()
                .tabItem {
                    Label("Saved", systemImage: "heart.fill")
                }
                .tag(AppTab.saved)

            SellDashboardView()
                .tabItem {
                    Label("Sell", systemImage: "house.and.flag.fill")
                }
                .tag(AppTab.sell)

            InboxView()
                .badge(store.unreadMessageCount)
                .tabItem {
                    Label("Inbox", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(AppTab.inbox)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(Color(red: 0.11, green: 0.36, blue: 0.52))
    }
}

private struct DiscoverView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @State private var searchText = ""
    @State private var selectedState: AustralianState?

    private var results: [PropertyListing] {
        store.searchListings(query: searchText, stateFilter: selectedState)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    searchBar
                    stateFilterRow
                    discoverySummary

                    ForEach(results) { listing in
                        NavigationLink {
                            PropertyDetailView(listingID: listing.id)
                        } label: {
                            ListingCard(listing: listing, isSaved: store.isSaved(listing.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle("Real A Who")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Private property sales, rebuilt for trust.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Buyers can search, question, inspect, and make non-binding offers directly with owners. Sellers get state-aware workflows without handing the whole sale to an agent.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                MetricPill(title: "Live listings", value: "\(store.activeListingCount)")
                MetricPill(title: "Saved", value: "\(store.savedListings.count)")
                MetricPill(title: "Inspections", value: "\(store.upcomingInspectionCount)")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.95, blue: 0.98),
                            Color(red: 0.89, green: 0.95, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search suburb, postcode, feature, or address", text: $searchText)
                .textInputAutocapitalization(.words)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
        )
    }

    private var stateFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isSelected: selectedState == nil) {
                    selectedState = nil
                }

                ForEach(AustralianState.allCases) { state in
                    FilterChip(title: state.rawValue, isSelected: selectedState == state) {
                        selectedState = selectedState == state ? nil : state
                    }
                }
            }
        }
    }

    private var discoverySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search plus seller workflow, together")
                .font(.headline)

            Text("Every listing in this iOS build is tied to a state-aware private treaty workflow, with document readiness, direct owner messaging, inspection booking, and non-binding offer actions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
        )
    }
}

private struct SavedView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(title: "Shortlist", subtitle: "Saved properties, upcoming inspections, and offers you have in motion.")

                    HStack(spacing: 12) {
                        StatTile(title: "Saved", value: "\(store.savedListings.count)", caption: "properties")
                        StatTile(title: "Inspections", value: "\(store.inspections.count)", caption: "booked or requested")
                        StatTile(title: "Offers", value: "\(store.offers.filter { $0.buyerName == "You" }.count)", caption: "active")
                    }

                    if store.savedListings.isEmpty {
                        EmptyStateCard(
                            title: "No saved properties yet",
                            message: "Use Discover to build a shortlist, compare document readiness, and keep your due diligence organised."
                        )
                    } else {
                        VStack(spacing: 14) {
                            ForEach(store.savedListings) { listing in
                                NavigationLink {
                                    PropertyDetailView(listingID: listing.id)
                                } label: {
                                    ListingCard(listing: listing, isSaved: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inspection planner")
                            .font(.headline)

                        ForEach(store.inspections) { inspection in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white)
                                .overlay(alignment: .leading) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(inspection.propertyTitle)
                                                .font(.headline)
                                                .lineLimit(2)
                                            Spacer()
                                            StatusBadge(title: inspection.status.rawValue, accent: inspection.status == .confirmed ? .green : .orange)
                                        }

                                        Text(inspection.slotTitle)
                                            .font(.subheadline.weight(.medium))

                                        Text("Booked for \(inspection.attendees) attendee\(inspection.attendees == 1 ? "" : "s").")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(18)
                                }
                                .frame(height: 128)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Offer tracker")
                            .font(.headline)

                        ForEach(store.offers.filter { $0.buyerName == "You" }) { offer in
                            OfferCard(offer: offer)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle("Saved")
        }
    }
}

private struct SellDashboardView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Seller dashboard",
                        subtitle: "Private listing performance, compliance tasks, inspection flow, and offer activity in one place."
                    )

                    HStack(spacing: 12) {
                        StatTile(title: "Live", value: "\(store.activeListingCount)", caption: "listings")
                        StatTile(title: "Offers", value: "\(store.sellerOfferCount)", caption: "active threads")
                        StatTile(title: "Tasks", value: "\(store.sellerTasks.count)", caption: "open items")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("My listings")
                            .font(.headline)

                        ForEach(store.featuredListings) { listing in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(listing.heroTitle)
                                            .font(.headline)
                                        Text(listing.locationLine)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(title: listing.status.rawValue, accent: listing.status.accentColor)
                                }

                                HStack(spacing: 10) {
                                    Label("\(listing.responseRate)% response", systemImage: "bolt.horizontal.circle")
                                    Label(listing.averageResponseTime, systemImage: "clock")
                                    Label(listing.disclosureStatus.rawValue, systemImage: "doc.text.fill")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Text(listing.legalStatusText)
                                    .font(.subheadline)

                                Text(listing.state.complianceSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.white)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Compliance and next actions")
                            .font(.headline)

                        ForEach(store.sellerTasks) { task in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(task.isBlocking ? Color(red: 0.98, green: 0.94, blue: 0.90) : .white)
                                .overlay(alignment: .leading) {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: task.isBlocking ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                            .foregroundStyle(task.isBlocking ? .orange : .green)
                                            .font(.title3)

                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(task.title)
                                                    .font(.headline)
                                                Spacer()
                                                Text(task.dueLabel)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }

                                            Text(task.detail)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(18)
                                }
                                .frame(minHeight: 96)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Sell")
        }
    }
}

private struct InboxView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.conversations) { thread in
                        NavigationLink {
                            ConversationDetailView(threadID: thread.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(thread.participantName)
                                        .font(.headline)
                                    Spacer()
                                    if thread.unreadCount > 0 {
                                        Text("\(thread.unreadCount)")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color(red: 0.11, green: 0.36, blue: 0.52)))
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(thread.listingTitle)
                                    .font(.subheadline.weight(.medium))

                                Text(thread.lastMessagePreview)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Direct owner conversations")
                } footer: {
                    Text("Contact details stay masked unless both sides choose to reveal them.")
                }
            }
            .navigationTitle("Inbox")
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard

                    HStack(spacing: 12) {
                        StatTile(title: "Saved", value: "\(store.savedListings.count)", caption: "properties")
                        StatTile(title: "Threads", value: "\(store.conversations.count)", caption: "owner chats")
                        StatTile(title: "Offers", value: "\(store.offers.count)", caption: "tracked")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What this app is")
                            .font(.headline)
                        InformationalCard(text: "A private-sale marketplace, workflow, and communication layer for Australian residential property.")
                        InformationalCard(text: "Not a law firm, conveyancer, escrow service, or trust account holder. Offers stay non-binding until valid contract execution.")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Legal and help")
                            .font(.headline)

                        LinkRow(title: "Privacy policy", subtitle: "Live in-app link required for App Review", url: LegalLinks.privacy)
                        LinkRow(title: "Terms of use", subtitle: "Marketplace and offer disclaimer draft", url: LegalLinks.terms)
                        LinkRow(title: "Support", subtitle: "Help, bug reporting, and contact information", url: LegalLinks.support)
                        LinkRow(title: "Product site", subtitle: "Overview of the current Real A Who experience", url: LegalLinks.home)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }

    private var profileCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.11, green: 0.36, blue: 0.52), Color(red: 0.25, green: 0.61, blue: 0.56)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text("Aaron Roper")
                    .font(.title3.weight(.bold))

                Text("Buyer and seller profile")
                    .foregroundStyle(.secondary)

                Label("Identity verification scaffolded", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white)
        )
    }
}

private struct PropertyDetailView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @Environment(\.dismiss) private var dismiss

    let listingID: UUID

    @State private var showingMessageSheet = false
    @State private var showingOfferSheet = false
    @State private var showingInspectionSheet = false
    @State private var showingBuildingPestInfo = false
    @State private var feedbackMessage: String?

    private var listing: PropertyListing? {
        store.listing(id: listingID)
    }

    var body: some View {
        Group {
            if let listing {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero(for: listing)
                        keyFacts(for: listing)
                        actionPanel(for: listing)
                        documentPanel(for: listing)
                        ownerPanel(for: listing)
                        compliancePanel(for: listing)
                        neighbourhoodPanel(for: listing)
                    }
                    .padding(20)
                }
                .background(Color(red: 0.97, green: 0.98, blue: 0.99).ignoresSafeArea())
                .navigationTitle(listing.suburb)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.toggleSaved(listingID: listing.id)
                        } label: {
                            Image(systemName: store.isSaved(listing.id) ? "heart.fill" : "heart")
                        }
                    }
                }
                .sheet(isPresented: $showingMessageSheet) {
                    MessageComposerView(listing: listing) { text in
                        store.startConversation(for: listing.id, openingMessage: text)
                        feedbackMessage = "Message sent to \(listing.sellerName)."
                    }
                }
                .sheet(isPresented: $showingOfferSheet) {
                    OfferComposerView(listing: listing) { amount, deposit, settlement, finance, building, pest, saleOfHome, note in
                        store.submitOffer(
                            listingID: listing.id,
                            amount: amount,
                            depositIntention: deposit,
                            settlementDays: settlement,
                            subjectToFinance: finance,
                            subjectToBuildingInspection: building,
                            subjectToPestInspection: pest,
                            subjectToSaleOfHome: saleOfHome,
                            buyerMessage: note
                        )
                        feedbackMessage = "Offer submitted as non-binding and ready for seller review."
                    }
                }
                .sheet(isPresented: $showingInspectionSheet) {
                    InspectionBookingView(listing: listing) { slotID, attendees in
                        store.requestInspection(listingID: listing.id, slotID: slotID, attendees: attendees)
                        feedbackMessage = "Inspection request recorded."
                    }
                }
                .sheet(isPresented: $showingBuildingPestInfo) {
                    BuildingPestInfoView(listing: listing)
                }
                .alert("Update", isPresented: Binding(get: { feedbackMessage != nil }, set: { if !$0 { feedbackMessage = nil } })) {
                    Button("OK") {
                        feedbackMessage = nil
                    }
                } message: {
                    Text(feedbackMessage ?? "")
                }
            } else {
                ContentUnavailableView("Listing unavailable", systemImage: "exclamationmark.triangle", description: Text("This property could not be loaded."))
            }
        }
    }

    private func hero(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [listing.state.accentColor.opacity(0.90), listing.state.secondaryAccentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 240)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        StatusBadge(title: listing.status.rawValue, accent: .white.opacity(0.25), foreground: .white)
                        Spacer()
                        Text(listing.state.rawValue)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.18)))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(listing.priceGuide)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(listing.heroTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("\(listing.addressLine), \(listing.locationLine)")
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(22)
            }

            Text(listing.summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func keyFacts(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property snapshot")
                .font(.headline)

            HStack(spacing: 12) {
                FactBubble(value: "\(listing.bedrooms)", label: "Beds")
                FactBubble(value: "\(listing.bathrooms)", label: "Baths")
                FactBubble(value: "\(listing.parking)", label: "Cars")
                FactBubble(value: listing.propertyType.rawValue, label: listing.saleMethod)
            }

            HStack(spacing: 12) {
                InlineDetail(title: "Land", value: listing.landSize)
                InlineDetail(title: "Building", value: listing.buildingSize)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func actionPanel(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Buyer actions")
                .font(.headline)

            Text("Offers in the app are non-binding until the right contract is executed for \(listing.state.title).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActionButton(title: store.isSaved(listing.id) ? "Saved" : "Save property", systemImage: store.isSaved(listing.id) ? "heart.fill" : "heart") {
                    store.toggleSaved(listingID: listing.id)
                }

                ActionButton(title: "Ask owner", systemImage: "bubble.left.and.bubble.right") {
                    showingMessageSheet = true
                }

                ActionButton(title: "Book inspection", systemImage: "calendar.badge.plus") {
                    showingInspectionSheet = true
                }

                ActionButton(title: "Request building & pest", systemImage: "doc.text.magnifyingglass") {
                    showingBuildingPestInfo = true
                }

                ActionButton(title: "Make offer", systemImage: "banknote") {
                    showingOfferSheet = true
                }

                Link(destination: LegalLinks.privacy) {
                    Label("Privacy policy", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func documentPanel(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Documents and disclosure")
                .font(.headline)

            ForEach(listing.documents) { document in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: document.isRequired ? "doc.badge.gearshape.fill" : "doc.text.fill")
                        .foregroundStyle(document.isRequired ? .orange : .blue)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(document.title)
                                .font(.subheadline.weight(.semibold))
                            if document.isRequired {
                                Text("Required")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.orange.opacity(0.14)))
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text(document.statusText)
                            .foregroundStyle(.secondary)
                        Text(document.provenance.rawValue)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func ownerPanel(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Owner profile")
                .font(.headline)

            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(listing.state.accentColor.opacity(0.18))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "house.fill")
                            .foregroundStyle(listing.state.accentColor)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(listing.sellerName)
                            .font(.headline)
                        if listing.sellerVerified {
                            Label("Verified", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }

                    Text("\(listing.responseRate)% response rate · average reply \(listing.averageResponseTime)")
                        .foregroundStyle(.secondary)

                    Text("What the owner loves: \(listing.whatOwnerLoves)")
                        .font(.subheadline)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func compliancePanel(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("State-aware legal workflow")
                .font(.headline)

            InformationalCard(text: listing.legalStatusText)
            InformationalCard(text: listing.state.complianceSummary)
            InformationalCard(text: listing.dueDiligencePrompt)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func neighbourhoodPanel(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features and neighbourhood")
                .font(.headline)

            FlowTagList(items: listing.features)
            FlowTagList(items: listing.neighbourhoodHighlights, tint: listing.state.accentColor.opacity(0.12), foreground: listing.state.accentColor)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }
}

private struct ConversationDetailView: View {
    @EnvironmentObject private var store: MarketplaceStore
    let threadID: UUID

    @State private var draft = ""

    private var thread: ConversationThread? {
        store.thread(id: threadID)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let thread {
                        ForEach(thread.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .padding(20)
            }

            HStack(spacing: 12) {
                TextField("Reply to the owner", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button("Send") {
                    store.sendMessage(threadID: threadID, text: draft)
                    draft = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(thread?.participantName ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.markConversationRead(threadID: threadID)
        }
    }
}

private struct MessageComposerView: View {
    @Environment(\.dismiss) private var dismiss
    let listing: PropertyListing
    let onSend: (String) -> Void

    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    Text(listing.heroTitle)
                    Text(listing.locationLine)
                        .foregroundStyle(.secondary)
                }

                Section("Ask owner a question") {
                    TextEditor(text: $message)
                        .frame(minHeight: 180)

                    Text("Contact details remain masked unless both sides choose to reveal them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Message owner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        onSend(message)
                        dismiss()
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct OfferComposerView: View {
    @Environment(\.dismiss) private var dismiss
    let listing: PropertyListing
    let onSubmit: (Int, String, Int, Bool, Bool, Bool, Bool, String) -> Void

    @State private var amountText = ""
    @State private var depositText = "5% on exchange"
    @State private var settlementDays = 45
    @State private var subjectToFinance = true
    @State private var subjectToBuilding = true
    @State private var subjectToPest = true
    @State private var subjectToSale = false
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Offer summary") {
                    Text(listing.heroTitle)
                    TextField("Offer amount", text: $amountText)
                        .keyboardType(.numberPad)
                    TextField("Deposit intention", text: $depositText)
                    Stepper("Settlement timeframe: \(settlementDays) days", value: $settlementDays, in: 14...120, step: 1)
                }

                Section("Conditions") {
                    Toggle("Subject to finance", isOn: $subjectToFinance)
                    Toggle("Subject to building inspection", isOn: $subjectToBuilding)
                    Toggle("Subject to pest inspection", isOn: $subjectToPest)
                    Toggle("Subject to sale of current home", isOn: $subjectToSale)
                }

                Section("Buyer note") {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                }

                Section {
                    Text("Important: this is a non-binding in-app offer only. A buyer is not committed to purchase and a seller is not committed to sell until a valid contract is formally executed in the legally correct way for the relevant Australian jurisdiction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Make offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        if let amount = Int(amountText.filter(\.isNumber)) {
                            onSubmit(amount, depositText, settlementDays, subjectToFinance, subjectToBuilding, subjectToPest, subjectToSale, message)
                            dismiss()
                        }
                    }
                    .disabled(Int(amountText.filter(\.isNumber)) == nil)
                }
            }
        }
    }
}

private struct InspectionBookingView: View {
    @Environment(\.dismiss) private var dismiss
    let listing: PropertyListing
    let onSubmit: (UUID, Int) -> Void

    @State private var selectedSlotID: UUID
    @State private var attendees = 1

    init(listing: PropertyListing, onSubmit: @escaping (UUID, Int) -> Void) {
        self.listing = listing
        self.onSubmit = onSubmit
        _selectedSlotID = State(initialValue: listing.inspectionSlots.first?.id ?? UUID())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Inspection options") {
                    ForEach(listing.inspectionSlots) { slot in
                        Button {
                            selectedSlotID = slot.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(slot.title)
                                        .foregroundStyle(.primary)
                                    Text("\(slot.bookedCount)/\(slot.capacity) booked")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedSlotID == slot.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedSlotID == slot.id ? .blue : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Attendees") {
                    Stepper("People attending: \(attendees)", value: $attendees, in: 1...6)
                }

                Section {
                    Text("Owner-managed inspections are recorded in-app so reminders, follow-ups, and attendance notes stay attached to the property thread.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Book inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Request") {
                        onSubmit(selectedSlotID, attendees)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct BuildingPestInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let listing: PropertyListing

    var body: some View {
        NavigationStack {
            List {
                Section("Building and pest flow") {
                    Text("1. Review any seller-provided reports already attached to the listing.")
                    Text("2. Request quotes or book your own inspector when you need fresh advice.")
                    Text("3. Report reliance, insurance, and licence checks stay visible before booking.")
                }

                Section("For this property") {
                    Text(listing.state == .act ? "ACT seller-provided report logic is supported here, including reimbursement metadata." : "Seller-provided reports and buyer-booked inspections can both be supported for this listing.")
                    Text("The marketplace can coordinate bookings and document delivery, but it does not guarantee findings or replace independent due diligence.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Building & pest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ListingCard: View {
    @EnvironmentObject private var store: MarketplaceStore
    let listing: PropertyListing
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [listing.state.accentColor.opacity(0.92), listing.state.secondaryAccentColor.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 190)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusBadge(title: listing.status.rawValue, accent: .white.opacity(0.22), foreground: .white)
                        Spacer()
                        Button {
                            store.toggleSaved(listingID: listing.id)
                        } label: {
                            Image(systemName: isSaved ? "heart.fill" : "heart")
                                .padding(10)
                                .background(Circle().fill(.white.opacity(0.18)))
                        }
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Text(listing.priceGuide)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    Text(listing.heroTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(listing.locationLine)
                        .foregroundStyle(.white.opacity(0.84))
                }
                .padding(18)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(listing.headline)
                    .font(.headline)

                Text(listing.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 14) {
                    Label("\(listing.bedrooms)", systemImage: "bed.double.fill")
                    Label("\(listing.bathrooms)", systemImage: "shower.fill")
                    Label("\(listing.parking)", systemImage: "car.fill")
                    Label(listing.propertyType.rawValue, systemImage: "house.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white))
    }
}

private struct OfferCard: View {
    let offer: OfferRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(offer.propertyTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                StatusBadge(title: offer.status.rawValue, accent: offer.status.accentColor)
            }

            Text(currencyString(for: offer.amount))
                .font(.title3.weight(.bold))

            Text("Deposit: \(offer.depositIntention) · Settlement: \(offer.settlementDays) days")
                .font(.subheadline)

            Text(offer.buyerMessage)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
    }

    private func currencyString(for amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

private struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.isFromCurrentUser { Spacer(minLength: 36) }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(message.senderName)
                        .font(.caption.weight(.semibold))
                    if message.isPinnedFAQ {
                        Text("Pinned FAQ")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.14)))
                            .foregroundStyle(.green)
                    }
                }

                Text(message.body)
                    .foregroundStyle(.primary)

                Text(message.sentAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.isFromCurrentUser ? Color(red: 0.89, green: 0.95, blue: 0.98) : .white)
            )

            if !message.isFromCurrentUser { Spacer(minLength: 36) }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
    }
}

private struct MetricPill: View {
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
        .background(Capsule().fill(.white.opacity(0.78)))
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(red: 0.11, green: 0.36, blue: 0.52) : .white)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.06, green: 0.17, blue: 0.25).opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.white)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .frame(height: 140)
    }
}

private struct InformationalCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.03))
            )
    }
}

private struct LinkRow: View {
    let title: String
    let subtitle: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
        }
        .buttonStyle(.plain)
    }
}

private struct FactBubble: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }
}

private struct InlineDetail: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowTagList: View {
    let items: [String]
    var tint: Color = Color(red: 0.05, green: 0.14, blue: 0.21).opacity(0.06)
    var foreground: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(chunked(items, size: 3), id: \.self) { row in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(tint))
                            .foregroundStyle(foreground)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ items: [String], size: Int) -> [[String]] {
        stride(from: 0, to: items.count, by: size).map {
            Array(items[$0 ..< min($0 + size, items.count)])
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let accent: Color
    var foreground: Color = .primary

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(accent))
            .foregroundStyle(foreground)
    }
}

private extension ListingStatus {
    var accentColor: Color {
        switch self {
        case .active: return Color.green.opacity(0.16)
        case .underOffer: return Color.orange.opacity(0.18)
        case .acceptedInPrinciple: return Color.blue.opacity(0.16)
        case .contractRequested: return Color.purple.opacity(0.14)
        case .exchanged: return Color.indigo.opacity(0.16)
        case .sold: return Color.gray.opacity(0.18)
        }
    }
}

private extension OfferStatus {
    var accentColor: Color {
        switch self {
        case .submitted: return Color.orange.opacity(0.16)
        case .countered: return Color.blue.opacity(0.16)
        case .acceptedInPrinciple: return Color.green.opacity(0.16)
        case .contractRequested: return Color.purple.opacity(0.14)
        case .expired: return Color.gray.opacity(0.18)
        }
    }
}

private extension AustralianState {
    var accentColor: Color {
        switch self {
        case .nsw: return Color(red: 0.16, green: 0.39, blue: 0.65)
        case .vic: return Color(red: 0.23, green: 0.41, blue: 0.75)
        case .qld: return Color(red: 0.16, green: 0.55, blue: 0.48)
        case .sa: return Color(red: 0.58, green: 0.24, blue: 0.41)
        case .act: return Color(red: 0.26, green: 0.47, blue: 0.58)
        case .nt: return Color(red: 0.61, green: 0.40, blue: 0.23)
        case .wa: return Color(red: 0.34, green: 0.44, blue: 0.18)
        case .tas: return Color(red: 0.35, green: 0.36, blue: 0.58)
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .nsw: return Color(red: 0.08, green: 0.27, blue: 0.43)
        case .vic: return Color(red: 0.18, green: 0.30, blue: 0.54)
        case .qld: return Color(red: 0.10, green: 0.41, blue: 0.36)
        case .sa: return Color(red: 0.41, green: 0.15, blue: 0.28)
        case .act: return Color(red: 0.17, green: 0.33, blue: 0.42)
        case .nt: return Color(red: 0.43, green: 0.26, blue: 0.14)
        case .wa: return Color(red: 0.22, green: 0.28, blue: 0.11)
        case .tas: return Color(red: 0.22, green: 0.24, blue: 0.42)
        }
    }
}
