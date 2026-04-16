import MapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    static let background = AppTheme.pageBackground
    static let card = AppTheme.cardBackground
    static let panel = AppTheme.panelBackground
    static let input = AppTheme.inputBackground
    static let pill = AppTheme.pillBackground
    static let selection = AppTheme.chipBackground
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
                selectedConversationID: $selectedConversationID,
                reminderTarget: focusedSaleReminderTarget,
                onResolveReminderTarget: resolveReminderTarget(_:)
            )
            .tabItem {
                Label("Saved", systemImage: "bookmark.fill")
            }
            .tag(AppTab.saved)

            SellView(
                selectedTab: $selectedTab,
                selectedListing: $selectedListing,
                selectedConversationID: $selectedConversationID,
                reminderTarget: focusedSaleReminderTarget,
                onResolveReminderTarget: resolveReminderTarget(_:)
            )
                .tabItem {
                    Label("Sell", systemImage: "key.horizontal.fill")
                }
                .tag(AppTab.sell)

            MessagesView(
                selectedConversationID: $selectedConversationID,
                onOpenSaleTask: { target in
                    openSaleTask(target)
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
            await store.refreshListings()
            await store.refreshMarketplaceState()
            await store.refreshOffers()
            await messaging.activateSession(for: store.currentUserID)
        }
        .task(id: store.inboundSaleReminderTarget?.routingKey) {
            guard let target = store.inboundSaleReminderTarget else {
                return
            }

            openSaleTask(target)
            store.consumeInboundSaleReminderTarget()
        }
    }

    private func openSaleTask(_ target: SaleReminderNavigationTarget) {
        focusedSaleReminderTarget = target

        if target.isConciergeReminder {
            selectedListing = nil

            if let offer = store.offer(id: target.offerID),
               store.currentUserID == offer.sellerID {
                selectedTab = .sell
            } else {
                selectedTab = .saved
            }
            return
        }

        guard let listing = store.listing(id: target.listingID) else {
            return
        }

        selectedTab = .browse
        selectedListing = listing
    }

    private func resolveReminderTarget(_ target: SaleReminderNavigationTarget) {
        guard focusedSaleReminderTarget?.routingKey == target.routingKey else {
            return
        }

        focusedSaleReminderTarget = nil
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
                            .fill(BrandPalette.pill.opacity(0.75))
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
                        .fill(AppTheme.inputBackground)
                )

            HStack(spacing: 12) {
                TextField("Suburb", text: $filters.suburb)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.inputBackground)
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
                .fill(AppTheme.cardBackground)
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
    @Environment(\.openURL) private var openURL

    @Binding var selectedTab: AppTab
    @Binding var selectedListing: PropertyListing?
    @Binding var selectedConversationID: UUID?
    let reminderTarget: SaleReminderNavigationTarget?
    let onResolveReminderTarget: (SaleReminderNavigationTarget) -> Void

    @State private var offerComposer: OfferComposerContext?
    @State private var legalSearchContext: LegalSearchContext?
    @State private var shareInviteContext: SaleInviteShareContext?
    @State private var archiveShareContext: SaleArchiveShareContext?
    @State private var conciergeBookingContext: PostSaleConciergeBookingContext?
    @State private var conciergeInvoiceUploadContext: PostSaleConciergeInvoiceUploadContext?
    @State private var conciergePaymentUploadContext: PostSaleConciergePaymentUploadContext?
    @State private var conciergeResolutionContext: PostSaleConciergeResolutionContext?
    @State private var postSaleFeedbackContext: PostSaleFeedbackContext?
    @State private var pendingVerificationUploadKind: VerificationCheckKind?
    @State private var preparedDocument: PreparedSaleDocument?
    @State private var buyerHubAlert: BuyerHubAlert?
    @State private var selectedAttentionItemIDs: Set<String> = []
    @State private var attentionSeverityFilter: ConciergeAttentionScopeFilter = .all
    @State private var attentionServiceFilter: ConciergeAttentionServiceFilter = .all
    @State private var suggestedReplacementPreviews: [String: ConciergeReplacementSuggestion] = [:]
    @State private var suggestedReplacementPreviewFingerprints: [String: String] = [:]
    @State private var loadingSuggestedReplacementPreviewIDs: Set<String> = []
    @State private var preparingSuggestedReplacementItemID: String?
    @State private var isBatchReplacingAttentionItems = false
    @State private var batchReplacementReviewContext: ConciergeBatchReplacementReviewContext?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Saved",
                        subtitle: "Shortlist homes, watch suburbs, and keep inspections in one place while you buy without agent friction."
                    )

                    if store.currentUser.role == .buyer {
                        buyerStats
                        buyerDealLane
                        buyerConciergeAttentionQueue
                        buyerArchiveCentre
                        buyerResponseQueue
                    }

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
            .navigationTitle(store.currentUser.role == .buyer ? "Buyer Hub" : "Watchlist")
            .task(id: reminderTarget?.routingKey) {
                handleBuyerReminderTarget(reminderTarget)
            }
            .sheet(item: $offerComposer) { composer in
                if let listing = composer.offer.flatMap({ store.listing(id: $0.listingID) }) {
                    OfferSheet(
                        listing: listing,
                        title: composer.title,
                        amountLabel: composer.amountLabel,
                        conditionsLabel: composer.conditionsLabel,
                        submitTitle: composer.submitTitle,
                        initialAmount: composer.amount,
                        initialConditions: composer.conditions
                    ) { amount, conditions in
                        handleBuyerOfferSubmission(
                            listing: listing,
                            amount: amount,
                            conditions: conditions
                        )
                    }
                } else {
                    EmptyPanel(message: "That offer is no longer available.")
                        .padding()
                }
            }
            .sheet(item: $legalSearchContext) { context in
                if let offer = store.offer(id: context.offerID),
                   let listing = store.listing(id: offer.listingID) {
                    LegalSearchSheet(
                        listing: listing,
                        actingRole: context.role,
                        currentSelection: offer.buyerLegalSelection?.professional,
                        onSelect: { professional in
                            handleBuyerLegalSelection(
                                listing: listing,
                                offerID: context.offerID,
                                professional: professional
                            )
                        }
                    )
                    .environmentObject(store)
                } else {
                    EmptyPanel(message: "That deal is no longer available.")
                        .padding()
                }
            }
            .sheet(item: $shareInviteContext) { context in
                TrackedShareSheet(
                    title: context.title,
                    items: [context.shareMessage]
                ) { completed in
                    if completed {
                        handleBuyerInviteShare(
                            listingID: context.listingID,
                            offerID: context.offerID,
                            role: context.role
                        )
                    }
                }
            }
            .sheet(item: $archiveShareContext) { context in
                TrackedShareSheet(
                    title: context.title,
                    items: context.fileURLs.map { $0 as Any }
                ) { _ in }
            }
            .sheet(item: $batchReplacementReviewContext) { context in
                ConciergeBatchReplacementReviewSheet(
                    context: context,
                    onConfirm: { reviewedEntries, returnContext in
                        confirmBuyerBatchReplacementReview(reviewedEntries, returnContext: returnContext)
                    },
                    onOpenEntry: { entry, returnContext in
                        openBuyerBatchReplacementReviewEntry(entry, returnContext: returnContext)
                    },
                    onCloseEntries: { entryIDs, remainingCount in
                        closeBuyerBatchReviewEntries(entryIDs, remainingCount: remainingCount)
                    }
                )
                .environmentObject(store)
            }
            .sheet(item: $conciergeBookingContext) { context in
                PostSaleConciergeSheet(
                    listing: context.listing,
                    serviceKind: context.serviceKind,
                    counterpartName: context.counterpartName,
                    focus: context.focus,
                    preferredProviderID: context.preferredProviderID,
                    preferredReplacementStrategy: context.preferredReplacementStrategy,
                    currentBooking: context.currentBooking,
                    manualReviewContext: context.manualReviewContext,
                    onConfirmProvider: { note in
                        confirmBuyerConciergeProvider(context: context, note: note)
                    },
                    onLogFollowUp: {
                        logBuyerConciergeFollowUp(context: context)
                    },
                    onSnoozeReminder: {
                        snoozeBuyerConciergeReminder(context: context)
                    },
                    onLogIssue: {
                        openBuyerConciergeResolution(context: context, mode: .logIssue)
                    },
                    onResolveIssue: {
                        openBuyerConciergeResolution(context: context, mode: .resolveIssue)
                    }
                ) { provider, scheduledFor, notes, estimatedCost in
                    bookBuyerPostSaleConciergeService(
                        context: context,
                        provider: provider,
                        scheduledFor: scheduledFor,
                        notes: notes,
                        estimatedCost: estimatedCost
                    )
                }
                .environmentObject(store)
            }
            .sheet(item: $conciergeResolutionContext) { context in
                PostSaleConciergeResolutionSheet(
                    mode: context.mode,
                    booking: context.booking
                ) { issueKind, note, amount in
                    handleBuyerConciergeResolution(
                        context: context,
                        issueKind: issueKind,
                        note: note,
                        amount: amount
                    )
                }
            }
            .sheet(item: $postSaleFeedbackContext) { context in
                PostSaleFeedbackSheet(
                    title: "Post-sale feedback",
                    listingTitle: context.listingTitle,
                    counterpartName: context.counterpartName,
                    existingEntry: context.existingEntry
                ) { rating, notes in
                    submitBuyerPostSaleFeedback(
                        context: context,
                        rating: rating,
                        notes: notes
                    )
                }
            }
            .sheet(item: $preparedDocument) { document in
                SaleDocumentPreviewSheet(document: document)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { conciergeInvoiceUploadContext != nil },
                    set: { isPresented in
                        if !isPresented {
                            conciergeInvoiceUploadContext = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedConciergeInvoice(result)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { conciergePaymentUploadContext != nil },
                    set: { isPresented in
                        if !isPresented {
                            conciergePaymentUploadContext = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedConciergePaymentProof(result)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { pendingVerificationUploadKind != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingVerificationUploadKind = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedVerificationDocument(result)
            }
            .alert(item: $buyerHubAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var buyerTransactionEntries: [BuyerTransactionEntry] {
        store.offers
            .filter { $0.buyerID == store.currentUserID }
            .compactMap { offer in
                guard let listing = store.listing(id: offer.listingID),
                      let seller = store.user(id: offer.sellerID) else {
                    return nil
                }

                return BuyerTransactionEntry(
                    listing: listing,
                    offer: offer,
                    seller: seller,
                    priority: buyerOfferPriority(for: offer, listing: listing, seller: seller)
                )
            }
            .sorted { left, right in
                if left.priority.score == right.priority.score {
                    return left.offer.createdAt > right.offer.createdAt
                }
                return left.priority.score > right.priority.score
            }
    }

    private var activeBuyerDealEntries: [BuyerTransactionEntry] {
        buyerTransactionEntries
            .filter {
                ($0.offer.status == .accepted || $0.offer.contractPacket?.isFullySigned == true) &&
                $0.offer.settlementCompletedAt == nil
            }
            .sorted { left, right in
                left.offer.createdAt > right.offer.createdAt
            }
    }

    private var buyerAttentionItems: [BuyerConciergeAttentionItem] {
        let includeDueSoon = store.currentUser.conciergeReminderIntensity.showsDueSoonAttention

        return settledBuyerArchiveEntries
            .flatMap { entry in
                conciergeRows(for: entry.offer).compactMap { row in
                    let severity: ConciergeAttentionSeverity?
                    if row.needsFollowUp {
                        severity = .overdue
                    } else if includeDueSoon && row.isResponseDueSoon {
                        severity = .dueSoon
                    } else {
                        severity = nil
                    }

                    guard let severity else {
                        return nil
                    }

                    return BuyerConciergeAttentionItem(
                        entry: entry,
                        row: row,
                        severity: severity
                    )
                }
            }
            .sorted { left, right in
                if left.severity.sortRank == right.severity.sortRank {
                    if left.entry.listing.title == right.entry.listing.title {
                        return left.row.title < right.row.title
                    }
                    return left.entry.listing.title < right.entry.listing.title
                }
                return left.severity.sortRank < right.severity.sortRank
            }
    }

    private var filteredBuyerAttentionItems: [BuyerConciergeAttentionItem] {
        buyerAttentionItems.filter {
            attentionSeverityFilter.matches($0.severity) &&
            attentionServiceFilter.matches($0.row.kind)
        }
    }

    private var settledBuyerArchiveEntries: [BuyerTransactionEntry] {
        buyerTransactionEntries
            .filter { $0.offer.settlementCompletedAt != nil }
            .sorted { left, right in
                guard let leftDate = left.offer.settlementCompletedAt,
                      let rightDate = right.offer.settlementCompletedAt else {
                    return left.offer.createdAt > right.offer.createdAt
                }
                return leftDate > rightDate
            }
    }

    private var buyerResponseQueueEntries: [BuyerTransactionEntry] {
        buyerTransactionEntries.filter {
            $0.offer.status != .accepted &&
            $0.offer.contractPacket?.isFullySigned != true &&
            $0.offer.settlementCompletedAt == nil
        }
    }

    private var buyerStats: some View {
        let entries = buyerTransactionEntries
        let financeReady = store.currentUser.hasVerifiedCheck(.finance)
        let acceptedDeals = entries.filter { $0.offer.status == .accepted }.count
        let counteredOffers = entries.filter { $0.offer.status == .countered || $0.offer.status == .changesRequested }.count
        let reminderDashboard = store.currentUserConciergeReminderDashboard

        return VStack(alignment: .leading, spacing: 12) {
            Text("Buyer transaction centre")
                .font(.headline)

            AdaptiveTagGrid(minimum: 150) {
                StatPanel(
                    title: "Live offers",
                    value: "\(entries.count)",
                    subtitle: "Offer records already synced into your deal rooms"
                )
                StatPanel(
                    title: "Accepted",
                    value: "\(acceptedDeals)",
                    subtitle: "Deals currently moving through legal or settlement"
                )
                StatPanel(
                    title: "Action now",
                    value: "\(counteredOffers)",
                    subtitle: "Seller responses waiting on your next move"
                )
                StatPanel(
                    title: "Finance",
                    value: financeReady ? "Ready" : "Pending",
                    subtitle: financeReady ? "Finance proof already verified" : "Upload proof to unlock contract issue"
                )
                StatPanel(
                    title: "Urgent",
                    value: "\(reminderDashboard.overdueCount)",
                    subtitle: reminderDashboard.overdueCount == 0
                        ? "No overdue provider follow-ups"
                        : "Concierge providers still waiting on reply"
                )
                if store.currentUser.conciergeReminderIntensity.showsDueSoonAttention {
                    StatPanel(
                        title: "Due soon",
                        value: "\(reminderDashboard.dueSoonCount)",
                        subtitle: "Upcoming provider reply windows"
                    )
                }
            }

            HighlightInformationCard(
                title: "Private-sale buyer workflow",
                message: "Use this hub to keep offers, legal selection, contract signing, settlement documents, and seller follow-ups together instead of jumping between screens.",
                supporting: "Saved homes and inspection plans stay below so the buying pipeline still feels familiar."
            )
        }
    }

    private var buyerDealLane: some View {
        let entries = activeBuyerDealEntries
        let signaturePendingCount = entries.filter {
            $0.offer.contractPacket?.isFullySigned != true && $0.offer.settlementCompletedAt == nil
        }.count
        let settlementReadyCount = entries.filter {
            $0.offer.documents.contains(where: { $0.kind == .settlementStatementPDF })
        }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Active buyer deals")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Accepted deals will appear here with the next buyer-side action, key documents, and shortcuts into secure messages.")
            } else {
                AdaptiveTagGrid(minimum: 150) {
                    MiniStatPanel(
                        title: "Live deals",
                        value: "\(entries.count)",
                        subtitle: "Accepted transactions already inside the shared deal room"
                    )
                    MiniStatPanel(
                        title: "Signatures open",
                        value: "\(signaturePendingCount)",
                        subtitle: "Deals still waiting on final contract sign-off"
                    )
                    MiniStatPanel(
                        title: "Statements ready",
                        value: "\(settlementReadyCount)",
                        subtitle: "Deals with settlement paperwork ready to close out"
                    )
                }

                ForEach(entries) { entry in
                    let executionAction = buyerExecutionPrimaryAction(for: entry)
                    BuyerDealExecutionCard(
                        entry: entry,
                        nextItem: nextChecklistItem(for: entry.offer),
                        nextSnapshot: nextChecklistItem(for: entry.offer).flatMap { entry.offer.liveTaskSnapshot(for: $0.id) },
                        blockingSummary: buyerExecutionBlockingSummary(for: entry),
                        keyDocuments: keyBuyerExecutionDocuments(for: entry.offer),
                        primaryActionTitle: executionAction?.title,
                        primaryActionSupporting: executionAction?.supporting,
                        onPrimaryAction: executionAction.map { action in
                            {
                                performBuyerExecutionAction(action, for: entry)
                            }
                        },
                        onOpenDocument: { document in
                            openBuyerExecutionDocument(document, for: entry)
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, seller: entry.seller)
                        }
                    )
                }
            }
        }
    }

    private var buyerResponseQueue: some View {
        let entries = buyerResponseQueueEntries

        return VStack(alignment: .leading, spacing: 12) {
            Text("Offer response queue")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Any live offer updates from sellers will appear here so you can respond quickly from the buyer hub.")
            } else {
                HighlightInformationCard(
                    title: "Stay on the front foot",
                    message: "Respond to counteroffers, requested changes, and open offers from here without losing the rest of your shortlist.",
                    supporting: "Every response continues inside the same verified deal room and secure thread."
                )

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    BuyerOfferQueueCard(
                        rank: index + 1,
                        entry: entry,
                        onRespond: {
                            offerComposer = OfferComposerContext(
                                mode: .buyer,
                                offer: entry.offer,
                                amount: entry.offer.amount,
                                conditions: entry.offer.conditions
                            )
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, seller: entry.seller)
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        }
                    )
                }
            }
        }
    }

    private var buyerConciergeAttentionQueue: some View {
        let items = filteredBuyerAttentionItems
        let selectedItems = items.filter { selectedAttentionItemIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Concierge attention queue")
                .font(.headline)

            if buyerAttentionItems.isEmpty {
                EmptyPanel(message: "No concierge provider follow-ups need attention right now. Urgent and due-soon provider replies will surface here once a settled deal needs action.")
            } else if items.isEmpty {
                ConciergeAttentionFilterPanel(
                    severityFilter: $attentionSeverityFilter,
                    serviceFilter: $attentionServiceFilter,
                    visibleCount: items.count,
                    totalCount: buyerAttentionItems.count,
                    selectedVisibleCount: selectedItems.count,
                    selectedTotalCount: selectedAttentionItemIDs.count,
                    onSelectVisible: {
                        selectedAttentionItemIDs.formUnion(items.map(\.id))
                    },
                    onClearSelection: {
                        selectedAttentionItemIDs.removeAll()
                    }
                )

                EmptyPanel(message: "No concierge reminders match the current filter. Change the scope or service filter to bring the rest of the queue back.")
            } else {
                HighlightInformationCard(
                    title: "Work the handover from one queue",
                    message: "This queue pulls overdue and due-soon concierge provider reply windows into one place so you can clear handover bottlenecks without opening each archive card first.",
                    supporting: "Select one or more provider rows below to run batch follow-up or snooze actions."
                )

                ConciergeAttentionFilterPanel(
                    severityFilter: $attentionSeverityFilter,
                    serviceFilter: $attentionServiceFilter,
                    visibleCount: items.count,
                    totalCount: buyerAttentionItems.count,
                    selectedVisibleCount: selectedItems.count,
                    selectedTotalCount: selectedAttentionItemIDs.count,
                    onSelectVisible: {
                        selectedAttentionItemIDs.formUnion(items.map(\.id))
                    },
                    onClearSelection: {
                        selectedAttentionItemIDs.removeAll()
                    }
                )

                AdaptiveTagGrid(minimum: 150) {
                    MiniStatPanel(
                        title: "Attention now",
                        value: "\(items.count)",
                        subtitle: "\(items.filter { $0.severity == .overdue }.count) urgent"
                    )
                    MiniStatPanel(
                        title: "Selected",
                        value: "\(selectedItems.count)",
                        subtitle: selectedItems.isEmpty ? "Choose provider rows below" : "Ready for batch actions"
                    )
                    if store.currentUser.conciergeReminderIntensity.showsDueSoonAttention {
                        MiniStatPanel(
                            title: "Due soon",
                            value: "\(items.filter { $0.severity == .dueSoon }.count)",
                            subtitle: "Upcoming provider reply windows"
                        )
                    }
                }

                HighlightInformationCard(
                    title: "Backup mode: \(store.currentUser.conciergeReplacementStrategy.title)",
                    message: "Any queue-generated provider replacement suggestions in Buyer Hub are being ranked with this strategy right now.",
                    supporting: store.currentUser.conciergeReplacementStrategy.detail
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        buyerAttentionBatchActionButtons(
                            selectedItems: selectedItems
                        )
                    }

                    VStack(alignment: .trailing, spacing: 10) {
                        buyerAttentionBatchActionButtons(
                            selectedItems: selectedItems
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                ForEach(PostSaleConciergeServiceKind.allCases, id: \.self) { serviceKind in
                    let groupItems = items.filter { $0.row.kind == serviceKind }

                    if !groupItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ConciergeAttentionSectionHeader(
                                serviceKind: serviceKind,
                                itemCount: groupItems.count,
                                urgentCount: groupItems.filter { $0.severity == .overdue }.count
                            )

                            ForEach(groupItems) { item in
                                let booking = item.entry.offer.conciergeBooking(for: item.row.kind)
                                let provider = booking?.provider
                                let previewTaskID = booking.map {
                                    "\(item.id)-\(conciergeReplacementPreviewFingerprint(for: $0, strategy: store.currentUser.conciergeReplacementStrategy))"
                                } ?? item.id
                                ConciergeAttentionQueueCard(
                                    title: item.row.title,
                                    listingTitle: item.entry.listing.title,
                                    listingSubtitle: item.entry.listing.address.fullLine,
                                    counterpartLabel: "Seller",
                                    counterpartName: item.entry.seller.name,
                                    recommendation: booking.map(conciergeAttentionRecommendation(for:)),
                                    statusText: item.row.statusText,
                                    detail: item.row.detail,
                                    activityLines: conciergeAttentionActivityLines(
                                        for: item.entry.offer,
                                        serviceKind: item.row.kind
                                    ),
                                    symbolName: item.row.kind.symbolName,
                                    severity: item.severity,
                                    isSelected: selectedAttentionItemIDs.contains(item.id),
                                    canLogFollowUp: item.row.canLogFollowUp,
                                    canSnooze: item.row.canSnoozeReminder,
                                    canConfirm: item.row.canConfirmProvider,
                                    canLogIssue: item.row.canLogIssue,
                                    currentProvider: provider,
                                    providerCallURL: provider.flatMap(conciergeProviderCallURL),
                                    providerWebsiteURL: provider?.websiteURL,
                                    providerMapsURL: provider?.mapsURL,
                                    suggestedReplacement: suggestedReplacementPreviews[item.id],
                                    isLoadingSuggestedReplacement: loadingSuggestedReplacementPreviewIDs.contains(item.id),
                                    isPreparingSuggestedReplacement: preparingSuggestedReplacementItemID == item.id,
                                    onToggleSelection: {
                                        toggleBuyerAttentionSelection(item)
                                    },
                                    onPrimaryAction: {
                                        handleBuyerConciergePrimaryAction(
                                            item.row.kind,
                                            booking: booking,
                                            for: item.entry
                                        )
                                    },
                                    onUseSuggestedReplacement: booking.map { resolvedBooking in
                                        {
                                            prepareBuyerSuggestedReplacement(
                                                item.row.kind,
                                                booking: resolvedBooking,
                                                itemID: item.id,
                                                cachedSuggestion: suggestedReplacementPreviews[item.id],
                                                for: item.entry
                                            )
                                        }
                                    },
                                    onOpenBooking: {
                                        openBuyerConciergeBooking(item.row.kind, for: item.entry)
                                    },
                                    onLogFollowUp: {
                                        logBuyerConciergeFollowUp(item.row.kind, for: item.entry)
                                    },
                                    onSnooze: {
                                        snoozeBuyerConciergeReminder(item.row.kind, for: item.entry)
                                    },
                                    onConfirm: {
                                        confirmBuyerConciergeProvider(item.row.kind, note: "", for: item.entry)
                                    },
                                    onLogIssue: {
                                        logBuyerConciergeIssue(item.row.kind, for: item.entry)
                                    },
                                    onOpenThread: {
                                        openConversation(for: item.entry.listing, seller: item.entry.seller)
                                    },
                                    onOpenListing: {
                                        selectedListing = item.entry.listing
                                    }
                                )
                                .task(id: previewTaskID) {
                                    guard let booking else { return }
                                    await prefetchBuyerSuggestedReplacementPreview(
                                        itemID: item.id,
                                        serviceKind: item.row.kind,
                                        booking: booking,
                                        entry: item.entry
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var buyerArchiveCentre: some View {
        let entries = settledBuyerArchiveEntries
        let reminderDashboard = store.currentUserConciergeReminderDashboard

        return VStack(alignment: .leading, spacing: 12) {
            Text("Settlement archive")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Completed private-sale purchases will move here with a downloadable closeout pack once settlement is confirmed.")
            } else {
                HighlightInformationCard(
                    title: "Closeout pack ready",
                    message: "Each completed purchase now keeps the signed contract, settlement paperwork, summary record, and handover checklist together in one archive.",
                    supporting: "Use the export button on any card to share the closeout pack with your records or legal team."
                )

                if reminderDashboard.hasEscalatedAttention {
                    ConciergeReminderEscalationCard(
                        title: "Buyer concierge attention",
                        dashboard: reminderDashboard
                    )
                }

                ForEach(entries) { entry in
                    DealArchiveCard(
                        title: entry.listing.title,
                        subtitle: entry.listing.address.fullLine,
                        counterpartLabel: "Seller",
                        counterpartName: entry.seller.name,
                        settlementDate: entry.offer.settlementCompletedAt,
                        amount: entry.offer.amount,
                        documents: archiveDocuments(for: entry.offer),
                        serviceRows: postSaleServiceRows(for: entry.offer),
                        conciergeRows: conciergeRows(for: entry.offer),
                        feedbackRows: postSaleFeedbackRows(for: entry.offer, currentRole: .buyer),
                        feedbackActionTitle: entry.offer.buyerFeedback == nil ? "Leave feedback" : "Update feedback",
                        onCompleteServiceTask: { task in
                            completeBuyerPostSaleTask(task, for: entry)
                        },
                        onManageConciergeService: { serviceKind in
                            openBuyerConciergeBooking(serviceKind, for: entry)
                        },
                        onOpenConciergeQuote: { serviceKind in
                            openBuyerConciergeQuote(serviceKind, for: entry)
                        },
                        onApproveConciergeQuote: { serviceKind in
                            approveBuyerConciergeQuote(serviceKind, for: entry)
                        },
                        onUploadConciergeInvoice: { serviceKind in
                            uploadBuyerConciergeInvoice(serviceKind, for: entry)
                        },
                        onOpenConciergeInvoice: { serviceKind in
                            openBuyerConciergeInvoice(serviceKind, for: entry)
                        },
                        onUploadConciergePaymentProof: { serviceKind in
                            uploadBuyerConciergePaymentProof(serviceKind, for: entry)
                        },
                        onOpenConciergePaymentProof: { serviceKind in
                            openBuyerConciergePaymentProof(serviceKind, for: entry)
                        },
                        onCancelConciergeService: { serviceKind in
                            cancelBuyerConciergeService(serviceKind, for: entry)
                        },
                        onRecordConciergeRefund: { serviceKind in
                            recordBuyerConciergeRefund(serviceKind, for: entry)
                        },
                        onLogConciergeIssue: { serviceKind in
                            logBuyerConciergeIssue(serviceKind, for: entry)
                        },
                        onResolveConciergeIssue: { serviceKind in
                            resolveBuyerConciergeIssue(serviceKind, for: entry)
                        },
                        onLogConciergeFollowUp: { serviceKind in
                            logBuyerConciergeFollowUp(serviceKind, for: entry)
                        },
                        onSnoozeConciergeReminder: { serviceKind in
                            snoozeBuyerConciergeReminder(serviceKind, for: entry)
                        },
                        onConfirmConciergeProvider: { serviceKind in
                            confirmBuyerConciergeProvider(serviceKind, note: "", for: entry)
                        },
                        onExportConciergeReceipt: { serviceKind in
                            exportBuyerConciergeReceipt(serviceKind, for: entry)
                        },
                        onOpenConciergeConfirmation: { serviceKind in
                            openBuyerConciergeConfirmation(serviceKind, for: entry)
                        },
                        onCompleteConciergeService: { serviceKind in
                            completeBuyerConciergeService(serviceKind, for: entry)
                        },
                        onLeaveFeedback: {
                            postSaleFeedbackContext = PostSaleFeedbackContext(
                                offerID: entry.offer.id,
                                listingID: entry.listing.id,
                                listingTitle: entry.listing.title,
                                counterpartName: entry.seller.name,
                                currentRole: .buyer,
                                existingEntry: entry.offer.buyerFeedback
                            )
                        },
                        onOpenDocument: { document in
                            openBuyerExecutionDocument(document, for: entry)
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, seller: entry.seller)
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        },
                        onShareArchive: {
                            prepareBuyerArchiveShare(for: entry)
                        }
                    )
                }
            }
        }
    }

    private func toggleBuyerAttentionSelection(_ item: BuyerConciergeAttentionItem) {
        if selectedAttentionItemIDs.contains(item.id) {
            selectedAttentionItemIDs.remove(item.id)
        } else {
            selectedAttentionItemIDs.insert(item.id)
        }
    }

    @ViewBuilder
    private func buyerAttentionBatchActionButtons(
        selectedItems: [BuyerConciergeAttentionItem]
    ) -> some View {
        Button(isBatchReplacingAttentionItems ? "Switching..." : "Review backups") {
            replaceSelectedBuyerAttentionItems(selectedItems)
        }
        .buttonStyle(.borderedProminent)
        .tint(BrandPalette.teal)
        .disabled(selectedItems.isEmpty || isBatchReplacingAttentionItems)

        Button("Log selected") {
            logSelectedBuyerAttentionItems(selectedItems)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.contains(where: \.row.canLogFollowUp) == false || isBatchReplacingAttentionItems)

        Button("Snooze 24h") {
            snoozeSelectedBuyerAttentionItems(selectedItems)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.contains(where: \.row.canSnoozeReminder) == false || isBatchReplacingAttentionItems)

        Button("Confirm selected") {
            confirmSelectedBuyerAttentionItems(selectedItems)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.contains(where: \.row.canConfirmProvider) == false || isBatchReplacingAttentionItems)
    }

    private func replaceSelectedBuyerAttentionItems(_ items: [BuyerConciergeAttentionItem]) {
        guard !items.isEmpty else {
            buyerHubAlert = BuyerHubAlert(
                title: "Nothing selected",
                message: "Select one or more provider rows first to review ranked backup changes."
            )
            return
        }

        batchReplacementReviewContext = makeBuyerBatchReplacementReviewContext(items)
    }

    private func makeBuyerBatchReplacementReviewContext(
        _ items: [BuyerConciergeAttentionItem],
        refreshSummary: ConciergeBatchReviewRefreshSummary? = nil,
        approvalRefreshSummary: ConciergeBatchReviewApprovalRefreshSummary? = nil,
        initialStagedEntryIDs: [String] = [],
        initialApprovedStagedEntryFingerprints: [String: String] = [:],
        initialRefreshHighlightedStagedEntryIDs: [String] = [],
        initialVisitedRefreshBookingEntryIDs: [String] = [],
        initialHasHiddenCompletedBookingLane: Bool = false,
        initialHasActiveBookingLaneReactivation: Bool = false,
        initialHasDismissedBookingLaneReactivationCompletion: Bool = false,
        initialReactivatedRefreshBookingEntryIDs: [String] = [],
        initialReactivationCompletionReviewLastItemID: String? = nil,
        initialReviewedReactivationCompletionItemIDs: [String] = [],
        entriesOverride: [ConciergeBatchReplacementReviewEntry]? = nil
    ) -> ConciergeBatchReplacementReviewContext {
        ConciergeBatchReplacementReviewContext(
            title: "Review ranked backups",
            hubTitle: "Buyer Hub",
            strategy: store.currentUser.conciergeReplacementStrategy,
            entries: entriesOverride ?? items.map(makeBuyerBatchReplacementReviewEntry),
            initialStagedEntryIDs: initialStagedEntryIDs,
            initialApprovedStagedEntryFingerprints: initialApprovedStagedEntryFingerprints,
            initialRefreshHighlightedStagedEntryIDs: initialRefreshHighlightedStagedEntryIDs,
            initialVisitedRefreshBookingEntryIDs: initialVisitedRefreshBookingEntryIDs,
            initialHasHiddenCompletedBookingLane: initialHasHiddenCompletedBookingLane,
            initialHasActiveBookingLaneReactivation: initialHasActiveBookingLaneReactivation,
            initialHasDismissedBookingLaneReactivationCompletion: initialHasDismissedBookingLaneReactivationCompletion,
            initialReactivatedRefreshBookingEntryIDs: initialReactivatedRefreshBookingEntryIDs,
            initialReactivationCompletionReviewLastItemID: initialReactivationCompletionReviewLastItemID,
            initialReviewedReactivationCompletionItemIDs: initialReviewedReactivationCompletionItemIDs,
            refreshSummary: refreshSummary,
            approvalRefreshSummary: approvalRefreshSummary
        )
    }

    private func makeBuyerBatchReplacementReviewEntry(
        _ item: BuyerConciergeAttentionItem
    ) -> ConciergeBatchReplacementReviewEntry {
        let booking = item.entry.offer.conciergeBooking(for: item.row.kind)
        let fingerprint = booking.map {
            conciergeReplacementPreviewFingerprint(
                for: $0,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
        }
        let cachedSuggestion: ConciergeReplacementSuggestion?
        if let booking,
           conciergeAttentionPrimaryAction(for: booking) == .switchProvider,
           let fingerprint,
           suggestedReplacementPreviewFingerprints[item.id] == fingerprint {
            cachedSuggestion = suggestedReplacementPreviews[item.id]
        } else {
            cachedSuggestion = nil
        }

        let manualReviewReason: String?
        let isLoadingSuggestion: Bool
        if let booking {
            if conciergeAttentionPrimaryAction(for: booking) != .switchProvider {
                manualReviewReason = "This provider thread is not currently in switch-provider mode, so it still needs manual review from the booking."
                isLoadingSuggestion = false
            } else if cachedSuggestion != nil {
                manualReviewReason = nil
                isLoadingSuggestion = false
            } else {
                manualReviewReason = nil
                isLoadingSuggestion = true
            }
        } else {
            manualReviewReason = "This concierge booking is no longer available in the settled archive."
            isLoadingSuggestion = false
        }

        return ConciergeBatchReplacementReviewEntry(
            id: item.id,
            offerID: item.entry.offer.id,
            listing: item.entry.listing,
            serviceKind: item.row.kind,
            counterpartLabel: "Seller",
            counterpartName: item.entry.seller.name,
            currentBooking: booking,
            reviewFingerprint: fingerprint,
            suggestedReplacement: cachedSuggestion,
            isLoadingSuggestion: isLoadingSuggestion,
            manualReviewReason: manualReviewReason
        )
    }

    private func confirmBuyerBatchReplacementReview(
        _ entries: [ConciergeBatchReplacementReviewEntry],
        returnContext: ConciergeBatchReviewReturnContext
    ) {
        let actionableEntries = entries.filter(\.canApplySuggestedReplacement)
        guard !actionableEntries.isEmpty else {
            buyerHubAlert = BuyerHubAlert(
                title: "No backups ready",
                message: "No selected provider rows finished with a ranked backup yet, so these bookings still need manual review."
            )
            return
        }

        batchReplacementReviewContext = nil
        isBatchReplacingAttentionItems = true

        Task {
            await performBuyerBatchReplacement(actionableEntries, returnContext: returnContext)
        }
    }

    private func openBuyerBatchReplacementReviewEntry(
        _ entry: ConciergeBatchReplacementReviewEntry,
        returnContext: ConciergeBatchReviewReturnContext
    ) {
        guard let offer = store.offer(id: entry.offerID),
              let listing = store.listing(id: offer.listingID),
              let seller = store.user(id: offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Booking unavailable",
                message: "That concierge booking is no longer available for manual review."
            )
            return
        }

        let currentBooking = offer.conciergeBooking(for: entry.serviceKind)
        let focus: PostSaleConciergeBookingFocus
        if let currentBooking,
           conciergeAttentionPrimaryAction(for: currentBooking) == .switchProvider {
            focus = .replacement
        } else {
            focus = .standard
        }

        let preferredProviderID = focus == .replacement ? entry.suggestedReplacement?.provider.id : nil
        let manualReviewContext = conciergeManualReviewContext(
            hubTitle: "Buyer Hub",
            entry: entry,
            focus: focus
        )
        batchReplacementReviewContext = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            conciergeBookingContext = PostSaleConciergeBookingContext(
                offerID: offer.id,
                listing: listing,
                serviceKind: entry.serviceKind,
                counterpartName: seller.name,
                focus: focus,
                preferredProviderID: preferredProviderID,
                preferredReplacementStrategy: store.currentUser.conciergeReplacementStrategy,
                currentBooking: currentBooking,
                manualReviewContext: manualReviewContext,
                batchReviewReturnContext: returnContext
            )
        }
    }

    private func reopenBuyerBatchReview(
        _ returnContext: ConciergeBatchReviewReturnContext,
        successTitle: String,
        successMessage: String
    ) {
        let refreshedItems = buyerAttentionItems.filter { returnContext.itemIDs.contains($0.id) }
        let survivingIDs = Set(refreshedItems.map(\.id))
        selectedAttentionItemIDs = survivingIDs

        guard refreshedItems.isEmpty == false else {
            batchReplacementReviewContext = nil
            let clearedCount = returnContext.itemIDs.count
            buyerHubAlert = BuyerHubAlert(
                title: "\(successTitle) • Review complete",
                message: "\(successMessage) \(clearedCount) selected review row\(clearedCount == 1 ? "" : "s") cleared from \(returnContext.hubTitle)."
            )
            return
        }

        let refreshedEntries = refreshedItems.map(makeBuyerBatchReplacementReviewEntry)
        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: returnContext.previousSnapshots.map { ($0.id, $0) }
        )
        let refreshedEntriesWithChangeHighlights = refreshedEntries.map { entry in
            var updatedEntry = entry
            if let previousSnapshot = previousSnapshotsByID[entry.id] {
                updatedEntry.rowChangeSummary = conciergeBatchReviewRowChangeSummary(
                    previousSnapshot: previousSnapshot,
                    refreshedEntry: entry
                )
            }
            return updatedEntry
        }
        let approvalRefreshState = conciergeBatchReviewStagedRefreshState(
            previousStagedEntryIDs: returnContext.stagedEntryIDs,
            previousApprovalFingerprints: returnContext.stagedApprovalFingerprints,
            previousRefreshHighlightedEntryIDs: returnContext.refreshHighlightedStagedEntryIDs,
            refreshedEntries: refreshedEntriesWithChangeHighlights
        )
        let refreshSummary = conciergeBatchReviewRefreshSummary(
            hubTitle: returnContext.hubTitle,
            actionTitle: successTitle,
            actionMessage: successMessage,
            previousSelectionCount: returnContext.itemIDs.count,
            refreshedEntries: refreshedEntriesWithChangeHighlights,
            itemTitlesByID: returnContext.itemTitlesByID,
            itemReferencesByID: returnContext.itemReferencesByID,
            currentStagedEntryIDs: approvalRefreshState.stagedEntryIDs,
            reviewedRefreshHighlightCount: returnContext.reviewedRefreshHighlightEntryIDs.count,
            appliedRefreshHighlightCount: returnContext.appliedRefreshHighlightEntryIDs.count,
            reviewedRefreshHighlightIDs: returnContext.reviewedRefreshHighlightEntryIDs,
            appliedRefreshHighlightIDs: returnContext.appliedRefreshHighlightEntryIDs
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            batchReplacementReviewContext = makeBuyerBatchReplacementReviewContext(
                refreshedItems,
                refreshSummary: refreshSummary,
                approvalRefreshSummary: approvalRefreshState.summary,
                initialStagedEntryIDs: approvalRefreshState.stagedEntryIDs,
                initialApprovedStagedEntryFingerprints: approvalRefreshState.approvalFingerprints,
                initialRefreshHighlightedStagedEntryIDs: approvalRefreshState.refreshHighlightedEntryIDs,
                initialVisitedRefreshBookingEntryIDs: returnContext.visitedRefreshBookingEntryIDs,
                initialHasHiddenCompletedBookingLane: returnContext.hasHiddenCompletedBookingLane,
                initialHasActiveBookingLaneReactivation: returnContext.hasActiveBookingLaneReactivation,
                initialHasDismissedBookingLaneReactivationCompletion: returnContext.hasDismissedBookingLaneReactivationCompletion,
                initialReactivatedRefreshBookingEntryIDs: returnContext.reactivatedRefreshBookingEntryIDs,
                initialReactivationCompletionReviewLastItemID: returnContext.reactivationCompletionReviewLastItemID,
                initialReviewedReactivationCompletionItemIDs: returnContext.reviewedReactivationCompletionItemIDs,
                entriesOverride: refreshedEntriesWithChangeHighlights
            )
        }
    }

    private func closeBuyerBatchReviewEntries(
        _ entryIDs: [String],
        remainingCount: Int
    ) {
        let idSet = Set(entryIDs)
        selectedAttentionItemIDs.subtract(idSet)

        guard remainingCount == 0 else {
            return
        }

        batchReplacementReviewContext = nil
        let closedCount = entryIDs.count
        buyerHubAlert = BuyerHubAlert(
            title: "Review complete",
            message: "Closed \(closedCount) safe review row\(closedCount == 1 ? "" : "s"). Buyer Hub only has unresolved concierge items selected now."
        )
    }

    @MainActor
    private func performBuyerBatchReplacement(
        _ entries: [ConciergeBatchReplacementReviewEntry],
        returnContext: ConciergeBatchReviewReturnContext? = nil
    ) async {
        defer { isBatchReplacingAttentionItems = false }

        var successCount = 0
        var unavailableCount = 0
        var succeededIDs: [String] = []

        for entry in entries {
            guard let reviewedSuggestion = entry.suggestedReplacement,
                  let offer = store.offer(id: entry.offerID),
                  let booking = offer.conciergeBooking(for: entry.serviceKind),
                  conciergeAttentionPrimaryAction(for: booking) == .switchProvider else {
                unavailableCount += 1
                continue
            }

            let currentFingerprint = conciergeReplacementPreviewFingerprint(
                for: booking,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
            guard entry.reviewFingerprint == currentFingerprint,
                  let seller = store.user(id: offer.sellerID),
                  let outcome = store.bookPostSaleConciergeService(
                    offerID: offer.id,
                    userID: store.currentUserID,
                    serviceKind: entry.serviceKind,
                    provider: reviewedSuggestion.provider,
                    scheduledFor: booking.scheduledFor,
                    notes: booking.notes,
                    estimatedCost: booking.estimatedCost
                  ) else {
                unavailableCount += 1
                continue
            }

            messaging.sendMessage(
                listing: entry.listing,
                from: store.currentUser,
                to: seller,
                body: outcome.threadMessage,
                isSystem: true
            )

            successCount += 1
            succeededIDs.append(entry.id)
            suggestedReplacementPreviews.removeValue(forKey: entry.id)
            suggestedReplacementPreviewFingerprints.removeValue(forKey: entry.id)
        }

        let manualReviewCount = entries.count - successCount - unavailableCount
        selectedAttentionItemIDs.subtract(succeededIDs)

        var messageParts: [String] = []
        if successCount > 0 {
            messageParts.append(
                "Switched \(successCount) concierge booking\(successCount == 1 ? "" : "s") to the best ranked backup from the attention queue."
            )
        }
        if manualReviewCount > 0 {
            messageParts.append(
                "\(manualReviewCount) booking\(manualReviewCount == 1 ? "" : "s") still need manual review because no ranked backup was available when the review sheet finished."
            )
        }
        if unavailableCount > 0 {
            messageParts.append(
                "\(unavailableCount) booking\(unavailableCount == 1 ? "" : "s") changed after review and were skipped so the switch stayed safe."
            )
        }

        let alertTitle = successCount == 0 ? "Replacement unavailable" : "Batch replacement complete"
        let alertMessage = messageParts.isEmpty
            ? "Those provider rows are no longer ready to switch."
            : messageParts.joined(separator: " ")

        if successCount > 0, let returnContext {
            reopenBuyerBatchReview(
                returnContext,
                successTitle: alertTitle,
                successMessage: alertMessage
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: alertTitle,
                message: alertMessage
            )
        }
    }

    private func logSelectedBuyerAttentionItems(_ items: [BuyerConciergeAttentionItem]) {
        let actionableItems = items.filter { $0.row.canLogFollowUp }
        guard !actionableItems.isEmpty else {
            buyerHubAlert = BuyerHubAlert(
                title: "Nothing to log",
                message: "Select at least one provider row that is ready for follow-up."
            )
            return
        }

        var successCount = 0
        for item in actionableItems {
            guard let outcome = store.logPostSaleConciergeFollowUp(
                offerID: item.entry.offer.id,
                userID: store.currentUserID,
                serviceKind: item.row.kind,
                note: ""
            ) else {
                continue
            }

            messaging.sendMessage(
                listing: item.entry.listing,
                from: store.currentUser,
                to: item.entry.seller,
                body: outcome.threadMessage,
                isSystem: true
            )
            successCount += 1
        }

        selectedAttentionItemIDs.subtract(actionableItems.map(\.id))
        buyerHubAlert = BuyerHubAlert(
            title: successCount == 0 ? "Follow-up unavailable" : "Batch follow-up logged",
            message: successCount == 0
                ? "Those provider rows are no longer ready for follow-up."
                : "Logged provider follow-up for \(successCount) concierge booking\(successCount == 1 ? "" : "s") from the attention queue."
        )
    }

    private func snoozeSelectedBuyerAttentionItems(_ items: [BuyerConciergeAttentionItem]) {
        let actionableItems = items.filter { $0.row.canSnoozeReminder }
        guard !actionableItems.isEmpty else {
            buyerHubAlert = BuyerHubAlert(
                title: "Nothing to snooze",
                message: "Select at least one provider row that can be snoozed for later."
            )
            return
        }

        var successCount = 0
        let snoozeUntil = Date().addingTimeInterval(60 * 60 * 24)
        for item in actionableItems {
            guard let outcome = store.snoozePostSaleConciergeFollowUp(
                offerID: item.entry.offer.id,
                userID: store.currentUserID,
                serviceKind: item.row.kind,
                until: snoozeUntil
            ) else {
                continue
            }

            messaging.sendMessage(
                listing: item.entry.listing,
                from: store.currentUser,
                to: item.entry.seller,
                body: outcome.threadMessage,
                isSystem: true
            )
            successCount += 1
        }

        selectedAttentionItemIDs.subtract(actionableItems.map(\.id))
        buyerHubAlert = BuyerHubAlert(
            title: successCount == 0 ? "Snooze unavailable" : "Batch snooze complete",
            message: successCount == 0
                ? "Those provider rows can no longer be snoozed."
                : "Snoozed \(successCount) concierge reminder\(successCount == 1 ? "" : "s") for 24 hours from the attention queue."
        )
    }

    private func confirmSelectedBuyerAttentionItems(_ items: [BuyerConciergeAttentionItem]) {
        let actionableItems = items.filter { $0.row.canConfirmProvider }
        guard !actionableItems.isEmpty else {
            buyerHubAlert = BuyerHubAlert(
                title: "Nothing to confirm",
                message: "Select at least one provider row that is ready to be marked confirmed."
            )
            return
        }

        var successCount = 0
        for item in actionableItems {
            guard let outcome = store.confirmPostSaleConciergeProvider(
                offerID: item.entry.offer.id,
                userID: store.currentUserID,
                serviceKind: item.row.kind,
                note: ""
            ) else {
                continue
            }

            messaging.sendMessage(
                listing: item.entry.listing,
                from: store.currentUser,
                to: item.entry.seller,
                body: outcome.threadMessage,
                isSystem: true
            )
            successCount += 1
        }

        selectedAttentionItemIDs.subtract(actionableItems.map(\.id))
        buyerHubAlert = BuyerHubAlert(
            title: successCount == 0 ? "Confirmation unavailable" : "Batch confirmation complete",
            message: successCount == 0
                ? "Those provider rows are no longer ready to be confirmed."
                : "Marked \(successCount) concierge provider\(successCount == 1 ? "" : "s") confirmed from the attention queue."
        )
    }

    private func conciergeRows(for offer: OfferRecord) -> [ArchiveConciergeRow] {
        PostSaleConciergeServiceKind.allCases.map { serviceKind in
            let booking = offer.conciergeBooking(for: serviceKind)
            let detail: String

            if let booking {
                let rescheduleSuffix = conciergeRescheduleSummary(for: booking).map { " \($0)" } ?? ""
                let issueSuffix = conciergeIssueSummary(for: booking).map { " \($0)" } ?? ""
                let confirmationSuffix = conciergeProviderConfirmationSummary(for: booking).map { " \($0)" } ?? ""
                let responseSlaSuffix = conciergeResponseSLASummary(for: booking).map { " \($0)" } ?? ""
                let followUpSuffix = conciergeFollowUpSummary(for: booking).map { " \($0)" } ?? ""
                if booking.isCancelled {
                        let cancelledDetail = booking.cancelledAt.map { " cancelled \(relativeDateString($0))" } ?? " cancelled"
                        let reasonDetail = booking.cancellationReason.map { " Reason: \($0)." } ?? ""
                    let refundDetail: String
                    if booking.isRefunded {
                        refundDetail = booking.refundAmount.map {
                            " Refund recorded: \(currencyString($0))."
                        } ?? " Refund recorded."
                    } else if booking.isPaid {
                        refundDetail = " Refund pending."
                    } else {
                        refundDetail = ""
                    }
                    detail = "\(booking.provider.name)\(cancelledDetail).\(reasonDetail)\(refundDetail)\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(rescheduleSuffix)\(issueSuffix)"
                } else if booking.isCompleted {
                    if let completedAt = booking.completedAt {
                        let quoteDetail = booking.isQuoteApproved ? " Quote approved." : " Quote approval pending."
                        let invoiceDetail = booking.invoiceAmount.map {
                            " Invoice total: \(currencyString($0))."
                        } ?? (booking.hasInvoiceAttachment ? " Invoice on file." : " Invoice not uploaded.")
                        let paymentDetail: String
                        if booking.isPaid {
                            let paidLine = booking.paidAmount.map { " Payment recorded: \(currencyString($0))." } ?? " Payment recorded."
                            paymentDetail = paidLine + (booking.hasPaymentProof ? " Proof on file." : "")
                        } else {
                            paymentDetail = booking.hasPaymentProof ? " Payment proof uploaded." : " Payment proof pending."
                        }
                        detail = "\(booking.provider.name) completed \(relativeDateString(completedAt)).\(quoteDetail)\(invoiceDetail)\(paymentDetail)\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(rescheduleSuffix)\(issueSuffix)"
                    } else {
                        detail = "\(booking.provider.name) has been marked complete for this settled deal.\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(rescheduleSuffix)\(issueSuffix)"
                    }
                } else {
                    let schedule = "\(shortDateString(booking.scheduledFor)) at \(timeString(booking.scheduledFor))"
                    let costSuffix = booking.estimatedCost.map { " Quote: \(currencyString($0))." } ?? ""
                    let quoteApprovalSuffix = booking.isQuoteApproved ? " Quote approved." : (booking.estimatedCost != nil ? " Quote approval pending." : "")
                    let invoiceSuffix = booking.invoiceAmount.map {
                        " Invoice total: \(currencyString($0))."
                    } ?? (booking.hasInvoiceAttachment ? " Invoice on file." : " Invoice not uploaded.")
                    let paymentSuffix: String
                    if booking.isPaid {
                        paymentSuffix = booking.paidAmount.map {
                            " Paid: \(currencyString($0))."
                        } ?? " Paid."
                    } else if booking.hasPaymentProof {
                        paymentSuffix = " Payment proof uploaded."
                    } else {
                        paymentSuffix = ""
                    }
                    let notesSuffix = booking.notes.isEmpty ? "" : " Notes: \(booking.notes)"
                    detail = "\(booking.provider.name) booked for \(schedule).\(costSuffix)\(quoteApprovalSuffix)\(invoiceSuffix)\(paymentSuffix)\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(notesSuffix)\(rescheduleSuffix)\(issueSuffix)"
                }
            } else {
                detail = serviceKind.detail
            }

            return ArchiveConciergeRow(
                kind: serviceKind,
                title: serviceKind.title,
                detail: detail,
                statusText: conciergeStatusText(for: booking),
                actionTitle: booking == nil ? "Book" : ((booking?.isCompleted == true || booking?.isCancelled == true) ? "Rebook" : "Update"),
                isBooked: booking != nil,
                isCompleted: booking?.isCompleted == true,
                isCancelled: booking?.isCancelled == true,
                isQuoteApproved: booking?.isQuoteApproved == true,
                isProviderConfirmed: booking?.isProviderConfirmed == true,
                isReminderSnoozed: booking?.isReminderSnoozed == true,
                isResponseDueSoon: booking?.isResponseDueSoon == true,
                needsFollowUp: booking?.needsResponseFollowUp == true,
                isPaid: booking?.isPaid == true,
                isRefunded: booking?.isRefunded == true,
                hasBeenRescheduled: booking?.hasBeenRescheduled == true,
                hasOpenIssue: booking?.hasOpenIssue == true,
                hasResolvedIssue: booking?.hasResolvedIssue == true,
                issueKindTitle: booking?.issueKind?.title,
                providerHistoryCount: booking?.providerHistoryCountValue ?? 0,
                latestProviderAuditSummary: booking.flatMap(conciergeProviderAuditSummary(for:)),
                estimatedCost: booking?.estimatedCost,
                invoiceAmount: booking?.invoiceAmount,
                paidAmount: booking?.paidAmount,
                refundAmount: booking?.refundAmount,
                canApproveQuote: booking?.estimatedCost != nil && booking?.isQuoteApproved != true && booking?.isCancelled != true && booking?.isRefunded != true,
                canCancel: booking != nil && booking?.isCompleted != true && booking?.isCancelled != true,
                canRecordRefund: booking != nil &&
                    booking?.isRefunded != true &&
                    ((booking?.isPaid == true) || (booking?.hasPaymentProof == true) || (booking?.invoiceAmount != nil) || (booking?.hasInvoiceAttachment == true)),
                canLogIssue: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isRefunded != true &&
                    booking?.hasOpenIssue != true,
                canResolveIssue: booking?.hasOpenIssue == true,
                canLogFollowUp: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isCompleted != true &&
                    booking?.isProviderConfirmed != true &&
                    ((booking?.needsResponseFollowUp == true) ||
                     (booking?.isResponseDueSoon == true) ||
                     (booking?.lastFollowUpAt != nil)),
                canSnoozeReminder: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isCompleted != true &&
                    booking?.isProviderConfirmed != true &&
                    booking?.isReminderSnoozed != true &&
                    ((booking?.needsResponseFollowUp == true) || (booking?.isResponseDueSoon == true)),
                canConfirmProvider: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isCompleted != true &&
                    booking?.isProviderConfirmed != true,
                canMarkDone: booking != nil && booking?.isCompleted != true && booking?.isCancelled != true && booking?.hasOpenIssue != true,
                canUploadInvoice: booking != nil && booking?.isCancelled != true,
                canUploadPaymentProof: booking != nil &&
                    ((booking?.invoiceAmount != nil) || (booking?.hasInvoiceAttachment == true)) &&
                    booking?.hasPaymentProof != true &&
                    booking?.isRefunded != true,
                hasInvoiceDocument: booking?.hasInvoiceAttachment == true,
                hasPaymentProofDocument: booking?.hasPaymentProof == true,
                hasQuoteDocument: booking?.estimatedCost != nil,
                hasConfirmationDocument: booking?.isCompleted == true
            )
        }
    }

    private func postSaleServiceRows(for offer: OfferRecord) -> [ArchiveServiceRow] {
        PostSaleServiceTaskKind.allCases.map { task in
            let completedAt = offer.completedAt(for: task)
            return ArchiveServiceRow(
                kind: task,
                title: task.title,
                detail: completedAt == nil
                    ? task.detail
                    : "\(task.title) completed \(relativeDateString(completedAt!)).",
                isCompleted: completedAt != nil
            )
        }
    }

    private func postSaleFeedbackRows(
        for offer: OfferRecord,
        currentRole: UserRole
    ) -> [ArchiveFeedbackRow] {
        let myFeedback = offer.feedback(for: currentRole)
        let counterpartRole: UserRole = currentRole == .buyer ? .seller : .buyer
        let counterpartFeedback = offer.feedback(for: counterpartRole)

        return [
            ArchiveFeedbackRow(
                id: "me",
                title: "Your feedback",
                detail: myFeedback.map {
                    "\($0.rating)-star rating • \(shortDateString($0.submittedAt))\n\($0.notes)"
                } ?? "No feedback saved yet for this settled deal.",
                isSubmitted: myFeedback != nil
            ),
            ArchiveFeedbackRow(
                id: "counterpart",
                title: counterpartRole == .buyer ? "Buyer feedback" : "Seller feedback",
                detail: counterpartFeedback.map {
                    "\($0.rating)-star rating • \(shortDateString($0.submittedAt))\n\($0.notes)"
                } ?? "No feedback has been shared by the other side yet.",
                isSubmitted: counterpartFeedback != nil
            )
        ]
    }

    private func nextChecklistItem(for offer: OfferRecord) -> SaleChecklistItem? {
        offer.settlementChecklist.first { $0.status != .completed }
    }

    private func buyerExecutionPrimaryAction(
        for entry: BuyerTransactionEntry
    ) -> BuyerDealExecutionActionDescriptor? {
        guard let nextItem = nextChecklistItem(for: entry.offer) else {
            return nil
        }

        let buyer = store.user(id: entry.offer.buyerID)
        let seller = store.user(id: entry.offer.sellerID)
        let missingContractIssueSteps = contractIssueMissingSteps(buyer: buyer, seller: seller)

        switch nextItem.id {
        case "buyer-representative":
            guard entry.offer.buyerLegalSelection == nil else {
                return nil
            }
            return BuyerDealExecutionActionDescriptor(
                title: "Choose buyer legal rep",
                supporting: "Lock in your conveyancer or solicitor so the deal room can move into contract issue.",
                kind: .chooseBuyerLegalRep
            )
        case "seller-representative":
            return BuyerDealExecutionActionDescriptor(
                title: "Prompt seller for legal rep",
                supporting: "Ask the seller to choose their representative so the contract packet can be issued.",
                kind: .nudgeSeller(
                    checklistItemID: nextItem.id,
                    body: "Buyer requested that the seller choose a legal representative so the contract packet can be issued for this private sale."
                )
            )
        case "contract-packet":
            if buyer?.hasVerifiedCheck(.finance) != true {
                return BuyerDealExecutionActionDescriptor(
                    title: "Upload finance proof",
                    supporting: "Buyer finance readiness still needs evidence before the contract packet can issue.",
                    kind: .uploadVerification(.finance)
                )
            }

            if entry.offer.buyerLegalSelection == nil {
                return BuyerDealExecutionActionDescriptor(
                    title: "Choose buyer legal rep",
                    supporting: "Your legal representative still needs to be selected before the contract can issue.",
                    kind: .chooseBuyerLegalRep
                )
            }

            if !missingContractIssueSteps.isEmpty {
                return BuyerDealExecutionActionDescriptor(
                    title: "Prompt seller to unblock contract",
                    supporting: missingContractIssueSteps.joined(separator: " • "),
                    kind: .nudgeSeller(
                        checklistItemID: nextItem.id,
                        body: "Buyer is ready to move forward. Seller-side setup is still blocking the contract packet: \(missingContractIssueSteps.joined(separator: "; "))."
                    )
                )
            }

            return nil
        case "workspace-invites", "workspace-active":
            return buyerInviteExecutionAction(for: entry.offer, checklistItemID: nextItem.id)
        case "contract-signatures":
            if let packet = entry.offer.contractPacket,
               packet.signedAt(for: store.currentUserID) == nil,
               !packet.isFullySigned {
                return BuyerDealExecutionActionDescriptor(
                    title: "Sign contract packet",
                    supporting: "Your contract sign-off is still needed before the sale can move into final settlement paperwork.",
                    kind: .signContract
                )
            }

            return BuyerDealExecutionActionDescriptor(
                title: "Prompt seller to sign",
                supporting: "Your sign-off is recorded. Ask the seller to complete the remaining signature.",
                kind: .nudgeSeller(
                    checklistItemID: nextItem.id,
                    body: "Buyer requested that the seller review and sign the contract packet so the private sale can keep moving toward settlement."
                )
            )
        case "legal-review-pack":
            return BuyerDealExecutionActionDescriptor(
                title: "Request legal review pack",
                supporting: "Ask the seller to follow up with legal reps so the reviewed contract and settlement adjustment PDFs are uploaded.",
                kind: .nudgeSeller(
                    checklistItemID: nextItem.id,
                    body: "Buyer requested an update on the legal review pack so the private sale can keep moving."
                )
            )
        case "settlement-statement":
            return BuyerDealExecutionActionDescriptor(
                title: "Request settlement statement",
                supporting: "Ask the seller to follow up with legal reps so the settlement statement PDF is uploaded.",
                kind: .nudgeSeller(
                    checklistItemID: nextItem.id,
                    body: "Buyer requested the settlement statement so final settlement paperwork can be completed."
                )
            )
        case "settlement-complete":
            return BuyerDealExecutionActionDescriptor(
                title: "Confirm settlement complete",
                supporting: "Close the file once funds, keys, and final handover are fully confirmed.",
                kind: .confirmSettlement
            )
        default:
            return nil
        }
    }

    private func buyerExecutionBlockingSummary(for entry: BuyerTransactionEntry) -> String? {
        guard let nextItem = nextChecklistItem(for: entry.offer) else {
            return nil
        }

        if nextItem.id == "contract-packet" {
            let missingSteps = contractIssueMissingSteps(
                buyer: store.user(id: entry.offer.buyerID),
                seller: store.user(id: entry.offer.sellerID)
            )
            if !missingSteps.isEmpty {
                return "Still blocked: \(missingSteps.joined(separator: " • "))"
            }
        }

        return nextItem.supporting
    }

    private func buyerInviteExecutionAction(
        for offer: OfferRecord,
        checklistItemID: String
    ) -> BuyerDealExecutionActionDescriptor? {
        let invites = offer.invites.sorted { left, right in
            if left.createdAt == right.createdAt {
                return left.role.rawValue < right.role.rawValue
            }
            return left.createdAt > right.createdAt
        }

        let buyerInvite: SaleWorkspaceInvite?
        if checklistItemID == "workspace-invites" {
            buyerInvite = invites.first(where: { $0.role == .buyerRepresentative && $0.isUnavailable })
                ?? invites.first(where: { $0.role == .buyerRepresentative && !$0.hasBeenShared })
                ?? invites.first(where: { $0.role == .buyerRepresentative && $0.needsFollowUp })
                ?? invites.first(where: { $0.role == .buyerRepresentative && !$0.isAcknowledged })
                ?? invites.first(where: { $0.role == .buyerRepresentative })
        } else {
            buyerInvite = invites.first(where: { $0.role == .buyerRepresentative && $0.isUnavailable })
                ?? invites.first(where: { $0.role == .buyerRepresentative && $0.needsFollowUp })
                ?? invites.first(where: { $0.role == .buyerRepresentative && !$0.isAcknowledged })
                ?? invites.first(where: { $0.role == .buyerRepresentative && !$0.isActivated })
                ?? invites.first(where: { $0.role == .buyerRepresentative })
        }

        guard let invite = buyerInvite else {
            return BuyerDealExecutionActionDescriptor(
                title: "Prompt seller for legal handoff",
                supporting: "Your side is ready. Ask the seller to finish the shared legal workspace setup.",
                kind: .nudgeSeller(
                    checklistItemID: checklistItemID,
                    body: "Buyer requested a follow-up on the shared legal workspace so the private sale can keep moving."
                )
            )
        }

        let audience = invite.role.audienceLabel.lowercased()
        if invite.isUnavailable {
            return BuyerDealExecutionActionDescriptor(
                title: "Regenerate \(audience) invite",
                supporting: "The current invite can no longer be opened, so a fresh share code is needed.",
                kind: .regenerateInvite(invite.role)
            )
        }

        let title = invite.hasBeenShared ? "Resend \(audience) invite" : "Share \(audience) invite"
        let supporting: String
        if invite.needsFollowUp {
            supporting = "This invite has not been opened yet. Resend it and keep your legal handoff moving."
        } else if invite.hasBeenShared {
            supporting = "The invite is already live. Resend it if your legal rep still needs the latest link and code."
        } else {
            supporting = "Send the invite link and code so your legal rep can join the shared workspace."
        }

        return BuyerDealExecutionActionDescriptor(
            title: title,
            supporting: supporting,
            kind: .shareInvite(invite.role)
        )
    }

    private func performBuyerExecutionAction(
        _ action: BuyerDealExecutionActionDescriptor,
        for entry: BuyerTransactionEntry
    ) {
        switch action.kind {
        case .chooseBuyerLegalRep:
            legalSearchContext = LegalSearchContext(offerID: entry.offer.id, role: .buyer)
        case let .shareInvite(role):
            guard let invite = entry.offer.invites
                .filter({ $0.role == role })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first else {
                buyerHubAlert = BuyerHubAlert(
                    title: "Invite unavailable",
                    message: "That legal workspace invite is no longer available."
                )
                return
            }

            shareInviteContext = SaleInviteShareContext(
                listingID: entry.listing.id,
                offerID: entry.offer.id,
                role: invite.role,
                title: invite.role.title,
                shareMessage: invite.shareMessage
            )
        case let .regenerateInvite(role):
            handleBuyerInviteManagement(
                listing: entry.listing,
                offer: entry.offer,
                role: role,
                action: .regenerate
            )
        case .signContract:
            handleBuyerContractSigning(listing: entry.listing, offer: entry.offer)
        case .confirmSettlement:
            handleBuyerSettlementCompletion(listing: entry.listing, offer: entry.offer)
        case let .uploadVerification(kind):
            pendingVerificationUploadKind = kind
        case let .nudgeSeller(checklistItemID, body):
            sendBuyerSellerNudge(
                listing: entry.listing,
                offer: entry.offer,
                checklistItemID: checklistItemID,
                body: body
            )
        }
    }

    private func handleBuyerOfferSubmission(
        listing: PropertyListing,
        amount: Int,
        conditions: String
    ) {
        if let moderationIssue = MarketplaceSafetyPolicy.moderationIssue(for: conditions) {
            buyerHubAlert = BuyerHubAlert(
                title: "Offer needs changes",
                message: moderationIssue.localizedDescription
            )
            return
        }

        guard let buyer = store.user(id: store.currentUserID),
              let seller = store.user(id: listing.sellerID),
              let outcome = store.submitOffer(
                listingID: listing.id,
                buyerID: buyer.id,
                amount: amount,
                conditions: conditions
              ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Offer unavailable",
                message: "Could not send the offer right now."
            )
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

        buyerHubAlert = BuyerHubAlert(
            title: "Offer updated",
            message: outcome.contractPacket == nil
                ? (outcome.isRevision ? "Offer updated and synced to the shared sale workspace." : "Offer sent securely to the seller.")
                : "Offer synced and the contract packet was refreshed in secure messages."
        )
        selectedConversationID = conversation.id
        selectedTab = .messages
    }

    private func handleBuyerLegalSelection(
        listing: PropertyListing,
        offerID: UUID,
        professional: LegalProfessional
    ) {
        guard let outcome = store.selectLegalProfessional(
            offerID: offerID,
            userID: store.currentUserID,
            professional: professional
        ),
        let updatedOffer = store.offer(id: offerID),
        let buyer = store.user(id: updatedOffer.buyerID),
        let seller = store.user(id: updatedOffer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Selection unavailable",
                message: "Could not save that legal representative right now."
            )
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
            buyerHubAlert = BuyerHubAlert(
                title: "Legal rep saved",
                message: "Buyer legal representative saved. The contract packet has been sent in secure messages."
            )
        } else if updatedOffer.isLegallyCoordinated {
            let missingSteps = contractIssueMissingSteps(buyer: buyer, seller: seller)
            buyerHubAlert = BuyerHubAlert(
                title: "Legal rep saved",
                message: missingSteps.isEmpty
                    ? "Buyer legal representative saved for this deal."
                    : "Buyer legal representative saved. Contract issue is waiting on: \(missingSteps.joined(separator: ", "))."
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: "Legal rep saved",
                message: "Buyer legal representative saved for this deal."
            )
        }
    }

    private func handleBuyerInviteManagement(
        listing: PropertyListing,
        offer: OfferRecord,
        role: LegalInviteRole,
        action: SaleInviteManagementAction
    ) {
        guard let outcome = store.manageSaleInvite(
            offerID: offer.id,
            role: role,
            action: action,
            triggeredBy: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Invite unavailable",
                message: "Could not update that legal workspace invite right now."
            )
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

        buyerHubAlert = BuyerHubAlert(
            title: "Invite updated",
            message: outcome.noticeMessage
        )
    }

    private func handleBuyerInviteShare(
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
            buyerHubAlert = BuyerHubAlert(
                title: "Invite unavailable",
                message: "Could not track that invite share right now."
            )
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

        buyerHubAlert = BuyerHubAlert(
            title: "Invite shared",
            message: outcome.noticeMessage
        )
    }

    private func handleBuyerContractSigning(
        listing: PropertyListing,
        offer: OfferRecord
    ) {
        guard let outcome = store.signContractPacket(
            offerID: offer.id,
            userID: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Signing unavailable",
                message: "Could not record the contract sign-off right now."
            )
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

        buyerHubAlert = BuyerHubAlert(
            title: "Contract updated",
            message: outcome.noticeMessage
        )
    }

    private func handleBuyerSettlementCompletion(
        listing: PropertyListing,
        offer: OfferRecord
    ) {
        guard let outcome = store.completeSettlement(
            offerID: offer.id,
            userID: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Settlement unavailable",
                message: "Could not close out settlement right now."
            )
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
                checklistItemID: "settlement-complete"
            )
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Settlement complete",
            message: outcome.noticeMessage
        )
    }

    private func sendBuyerSellerNudge(
        listing: PropertyListing,
        offer: OfferRecord,
        checklistItemID: String,
        body: String
    ) {
        guard let buyer = store.user(id: offer.buyerID),
              let seller = store.user(id: offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Seller unavailable",
                message: "Could not send that reminder right now."
            )
            return
        }

        messaging.sendMessage(
            listing: listing,
            from: buyer,
            to: seller,
            body: body,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: offer.id,
                checklistItemID: checklistItemID
            )
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Seller notified",
            message: "A secure follow-up was sent to the seller for this milestone."
        )
    }

    private func handleImportedVerificationDocument(_ result: Result<[URL], Error>) {
        guard let kind = pendingVerificationUploadKind else {
            return
        }

        defer { pendingVerificationUploadKind = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                buyerHubAlert = BuyerHubAlert(
                    title: "Upload cancelled",
                    message: "No PDF was selected."
                )
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? defaultVerificationUploadFileName(for: kind)
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let outcome = store.uploadVerificationDocument(
                    userID: store.currentUserID,
                    kind: kind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf"
                ) else {
                    buyerHubAlert = BuyerHubAlert(
                        title: "Upload unavailable",
                        message: "Could not attach that verification PDF right now."
                    )
                    return
                }

                for unlocked in outcome.unlockedContractPackets {
                    guard let unlockedListing = store.listing(id: unlocked.offer.listingID),
                          let buyer = store.user(id: unlocked.offer.buyerID),
                          let seller = store.user(id: unlocked.offer.sellerID) else {
                        continue
                    }

                    messaging.sendContractPacket(
                        listing: unlockedListing,
                        offerID: unlocked.offer.id,
                        buyer: buyer,
                        seller: seller,
                        packet: unlocked.packet,
                        triggeredBy: store.currentUser
                    )
                }

                buyerHubAlert = BuyerHubAlert(
                    title: "Verification updated",
                    message: outcome.unlockedContractPackets.isEmpty
                        ? outcome.noticeMessage
                        : "\(outcome.noticeMessage) Open secure messages to see the updated contract packet."
                )
            } catch {
                buyerHubAlert = BuyerHubAlert(
                    title: "Upload unavailable",
                    message: "Could not read that verification PDF right now."
                )
            }
        case .failure:
            buyerHubAlert = BuyerHubAlert(
                title: "Upload cancelled",
                message: "The PDF picker was cancelled."
            )
        }
    }

    private func keyBuyerExecutionDocuments(for offer: OfferRecord) -> [SaleDocument] {
        let preferredKinds: [SaleDocumentKind] = [
            .settlementStatementPDF,
            .signedContractPDF,
            .reviewedContractPDF,
            .settlementAdjustmentPDF,
            .contractPacketPDF,
            .buyerFinanceProofPDF
        ]

        let latestByKind = store.saleDocuments(for: offer.id).reduce(into: [SaleDocumentKind: SaleDocument]()) { result, document in
            if let existing = result[document.kind], existing.createdAt >= document.createdAt {
                return
            }
            result[document.kind] = document
        }

        return preferredKinds.compactMap { latestByKind[$0] }
    }

    private func archiveDocuments(for offer: OfferRecord) -> [SaleDocument] {
        let preferredKinds: [SaleDocumentKind] = [
            .settlementSummaryPDF,
            .handoverChecklistPDF,
            .settlementStatementPDF,
            .signedContractPDF,
            .reviewedContractPDF,
            .settlementAdjustmentPDF,
            .contractPacketPDF
        ]

        let latestByKind = store.saleDocuments(for: offer.id).reduce(into: [SaleDocumentKind: SaleDocument]()) { result, document in
            if let existing = result[document.kind], existing.createdAt >= document.createdAt {
                return
            }
            result[document.kind] = document
        }

        return preferredKinds.compactMap { latestByKind[$0] }
    }

    private func openBuyerExecutionDocument(
        _ document: SaleDocument,
        for entry: BuyerTransactionEntry
    ) {
        do {
            preparedDocument = try SaleDocumentRenderer.render(
                document: document,
                listing: entry.listing,
                offer: entry.offer,
                buyer: store.currentUser,
                seller: entry.seller
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Preview unavailable",
                message: "Could not prepare the PDF preview right now."
            )
        }
    }

    private func prepareBuyerArchiveShare(for entry: BuyerTransactionEntry) {
        let documents = archiveDocuments(for: entry.offer)
        let conciergeBookings = entry.offer.conciergeBookings
        guard !documents.isEmpty || !conciergeBookings.isEmpty else {
            buyerHubAlert = BuyerHubAlert(
                title: "Archive unavailable",
                message: "There are no closeout documents ready to export for this settled deal yet."
            )
            return
        }

        do {
            let rendered = try documents.map {
                try SaleDocumentRenderer.render(
                    document: $0,
                    listing: entry.listing,
                    offer: entry.offer,
                    buyer: store.currentUser,
                    seller: entry.seller
                )
            } + conciergeBookings.map {
                try SaleDocumentRenderer.renderPostSaleConciergeReceipt(
                    booking: $0,
                    listing: entry.listing,
                    offer: entry.offer,
                    buyer: store.currentUser,
                    seller: entry.seller
                )
            }
            archiveShareContext = SaleArchiveShareContext(
                title: "Real O Who closeout pack",
                fileURLs: rendered.map(\.url)
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Archive unavailable",
                message: "Could not prepare the closeout pack right now."
            )
        }
    }

    private func completeBuyerPostSaleTask(
        _ task: PostSaleServiceTaskKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let outcome = store.completePostSaleServiceTask(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            task: task
        ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Service unavailable",
                message: "That post-sale service step is already complete or not ready yet."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Archive updated",
            message: outcome.noticeMessage
        )
    }

    private func openBuyerConciergeBooking(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry,
        focus: PostSaleConciergeBookingFocus = .standard,
        preferredProviderID: String? = nil
    ) {
        conciergeBookingContext = PostSaleConciergeBookingContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.seller.name,
            focus: focus,
            preferredProviderID: preferredProviderID,
            preferredReplacementStrategy: store.currentUser.conciergeReplacementStrategy,
            currentBooking: entry.offer.conciergeBooking(for: serviceKind)
        )
    }

    private func handleBuyerConciergePrimaryAction(
        _ serviceKind: PostSaleConciergeServiceKind,
        booking: PostSaleConciergeBooking?,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking else {
            openBuyerConciergeBooking(serviceKind, for: entry)
            return
        }

        switch conciergeAttentionPrimaryAction(for: booking) {
        case .switchProvider:
            openBuyerConciergeBooking(serviceKind, for: entry, focus: .replacement)
        case .callProvider:
            if let callURL = conciergeProviderCallURL(booking.provider) {
                openURL(callURL)
            } else {
                openBuyerConciergeBooking(serviceKind, for: entry)
            }
        case .reviewBooking, .viewBooking:
            openBuyerConciergeBooking(serviceKind, for: entry)
        }
    }

    private func prepareBuyerSuggestedReplacement(
        _ serviceKind: PostSaleConciergeServiceKind,
        booking: PostSaleConciergeBooking,
        itemID: String,
        cachedSuggestion: ConciergeReplacementSuggestion? = nil,
        for entry: BuyerTransactionEntry
    ) {
        if let cachedSuggestion {
            openBuyerConciergeBooking(
                serviceKind,
                for: entry,
                focus: .replacement,
                preferredProviderID: cachedSuggestion.provider.id
            )
            buyerHubAlert = BuyerHubAlert(
                title: "Best backup ready",
                message: "\(cachedSuggestion.provider.name) is already ranked as the strongest replacement for this \(serviceKind.title.lowercased()) booking."
            )
            return
        }

        preparingSuggestedReplacementItemID = itemID

        Task {
            do {
                let providers = try await store.searchPostSaleConciergeProviders(
                    for: entry.listing,
                    serviceKind: serviceKind
                )
                let bestProvider = bestConciergeReplacementProvider(
                    for: booking,
                    listing: entry.listing,
                    candidates: providers,
                    strategy: store.currentUser.conciergeReplacementStrategy
                )

                await MainActor.run {
                    preparingSuggestedReplacementItemID = nil
                    openBuyerConciergeBooking(
                        serviceKind,
                        for: entry,
                        focus: .replacement,
                        preferredProviderID: bestProvider?.id
                    )
                    buyerHubAlert = BuyerHubAlert(
                        title: bestProvider == nil ? "Replacement options opened" : "Best backup ready",
                        message: bestProvider == nil
                            ? "No ranked backup was available yet, so the full replacement sheet is open for manual selection."
                            : "\(bestProvider!.name) is preselected as the strongest replacement for this \(serviceKind.title.lowercased()) booking."
                    )
                }
            } catch {
                await MainActor.run {
                    preparingSuggestedReplacementItemID = nil
                    openBuyerConciergeBooking(serviceKind, for: entry, focus: .replacement)
                    buyerHubAlert = BuyerHubAlert(
                        title: "Replacement search unavailable",
                        message: "Could not rank local backups right now, but the replacement sheet is open so you can choose one manually."
                    )
                }
            }
        }
    }

    @MainActor
    private func prefetchBuyerSuggestedReplacementPreview(
        itemID: String,
        serviceKind: PostSaleConciergeServiceKind,
        booking: PostSaleConciergeBooking,
        entry: BuyerTransactionEntry
    ) async {
        let fingerprint = conciergeReplacementPreviewFingerprint(
            for: booking,
            strategy: store.currentUser.conciergeReplacementStrategy
        )
        guard conciergeAttentionPrimaryAction(for: booking) == .switchProvider,
              suggestedReplacementPreviewFingerprints[itemID] != fingerprint ||
                suggestedReplacementPreviews[itemID] == nil,
              loadingSuggestedReplacementPreviewIDs.contains(itemID) == false else {
            return
        }

        loadingSuggestedReplacementPreviewIDs.insert(itemID)
        defer { loadingSuggestedReplacementPreviewIDs.remove(itemID) }

        do {
            let providers = try await store.searchPostSaleConciergeProviders(
                for: entry.listing,
                serviceKind: serviceKind
            )
            let rankedProviders = rankedConciergeReplacementProviders(
                for: booking,
                listing: entry.listing,
                candidates: providers,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
            guard let bestProvider = rankedProviders.first else {
                return
            }

            suggestedReplacementPreviews[itemID] = conciergeReplacementSuggestion(
                for: bestProvider,
                currentBooking: booking,
                listing: entry.listing,
                rankedCandidates: rankedProviders,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
            suggestedReplacementPreviewFingerprints[itemID] = fingerprint
        } catch {
            return
        }
    }

    private func handleBuyerReminderTarget(_ target: SaleReminderNavigationTarget?) {
        guard let target,
              let serviceKind = target.conciergeServiceKind else {
            return
        }
        defer { onResolveReminderTarget(target) }

        guard let offer = store.offer(id: target.offerID),
              offer.buyerID == store.currentUserID,
              let listing = store.listing(id: offer.listingID),
              let seller = store.user(id: offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Reminder unavailable",
                message: "That concierge reminder is no longer available."
            )
            return
        }

        let booking = offer.conciergeBooking(for: serviceKind)
        if let booking {
            conciergeBookingContext = PostSaleConciergeBookingContext(
                offerID: offer.id,
                listing: listing,
                serviceKind: serviceKind,
                counterpartName: seller.name,
                focus: .standard,
                preferredProviderID: nil,
                preferredReplacementStrategy: store.currentUser.conciergeReplacementStrategy,
                currentBooking: booking
            )

            let alertTitle: String
            let alertMessage: String
            if booking.needsResponseFollowUp {
                alertTitle = "\(serviceKind.title) follow-up due"
                alertMessage = "\(booking.provider.name) has not confirmed this booking yet. Open the booking to log a provider follow-up or snooze the reminder."
            } else if booking.isResponseDueSoon, let responseDueAt = booking.responseDueAt {
                alertTitle = "\(serviceKind.title) reply due soon"
                alertMessage = "\(booking.provider.name) is expected to reply by \(responseDueAt.formatted(date: .abbreviated, time: .shortened)). Open the booking to stay on top of the handover."
            } else {
                alertTitle = "\(serviceKind.title) booking opened"
                alertMessage = "This booking is open so you can review the current provider status."
            }

            buyerHubAlert = BuyerHubAlert(
                title: alertTitle,
                message: alertMessage
            )
            return
        }

        buyerHubAlert = BuyerHubAlert(
            title: "Reminder unavailable",
            message: "This provider reminder is no longer active."
        )
    }

    private func bookBuyerPostSaleConciergeService(
        context: PostSaleConciergeBookingContext,
        provider: PostSaleConciergeProvider,
        scheduledFor: Date,
        notes: String,
        estimatedCost: Int?
    ) {
        guard let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID),
              let outcome = store.bookPostSaleConciergeService(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                provider: provider,
                scheduledFor: scheduledFor,
                notes: notes,
                estimatedCost: estimatedCost
              ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Booking unavailable",
                message: "Could not save that moving concierge booking right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenBuyerBatchReview(
                batchReviewReturnContext,
                successTitle: "Booking saved",
                successMessage: outcome.noticeMessage
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: "Booking saved",
                message: outcome.noticeMessage
            )
        }
    }

    private func confirmBuyerConciergeProvider(
        context: PostSaleConciergeBookingContext,
        note: String
    ) {
        guard let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID),
              let outcome = store.confirmPostSaleConciergeProvider(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                note: note
              ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Confirmation unavailable",
                message: "That concierge booking is not ready for provider confirmation right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenBuyerBatchReview(
                batchReviewReturnContext,
                successTitle: "Provider confirmed",
                successMessage: outcome.noticeMessage
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: "Provider confirmed",
                message: outcome.noticeMessage
            )
        }
    }

    private func logBuyerConciergeFollowUp(
        context: PostSaleConciergeBookingContext
    ) {
        guard let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID),
              let outcome = store.logPostSaleConciergeFollowUp(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                note: ""
              ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Follow-up unavailable",
                message: "That concierge booking is not ready for provider follow-up right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenBuyerBatchReview(
                batchReviewReturnContext,
                successTitle: "Follow-up logged",
                successMessage: outcome.noticeMessage
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: "Follow-up logged",
                message: outcome.noticeMessage
            )
        }
    }

    private func snoozeBuyerConciergeReminder(
        context: PostSaleConciergeBookingContext
    ) {
        guard let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID),
              let outcome = store.snoozePostSaleConciergeFollowUp(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                until: Date().addingTimeInterval(60 * 60 * 24)
              ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Snooze unavailable",
                message: "That concierge follow-up cannot be snoozed right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenBuyerBatchReview(
                batchReviewReturnContext,
                successTitle: "Reminder snoozed",
                successMessage: outcome.noticeMessage
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: "Reminder snoozed",
                message: outcome.noticeMessage
            )
        }
    }

    private func openBuyerConciergeResolution(
        context: PostSaleConciergeBookingContext,
        mode: PostSaleConciergeResolutionMode
    ) {
        guard let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID),
              let booking = offer.conciergeBooking(for: context.serviceKind) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Review unavailable",
                message: "That concierge booking is no longer available for a review update."
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            conciergeResolutionContext = PostSaleConciergeResolutionContext(
                offerID: offer.id,
                listing: context.listing,
                serviceKind: context.serviceKind,
                counterpartName: seller.name,
                booking: booking,
                mode: mode,
                batchReviewReturnContext: context.batchReviewReturnContext
            )
        }
    }

    private func openBuyerConciergeQuote(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              booking.estimatedCost != nil else {
            buyerHubAlert = BuyerHubAlert(
                title: "Quote unavailable",
                message: "There is no quote summary ready for that concierge booking yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderPostSaleConciergeQuote(
                booking: booking,
                listing: entry.listing,
                offer: entry.offer,
                buyer: store.currentUser,
                seller: entry.seller
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Quote unavailable",
                message: "Could not prepare that quote summary right now."
            )
        }
    }

    private func approveBuyerConciergeQuote(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let outcome = store.approvePostSaleConciergeQuote(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind
        ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Approval unavailable",
                message: "That concierge quote is not ready to approve right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Quote approved",
            message: outcome.noticeMessage
        )
    }

    private func uploadBuyerConciergeInvoice(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        conciergeInvoiceUploadContext = PostSaleConciergeInvoiceUploadContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind
        )
    }

    private func openBuyerConciergeInvoice(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              let fileName = booking.invoiceFileName,
              let attachmentBase64 = booking.invoiceAttachmentBase64 else {
            buyerHubAlert = BuyerHubAlert(
                title: "Invoice unavailable",
                message: "There is no uploaded invoice on file for that concierge booking yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderAttachment(
                title: "\(serviceKind.title) invoice",
                fileName: fileName,
                attachmentBase64: attachmentBase64
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Invoice unavailable",
                message: "Could not prepare that invoice PDF right now."
            )
        }
    }

    private func uploadBuyerConciergePaymentProof(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        conciergePaymentUploadContext = PostSaleConciergePaymentUploadContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind
        )
    }

    private func openBuyerConciergePaymentProof(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              let fileName = booking.paymentProofFileName,
              let attachmentBase64 = booking.paymentProofAttachmentBase64 else {
            buyerHubAlert = BuyerHubAlert(
                title: "Payment proof unavailable",
                message: "There is no uploaded payment proof on file for that concierge booking yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderAttachment(
                title: "\(serviceKind.title) payment proof",
                fileName: fileName,
                attachmentBase64: attachmentBase64
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Payment proof unavailable",
                message: "Could not prepare that payment proof PDF right now."
            )
        }
    }

    private func cancelBuyerConciergeService(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Cancellation unavailable",
                message: "There is no concierge booking to cancel right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.seller.name,
            booking: booking,
            mode: .cancel
        )
    }

    private func recordBuyerConciergeRefund(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Refund unavailable",
                message: "There is no concierge booking ready for a refund record right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.seller.name,
            booking: booking,
            mode: .refund
        )
    }

    private func logBuyerConciergeIssue(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Issue unavailable",
                message: "There is no concierge booking ready for an issue log right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.seller.name,
            booking: booking,
            mode: .logIssue
        )
    }

    private func resolveBuyerConciergeIssue(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Issue unavailable",
                message: "There is no concierge booking issue to resolve right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.seller.name,
            booking: booking,
            mode: .resolveIssue
        )
    }

    private func confirmBuyerConciergeProvider(
        _ serviceKind: PostSaleConciergeServiceKind,
        note: String,
        for entry: BuyerTransactionEntry?
    ) {
        guard let entry else {
            buyerHubAlert = BuyerHubAlert(
                title: "Confirmation unavailable",
                message: "That concierge booking is no longer available."
            )
            return
        }

        guard let outcome = store.confirmPostSaleConciergeProvider(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind,
            note: note
        ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Confirmation unavailable",
                message: "That concierge booking is not ready for provider confirmation right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Provider confirmed",
            message: outcome.noticeMessage
        )
    }

    private func logBuyerConciergeFollowUp(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let outcome = store.logPostSaleConciergeFollowUp(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind,
            note: ""
        ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Follow-up unavailable",
                message: "That concierge booking is not ready for provider follow-up right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Follow-up logged",
            message: outcome.noticeMessage
        )
    }

    private func snoozeBuyerConciergeReminder(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let outcome = store.snoozePostSaleConciergeFollowUp(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind,
            until: Date().addingTimeInterval(60 * 60 * 24)
        ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Snooze unavailable",
                message: "That concierge follow-up cannot be snoozed right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Reminder snoozed",
            message: outcome.noticeMessage
        )
    }

    private func exportBuyerConciergeReceipt(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Receipt unavailable",
                message: "There is no concierge booking receipt ready to export yet."
            )
            return
        }

        do {
            let receipt = try SaleDocumentRenderer.renderPostSaleConciergeReceipt(
                booking: booking,
                listing: entry.listing,
                offer: entry.offer,
                buyer: store.currentUser,
                seller: entry.seller
            )
            archiveShareContext = SaleArchiveShareContext(
                title: "Real O Who concierge receipt",
                fileURLs: [receipt.url]
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Receipt unavailable",
                message: "Could not prepare that concierge receipt right now."
            )
        }
    }

    private func openBuyerConciergeConfirmation(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              booking.isCompleted else {
            buyerHubAlert = BuyerHubAlert(
                title: "Proof unavailable",
                message: "That concierge booking has not been completed yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderPostSaleConciergeConfirmation(
                booking: booking,
                listing: entry.listing,
                offer: entry.offer,
                buyer: store.currentUser,
                seller: entry.seller
            )
        } catch {
            buyerHubAlert = BuyerHubAlert(
                title: "Proof unavailable",
                message: "Could not prepare that service completion proof right now."
            )
        }
    }

    private func completeBuyerConciergeService(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: BuyerTransactionEntry
    ) {
        guard let outcome = store.completePostSaleConciergeBooking(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind
        ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Update unavailable",
                message: "Could not mark that concierge booking complete right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Archive updated",
            message: outcome.noticeMessage
        )
    }

    private func handleBuyerConciergeResolution(
        context: PostSaleConciergeResolutionContext,
        issueKind: PostSaleConciergeIssueKind?,
        note: String,
        amount: Int?
    ) {
        guard let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Archive unavailable",
                message: "That concierge update is no longer available."
            )
            return
        }

        let outcome: PostSaleConciergeBookingOutcome?
        let successTitle: String

        switch context.mode {
        case .cancel:
            outcome = store.cancelPostSaleConciergeBooking(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                reason: note
            )
            successTitle = "Booking cancelled"
        case .refund:
            outcome = store.recordPostSaleConciergeRefund(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                refundAmount: amount,
                note: note
            )
            successTitle = "Refund recorded"
        case .logIssue:
            outcome = store.logPostSaleConciergeIssue(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                issueKind: issueKind ?? .other,
                note: note
            )
            successTitle = "Issue logged"
        case .resolveIssue:
            outcome = store.resolvePostSaleConciergeIssue(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                resolutionNote: note
            )
            successTitle = "Issue resolved"
        }

        guard let outcome else {
            buyerHubAlert = BuyerHubAlert(
                title: "Update unavailable",
                message: "Could not save that concierge update right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenBuyerBatchReview(
                batchReviewReturnContext,
                successTitle: successTitle,
                successMessage: outcome.noticeMessage
            )
        } else {
            buyerHubAlert = BuyerHubAlert(
                title: successTitle,
                message: outcome.noticeMessage
            )
        }
    }

    private func handleImportedConciergeInvoice(_ result: Result<[URL], Error>) {
        guard let context = conciergeInvoiceUploadContext else {
            return
        }

        defer { conciergeInvoiceUploadContext = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let listing = store.listing(id: context.listing.id),
                  let offer = store.offer(id: context.offerID),
                  let seller = store.user(id: offer.sellerID) else {
                buyerHubAlert = BuyerHubAlert(
                    title: "Invoice unavailable",
                    message: "No PDF was selected."
                )
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? "concierge-invoice.pdf"
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let estimatedCost = offer.conciergeBooking(for: context.serviceKind)?.estimatedCost
                guard let outcome = store.uploadPostSaleConciergeInvoice(
                    offerID: context.offerID,
                    userID: store.currentUserID,
                    serviceKind: context.serviceKind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf",
                    invoiceAmount: estimatedCost
                ) else {
                    buyerHubAlert = BuyerHubAlert(
                        title: "Invoice unavailable",
                        message: "Could not save that invoice right now."
                    )
                    return
                }

                messaging.sendMessage(
                    listing: listing,
                    from: store.currentUser,
                    to: seller,
                    body: outcome.threadMessage,
                    isSystem: true
                )

                buyerHubAlert = BuyerHubAlert(
                    title: "Invoice saved",
                    message: outcome.noticeMessage
                )
            } catch {
                buyerHubAlert = BuyerHubAlert(
                    title: "Invoice unavailable",
                    message: "Could not read that invoice PDF right now."
                )
            }
        case .failure:
            buyerHubAlert = BuyerHubAlert(
                title: "Invoice unavailable",
                message: "Could not import that invoice PDF right now."
            )
        }
    }

    private func handleImportedConciergePaymentProof(_ result: Result<[URL], Error>) {
        guard let context = conciergePaymentUploadContext else {
            return
        }

        defer { conciergePaymentUploadContext = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let listing = store.listing(id: context.listing.id),
                  let offer = store.offer(id: context.offerID),
                  let seller = store.user(id: offer.sellerID) else {
                buyerHubAlert = BuyerHubAlert(
                    title: "Payment proof unavailable",
                    message: "No PDF was selected."
                )
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? "concierge-payment-proof.pdf"
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let paidAmount = offer.conciergeBooking(for: context.serviceKind)?.invoiceAmount ??
                    offer.conciergeBooking(for: context.serviceKind)?.estimatedCost
                guard let outcome = store.uploadPostSaleConciergePaymentProof(
                    offerID: context.offerID,
                    userID: store.currentUserID,
                    serviceKind: context.serviceKind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf",
                    paidAmount: paidAmount
                ) else {
                    buyerHubAlert = BuyerHubAlert(
                        title: "Payment proof unavailable",
                        message: "Could not save that payment proof right now."
                    )
                    return
                }

                messaging.sendMessage(
                    listing: listing,
                    from: store.currentUser,
                    to: seller,
                    body: outcome.threadMessage,
                    isSystem: true
                )

                buyerHubAlert = BuyerHubAlert(
                    title: "Payment proof saved",
                    message: outcome.noticeMessage
                )
            } catch {
                buyerHubAlert = BuyerHubAlert(
                    title: "Payment proof unavailable",
                    message: "Could not read that payment proof PDF right now."
                )
            }
        case .failure:
            buyerHubAlert = BuyerHubAlert(
                title: "Payment proof unavailable",
                message: "Could not import that payment proof PDF right now."
            )
        }
    }

    private func submitBuyerPostSaleFeedback(
        context: PostSaleFeedbackContext,
        rating: Int,
        notes: String
    ) {
        guard let listing = store.listing(id: context.listingID),
              let offer = store.offer(id: context.offerID),
              let seller = store.user(id: offer.sellerID),
              let outcome = store.submitPostSaleFeedback(
                offerID: context.offerID,
                userID: store.currentUserID,
                rating: rating,
                notes: notes
              ) else {
            buyerHubAlert = BuyerHubAlert(
                title: "Feedback unavailable",
                message: "Could not save post-sale feedback right now."
            )
            return
        }

        messaging.sendMessage(
            listing: listing,
            from: store.currentUser,
            to: seller,
            body: outcome.threadMessage,
            isSystem: true
        )

        buyerHubAlert = BuyerHubAlert(
            title: "Feedback saved",
            message: outcome.noticeMessage
        )
    }

    private func openConversation(
        for listing: PropertyListing,
        seller: UserProfile
    ) {
        let buyer = store.currentUser
        let thread = messaging.ensureConversation(listing: listing, buyer: buyer, seller: seller)
        selectedConversationID = thread.id
        selectedTab = .messages
    }

    private func defaultVerificationUploadFileName(for kind: VerificationCheckKind) -> String {
        switch kind {
        case .finance:
            return "finance-proof.pdf"
        case .ownership:
            return "ownership-evidence.pdf"
        case .identity:
            return "identity-check.pdf"
        case .mobile:
            return "mobile-confirmation.pdf"
        case .legal:
            return "legal-readiness.pdf"
        }
    }
}

private struct SellView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService
    @Environment(\.openURL) private var openURL

    @Binding var selectedTab: AppTab
    @Binding var selectedListing: PropertyListing?
    @Binding var selectedConversationID: UUID?
    let reminderTarget: SaleReminderNavigationTarget?
    let onResolveReminderTarget: (SaleReminderNavigationTarget) -> Void

    @State private var isShowingCreateListing = false
    @State private var sellerHubAlert: SellerHubAlert?
    @State private var repricingContext: ListingRepriceContext?
    @State private var negotiationComposer: SellerNegotiationComposerContext?
    @State private var executionLegalSearchContext: LegalSearchContext?
    @State private var executionShareInviteContext: SaleInviteShareContext?
    @State private var archiveShareContext: SaleArchiveShareContext?
    @State private var conciergeBookingContext: PostSaleConciergeBookingContext?
    @State private var conciergeInvoiceUploadContext: PostSaleConciergeInvoiceUploadContext?
    @State private var conciergePaymentUploadContext: PostSaleConciergePaymentUploadContext?
    @State private var conciergeResolutionContext: PostSaleConciergeResolutionContext?
    @State private var postSaleFeedbackContext: PostSaleFeedbackContext?
    @State private var pendingVerificationUploadKind: VerificationCheckKind?
    @State private var preparedDocument: PreparedSaleDocument?
    @State private var selectedAttentionItemIDs: Set<String> = []
    @State private var attentionSeverityFilter: ConciergeAttentionScopeFilter = .all
    @State private var attentionServiceFilter: ConciergeAttentionServiceFilter = .all
    @State private var suggestedReplacementPreviews: [String: ConciergeReplacementSuggestion] = [:]
    @State private var suggestedReplacementPreviewFingerprints: [String: String] = [:]
    @State private var loadingSuggestedReplacementPreviewIDs: Set<String> = []
    @State private var preparingSuggestedReplacementItemID: String?
    @State private var isBatchReplacingAttentionItems = false
    @State private var batchReplacementReviewContext: ConciergeBatchReplacementReviewContext?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Seller Hub",
                        subtitle: "Run a private sale with owner tools, direct offers, and more money staying in your pocket."
                    )

                    if store.currentUser.role != .seller {
                        sellerAccessCard
                    } else {
                        sellerStats
                        ownerInsights
                        pricingControlPanel
                        activeDealLane
                        sellerConciergeAttentionQueue
                        settledDealArchive
                        warmFollowUpQueue
                        negotiationBoard
                        comparisonWorkspace
                        sellerListings
                    }
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Sell Privately")
            .task(id: reminderTarget?.routingKey) {
                handleSellerReminderTarget(reminderTarget)
            }
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
                    try store.createListing(from: draft, sellerID: store.currentUserID)
                }
            }
            .sheet(item: $repricingContext) { context in
                RepriceListingSheet(listing: context.listing) { newPrice, note in
                    let outcome = try store.repriceListing(
                        listingID: context.listing.id,
                        sellerID: store.currentUserID,
                        newPrice: newPrice,
                        note: note
                    )
                    notifyImpactedConversations(for: outcome)
                    sellerHubAlert = SellerHubAlert(
                        title: "Price updated",
                        message: outcome.noticeMessage
                    )
                }
            }
            .sheet(item: $negotiationComposer) { composer in
                OfferSheet(
                    listing: composer.listing,
                    title: composer.offerContext.title,
                    amountLabel: composer.offerContext.amountLabel,
                    conditionsLabel: composer.offerContext.conditionsLabel,
                    submitTitle: composer.offerContext.submitTitle,
                    initialAmount: composer.offerContext.amount,
                    initialConditions: composer.offerContext.conditions
                ) { amount, conditions in
                    handleSellerNegotiationSubmission(
                        listing: composer.listing,
                        offer: composer.offer,
                        action: composer.action,
                        amount: amount,
                        conditions: conditions
                    )
                }
            }
            .sheet(item: $executionLegalSearchContext) { context in
                if let offer = store.offer(id: context.offerID),
                   let listing = store.listing(id: offer.listingID) {
                    LegalSearchSheet(
                        listing: listing,
                        actingRole: context.role,
                        currentSelection: context.role == .buyer
                            ? offer.buyerLegalSelection?.professional
                            : offer.sellerLegalSelection?.professional,
                        onSelect: { professional in
                            handleExecutionLegalSelection(
                                listing: listing,
                                offerID: context.offerID,
                                role: context.role,
                                professional: professional
                            )
                        }
                    )
                    .environmentObject(store)
                } else {
                    EmptyPanel(message: "That deal is no longer available.")
                        .padding()
                }
            }
            .sheet(item: $executionShareInviteContext) { context in
                TrackedShareSheet(
                    title: context.title,
                    items: [context.shareMessage]
                ) { completed in
                    if completed {
                        handleExecutionInviteShare(
                            listingID: context.listingID,
                            offerID: context.offerID,
                            role: context.role
                        )
                    }
                }
            }
            .sheet(item: $archiveShareContext) { context in
                TrackedShareSheet(
                    title: context.title,
                    items: context.fileURLs.map { $0 as Any }
                ) { _ in }
            }
            .sheet(item: $batchReplacementReviewContext) { context in
                ConciergeBatchReplacementReviewSheet(
                    context: context,
                    onConfirm: { reviewedEntries, returnContext in
                        confirmSellerBatchReplacementReview(reviewedEntries, returnContext: returnContext)
                    },
                    onOpenEntry: { entry, returnContext in
                        openSellerBatchReplacementReviewEntry(entry, returnContext: returnContext)
                    },
                    onCloseEntries: { entryIDs, remainingCount in
                        closeSellerBatchReviewEntries(entryIDs, remainingCount: remainingCount)
                    }
                )
                .environmentObject(store)
            }
            .sheet(item: $conciergeBookingContext) { context in
                PostSaleConciergeSheet(
                    listing: context.listing,
                    serviceKind: context.serviceKind,
                    counterpartName: context.counterpartName,
                    focus: context.focus,
                    preferredProviderID: context.preferredProviderID,
                    preferredReplacementStrategy: context.preferredReplacementStrategy,
                    currentBooking: context.currentBooking,
                    manualReviewContext: context.manualReviewContext,
                    onConfirmProvider: { note in
                        confirmSellerConciergeProvider(context: context, note: note)
                    },
                    onLogFollowUp: {
                        logSellerConciergeFollowUp(context: context)
                    },
                    onSnoozeReminder: {
                        snoozeSellerConciergeReminder(context: context)
                    },
                    onLogIssue: {
                        openSellerConciergeResolution(context: context, mode: .logIssue)
                    },
                    onResolveIssue: {
                        openSellerConciergeResolution(context: context, mode: .resolveIssue)
                    }
                ) { provider, scheduledFor, notes, estimatedCost in
                    bookSellerPostSaleConciergeService(
                        context: context,
                        provider: provider,
                        scheduledFor: scheduledFor,
                        notes: notes,
                        estimatedCost: estimatedCost
                    )
                }
                .environmentObject(store)
            }
            .sheet(item: $conciergeResolutionContext) { context in
                PostSaleConciergeResolutionSheet(
                    mode: context.mode,
                    booking: context.booking
                ) { issueKind, note, amount in
                    handleSellerConciergeResolution(
                        context: context,
                        issueKind: issueKind,
                        note: note,
                        amount: amount
                    )
                }
            }
            .sheet(item: $postSaleFeedbackContext) { context in
                PostSaleFeedbackSheet(
                    title: "Post-sale feedback",
                    listingTitle: context.listingTitle,
                    counterpartName: context.counterpartName,
                    existingEntry: context.existingEntry
                ) { rating, notes in
                    submitSellerPostSaleFeedback(
                        context: context,
                        rating: rating,
                        notes: notes
                    )
                }
            }
            .sheet(item: $preparedDocument) { document in
                SaleDocumentPreviewSheet(document: document)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { conciergeInvoiceUploadContext != nil },
                    set: { isPresented in
                        if !isPresented {
                            conciergeInvoiceUploadContext = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedConciergeInvoice(result)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { conciergePaymentUploadContext != nil },
                    set: { isPresented in
                        if !isPresented {
                            conciergePaymentUploadContext = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedConciergePaymentProof(result)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { pendingVerificationUploadKind != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingVerificationUploadKind = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedVerificationDocument(result)
            }
            .alert(item: $sellerHubAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var sellerAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Seller access required")
                .font(.headline)

            Text("Seller Hub is only available when the built-in seller demo profile is active. Switch now to review listing management, repricing, offers, legal handoff, contracts, settlement, and concierge follow-through.")
                .foregroundStyle(.secondary)

            if let seller = preferredSellerDemoProfile {
                Button {
                    store.setCurrentUser(seller.id)
                } label: {
                    PersonaCard(user: seller, isSelected: seller.id == store.currentUserID)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button("Open Account access") {
                    selectedTab = .account
                }
                .buttonStyle(.bordered)

                if let seller = preferredSellerDemoProfile,
                   seller.id != store.currentUserID {
                    Button("Switch to seller demo") {
                        store.setCurrentUser(seller.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandPalette.teal)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private var preferredSellerDemoProfile: UserProfile? {
        if store.currentUser.role == .seller {
            return store.currentUser
        }

        return store.sellers.first
    }

    private var sellerNegotiationEntries: [SellerOfferBoardEntry] {
        store.offers
            .filter { $0.sellerID == store.currentUserID && $0.settlementCompletedAt == nil }
            .compactMap { offer in
                guard let listing = store.listing(id: offer.listingID),
                      let buyer = store.user(id: offer.buyerID) else {
                    return nil
                }

                return SellerOfferBoardEntry(
                    listing: listing,
                    offer: offer,
                    buyer: buyer,
                    priority: sellerOfferPriority(for: offer, listing: listing, buyer: buyer)
                )
            }
            .sorted { left, right in
                if left.priority.score == right.priority.score {
                    return left.offer.createdAt > right.offer.createdAt
                }
                return left.priority.score > right.priority.score
            }
    }

    private var settledDealEntries: [SellerOfferBoardEntry] {
        store.offers
            .filter { $0.sellerID == store.currentUserID && $0.settlementCompletedAt != nil }
            .compactMap { offer in
                guard let listing = store.listing(id: offer.listingID),
                      let buyer = store.user(id: offer.buyerID) else {
                    return nil
                }

                return SellerOfferBoardEntry(
                    listing: listing,
                    offer: offer,
                    buyer: buyer,
                    priority: sellerOfferPriority(for: offer, listing: listing, buyer: buyer)
                )
            }
            .sorted { left, right in
                guard let leftDate = left.offer.settlementCompletedAt,
                      let rightDate = right.offer.settlementCompletedAt else {
                    return left.offer.createdAt > right.offer.createdAt
                }
                return leftDate > rightDate
            }
    }

    private var sellerOfferComparisonGroups: [SellerOfferComparisonGroup] {
        Dictionary(grouping: sellerNegotiationEntries, by: { $0.listing.id })
            .values
            .compactMap { entries in
                guard let first = entries.first else { return nil }
                let sortedEntries = entries.sorted { left, right in
                    let leftRank = sellerRelationshipSortRank(left.offer.sellerRelationshipStatus)
                    let rightRank = sellerRelationshipSortRank(right.offer.sellerRelationshipStatus)
                    if leftRank == rightRank {
                        if left.priority.score == right.priority.score {
                            return left.offer.amount > right.offer.amount
                        }
                        return left.priority.score > right.priority.score
                    }
                    return leftRank > rightRank
                }
                return SellerOfferComparisonGroup(listing: first.listing, entries: sortedEntries)
            }
            .sorted { left, right in
                if left.entries.count == right.entries.count {
                    return left.listing.updatedAt > right.listing.updatedAt
                }
                return left.entries.count > right.entries.count
            }
    }

    private var activeDealEntries: [SellerOfferBoardEntry] {
        sellerOfferComparisonGroups
            .compactMap { group in
                let activeOffer = activeExecutionOffer(for: group.listing.id, offers: group.entries.map(\.offer))
                return activeOffer.flatMap { offer in
                    group.entries.first(where: { $0.offer.id == offer.id })
                }
            }
            .sorted { left, right in
                if left.offer.contractPacket?.isFullySigned == right.offer.contractPacket?.isFullySigned {
                    return left.offer.createdAt > right.offer.createdAt
                }
                return left.offer.contractPacket?.isFullySigned == true
            }
    }

    private var sellerAttentionItems: [SellerConciergeAttentionItem] {
        let includeDueSoon = store.currentUser.conciergeReminderIntensity.showsDueSoonAttention

        return settledDealEntries
            .flatMap { entry in
                conciergeRows(for: entry.offer).compactMap { row in
                    let severity: ConciergeAttentionSeverity?
                    if row.needsFollowUp {
                        severity = .overdue
                    } else if includeDueSoon && row.isResponseDueSoon {
                        severity = .dueSoon
                    } else {
                        severity = nil
                    }

                    guard let severity else {
                        return nil
                    }

                    return SellerConciergeAttentionItem(
                        entry: entry,
                        row: row,
                        severity: severity
                    )
                }
            }
            .sorted { left, right in
                if left.severity.sortRank == right.severity.sortRank {
                    if left.entry.listing.title == right.entry.listing.title {
                        return left.row.title < right.row.title
                    }
                    return left.entry.listing.title < right.entry.listing.title
                }
                return left.severity.sortRank < right.severity.sortRank
            }
    }

    private var filteredSellerAttentionItems: [SellerConciergeAttentionItem] {
        sellerAttentionItems.filter {
            attentionSeverityFilter.matches($0.severity) &&
            attentionServiceFilter.matches($0.row.kind)
        }
    }

    private var warmFollowUpEntries: [SellerOfferBoardEntry] {
        let activeOfferIDs = Set(activeDealEntries.map(\.id))

        return sellerOfferComparisonGroups
            .filter { group in
                activeExecutionOffer(for: group.listing.id, offers: group.entries.map(\.offer)) != nil
            }
            .flatMap { group in
                group.entries.filter { !activeOfferIDs.contains($0.id) }
            }
            .sorted { left, right in
                let leftRank = sellerRelationshipSortRank(left.offer.sellerRelationshipStatus)
                let rightRank = sellerRelationshipSortRank(right.offer.sellerRelationshipStatus)
                if leftRank == rightRank {
                    return left.priority.score > right.priority.score
                }
                return leftRank > rightRank
            }
    }

    private var sellerStats: some View {
        let stats = store.sellerDashboardStats
        let reminderDashboard = store.currentUserConciergeReminderDashboard

        return AdaptiveTagGrid(minimum: 150) {
            StatPanel(title: "Active", value: "\(stats.activeListings)", subtitle: "Private listings live")
            StatPanel(title: "Drafts", value: "\(stats.draftListings)", subtitle: "Listings in progress")
            StatPanel(title: "Offers", value: "\(stats.totalOffers)", subtitle: "Offer records received")
            StatPanel(title: "Demand", value: "\(stats.averageDemandScore)", subtitle: "Average buyer demand score")
            StatPanel(
                title: "Urgent",
                value: "\(reminderDashboard.overdueCount)",
                subtitle: reminderDashboard.overdueCount == 0
                    ? "No overdue provider follow-ups"
                    : "Settled-deal concierge follow-ups need action"
            )
            if store.currentUser.conciergeReminderIntensity.showsDueSoonAttention {
                StatPanel(
                    title: "Due soon",
                    value: "\(reminderDashboard.dueSoonCount)",
                    subtitle: "Upcoming provider reply windows"
                )
            }
        }
    }

    private var ownerInsights: some View {
        let ownedListings = store.sellerListings(for: store.currentUserID)
        let demandAverage = ownedListings.isEmpty ? 0 : ownedListings.map(\.marketPulse.buyerDemandScore).reduce(0, +) / ownedListings.count
        let totalIndicativeSavings = ownedListings
            .map { privateSaleEconomics(for: $0.askingPrice).estimatedTraditionalCost }
            .reduce(0, +)
        let totalIndicativeNet = ownedListings
            .map { privateSaleEconomics(for: $0.askingPrice).estimatedSellerNet }
            .reduce(0, +)
        let liveDealRoomCount = store.offers.filter { $0.sellerID == store.currentUserID }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Owner market snapshot")
                .font(.headline)

            AdaptiveTagGrid(minimum: 150) {
                StatPanel(
                    title: "Cost avoided",
                    value: currencyString(totalIndicativeSavings),
                    subtitle: "Indicative traditional sale cost across current asks"
                )
                StatPanel(
                    title: "Seller net",
                    value: currencyString(totalIndicativeNet),
                    subtitle: "Indicative owner-first net at current asking prices"
                )
                StatPanel(
                    title: "Deal rooms",
                    value: "\(liveDealRoomCount)",
                    subtitle: "Offers already inside the shared workspace"
                )
                StatPanel(
                    title: "Demand",
                    value: "\(demandAverage)",
                    subtitle: "Average buyer demand score"
                )
            }

            HighlightInformationCard(
                title: "Why this stands out",
                message: "Real O Who is not just another listing surface. It combines private-sale savings visibility, verified participants, direct messaging, and a live transaction room that keeps buyer, seller, and legal handoff together.",
                supporting: "Current portfolio demand score average: \(demandAverage)."
            )
        }
    }

    private var activeDealLane: some View {
        let entries = activeDealEntries
        let signaturePendingCount = entries.filter { $0.offer.contractPacket?.isFullySigned != true }.count
        let nextStepCount = entries.compactMap { nextChecklistItem(for: $0.offer) }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Active deal lane")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Once you accept an offer, the live deal will appear here with the next milestone and direct shortcuts into the listing and secure thread.")
            } else {
                AdaptiveTagGrid(minimum: 150) {
                    MiniStatPanel(
                        title: "Live deals",
                        value: "\(entries.count)",
                        subtitle: "Listings currently moving through legal handoff or signing"
                    )
                    MiniStatPanel(
                        title: "Signatures open",
                        value: "\(signaturePendingCount)",
                        subtitle: "Accepted deals still waiting on final sign-off"
                    )
                    MiniStatPanel(
                        title: "Next steps",
                        value: "\(nextStepCount)",
                        subtitle: "Deals with a clear next milestone ready to action"
                    )
                }

                ForEach(entries) { entry in
                    let executionAction = executionPrimaryAction(for: entry)
                    ActiveDealExecutionCard(
                        entry: entry,
                        nextItem: nextChecklistItem(for: entry.offer),
                        nextSnapshot: nextChecklistItem(for: entry.offer).flatMap { entry.offer.liveTaskSnapshot(for: $0.id) },
                        blockingSummary: executionBlockingSummary(for: entry),
                        keyDocuments: keyExecutionDocuments(for: entry.offer),
                        primaryActionTitle: executionAction?.title,
                        primaryActionSupporting: executionAction?.supporting,
                        onPrimaryAction: executionAction.map { action in
                            {
                                performExecutionAction(action, for: entry)
                            }
                        },
                        onOpenDocument: { document in
                            openExecutionDocument(document, for: entry)
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, buyer: entry.buyer)
                        }
                    )
                }
            }
        }
    }

    private var sellerConciergeAttentionQueue: some View {
        let items = filteredSellerAttentionItems
        let selectedItems = items.filter { selectedAttentionItemIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Concierge attention queue")
                .font(.headline)

            if sellerAttentionItems.isEmpty {
                EmptyPanel(message: "No concierge provider follow-ups need attention right now. Urgent and due-soon provider replies will surface here once a settled sale needs action.")
            } else if items.isEmpty {
                ConciergeAttentionFilterPanel(
                    severityFilter: $attentionSeverityFilter,
                    serviceFilter: $attentionServiceFilter,
                    visibleCount: items.count,
                    totalCount: sellerAttentionItems.count,
                    selectedVisibleCount: selectedItems.count,
                    selectedTotalCount: selectedAttentionItemIDs.count,
                    onSelectVisible: {
                        selectedAttentionItemIDs.formUnion(items.map(\.id))
                    },
                    onClearSelection: {
                        selectedAttentionItemIDs.removeAll()
                    }
                )

                EmptyPanel(message: "No concierge reminders match the current filter. Change the scope or service filter to bring the rest of the queue back.")
            } else {
                HighlightInformationCard(
                    title: "Clear settled-sale bottlenecks from one place",
                    message: "This queue pulls overdue and due-soon concierge provider reply windows into one seller workspace so you can keep handover moving without opening each archive card first.",
                    supporting: "Select one or more provider rows below to run batch follow-up, snooze, or confirmation actions."
                )

                ConciergeAttentionFilterPanel(
                    severityFilter: $attentionSeverityFilter,
                    serviceFilter: $attentionServiceFilter,
                    visibleCount: items.count,
                    totalCount: sellerAttentionItems.count,
                    selectedVisibleCount: selectedItems.count,
                    selectedTotalCount: selectedAttentionItemIDs.count,
                    onSelectVisible: {
                        selectedAttentionItemIDs.formUnion(items.map(\.id))
                    },
                    onClearSelection: {
                        selectedAttentionItemIDs.removeAll()
                    }
                )

                AdaptiveTagGrid(minimum: 150) {
                    MiniStatPanel(
                        title: "Attention now",
                        value: "\(items.count)",
                        subtitle: "\(items.filter { $0.severity == .overdue }.count) urgent"
                    )
                    MiniStatPanel(
                        title: "Selected",
                        value: "\(selectedItems.count)",
                        subtitle: selectedItems.isEmpty ? "Choose provider rows below" : "Ready for batch actions"
                    )
                    if store.currentUser.conciergeReminderIntensity.showsDueSoonAttention {
                        MiniStatPanel(
                            title: "Due soon",
                            value: "\(items.filter { $0.severity == .dueSoon }.count)",
                            subtitle: "Upcoming provider reply windows"
                        )
                    }
                }

                HighlightInformationCard(
                    title: "Backup mode: \(store.currentUser.conciergeReplacementStrategy.title)",
                    message: "Any queue-generated provider replacement suggestions in Seller Hub are being ranked with this strategy right now.",
                    supporting: store.currentUser.conciergeReplacementStrategy.detail
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        sellerAttentionBatchActionButtons(
                            selectedItems: selectedItems
                        )
                    }

                    VStack(alignment: .trailing, spacing: 10) {
                        sellerAttentionBatchActionButtons(
                            selectedItems: selectedItems
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                ForEach(PostSaleConciergeServiceKind.allCases, id: \.self) { serviceKind in
                    let groupItems = items.filter { $0.row.kind == serviceKind }

                    if !groupItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ConciergeAttentionSectionHeader(
                                serviceKind: serviceKind,
                                itemCount: groupItems.count,
                                urgentCount: groupItems.filter { $0.severity == .overdue }.count
                            )

                            ForEach(groupItems) { item in
                                let booking = item.entry.offer.conciergeBooking(for: item.row.kind)
                                let provider = booking?.provider
                                let previewTaskID = booking.map {
                                    "\(item.id)-\(conciergeReplacementPreviewFingerprint(for: $0, strategy: store.currentUser.conciergeReplacementStrategy))"
                                } ?? item.id
                                ConciergeAttentionQueueCard(
                                    title: item.row.title,
                                    listingTitle: item.entry.listing.title,
                                    listingSubtitle: item.entry.listing.address.fullLine,
                                    counterpartLabel: "Buyer",
                                    counterpartName: item.entry.buyer.name,
                                    recommendation: booking.map(conciergeAttentionRecommendation(for:)),
                                    statusText: item.row.statusText,
                                    detail: item.row.detail,
                                    activityLines: conciergeAttentionActivityLines(
                                        for: item.entry.offer,
                                        serviceKind: item.row.kind
                                    ),
                                    symbolName: item.row.kind.symbolName,
                                    severity: item.severity,
                                    isSelected: selectedAttentionItemIDs.contains(item.id),
                                    canLogFollowUp: item.row.canLogFollowUp,
                                    canSnooze: item.row.canSnoozeReminder,
                                    canConfirm: item.row.canConfirmProvider,
                                    canLogIssue: item.row.canLogIssue,
                                    currentProvider: provider,
                                    providerCallURL: provider.flatMap(conciergeProviderCallURL),
                                    providerWebsiteURL: provider?.websiteURL,
                                    providerMapsURL: provider?.mapsURL,
                                    suggestedReplacement: suggestedReplacementPreviews[item.id],
                                    isLoadingSuggestedReplacement: loadingSuggestedReplacementPreviewIDs.contains(item.id),
                                    isPreparingSuggestedReplacement: preparingSuggestedReplacementItemID == item.id,
                                    onToggleSelection: {
                                        toggleSellerAttentionSelection(item)
                                    },
                                    onPrimaryAction: {
                                        handleSellerConciergePrimaryAction(
                                            item.row.kind,
                                            booking: booking,
                                            for: item.entry
                                        )
                                    },
                                    onUseSuggestedReplacement: booking.map { resolvedBooking in
                                        {
                                            prepareSellerSuggestedReplacement(
                                                item.row.kind,
                                                booking: resolvedBooking,
                                                itemID: item.id,
                                                cachedSuggestion: suggestedReplacementPreviews[item.id],
                                                for: item.entry
                                            )
                                        }
                                    },
                                    onOpenBooking: {
                                        openSellerConciergeBooking(item.row.kind, for: item.entry)
                                    },
                                    onLogFollowUp: {
                                        logSellerConciergeFollowUp(item.row.kind, for: item.entry)
                                    },
                                    onSnooze: {
                                        snoozeSellerConciergeReminder(item.row.kind, for: item.entry)
                                    },
                                    onConfirm: {
                                        confirmSellerConciergeProvider(item.row.kind, note: "", for: item.entry)
                                    },
                                    onLogIssue: {
                                        logSellerConciergeIssue(item.row.kind, for: item.entry)
                                    },
                                    onOpenThread: {
                                        openConversation(for: item.entry.listing, buyer: item.entry.buyer)
                                    },
                                    onOpenListing: {
                                        selectedListing = item.entry.listing
                                    }
                                )
                                .task(id: previewTaskID) {
                                    guard let booking else { return }
                                    await prefetchSellerSuggestedReplacementPreview(
                                        itemID: item.id,
                                        serviceKind: item.row.kind,
                                        booking: booking,
                                        entry: item.entry
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var warmFollowUpQueue: some View {
        let entries = warmFollowUpEntries

        return VStack(alignment: .leading, spacing: 12) {
            Text("Warm follow-up")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Backup buyers will appear here when one of your listings already has an accepted deal underway.")
            } else {
                HighlightInformationCard(
                    title: "Keep backup buyers warm",
                    message: "These buyers sit behind an active accepted deal on the same listing. You can keep them shortlisted, adjust their seller status, or continue the secure conversation without disrupting execution.",
                    supporting: "Accept is paused while another buyer is already active on that property."
                )

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    SellerOfferComparisonCard(
                        rank: index + 1,
                        entry: entry,
                        canAccept: canAcceptOffer(entry.offer),
                        onSetRelationshipStatus: { status in
                            updateSellerRelationshipStatus(status, for: entry)
                        },
                        onAccept: {
                            handleSellerNegotiationSubmission(
                                listing: entry.listing,
                                offer: entry.offer,
                                action: .accept,
                                amount: entry.offer.amount,
                                conditions: entry.offer.conditions
                            )
                        },
                        onCounter: {
                            negotiationComposer = SellerNegotiationComposerContext(
                                listing: entry.listing,
                                offer: entry.offer,
                                action: .counter
                            )
                        },
                        onRequestChanges: {
                            negotiationComposer = SellerNegotiationComposerContext(
                                listing: entry.listing,
                                offer: entry.offer,
                                action: .requestChanges
                            )
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, buyer: entry.buyer)
                        }
                    )
                }
            }
        }
    }

    private var settledDealArchive: some View {
        let entries = settledDealEntries
        let reminderDashboard = store.currentUserConciergeReminderDashboard

        return VStack(alignment: .leading, spacing: 12) {
            Text("Settled archive")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Completed private sales will move here once settlement is confirmed, along with a closeout pack and handover checklist.")
            } else {
                HighlightInformationCard(
                    title: "Completed sale records",
                    message: "Each settled sale now keeps the signed contract, settlement paperwork, summary record, and handover checklist in one owner archive.",
                    supporting: "Export the closeout pack from any card when you need to share it with your records, buyer, or legal team."
                )

                if reminderDashboard.hasEscalatedAttention {
                    ConciergeReminderEscalationCard(
                        title: "Seller concierge attention",
                        dashboard: reminderDashboard
                    )
                }

                ForEach(entries) { entry in
                    DealArchiveCard(
                        title: entry.listing.title,
                        subtitle: entry.listing.address.fullLine,
                        counterpartLabel: "Buyer",
                        counterpartName: entry.buyer.name,
                        settlementDate: entry.offer.settlementCompletedAt,
                        amount: entry.offer.amount,
                        documents: archiveDocuments(for: entry.offer),
                        serviceRows: postSaleServiceRows(for: entry.offer),
                        conciergeRows: conciergeRows(for: entry.offer),
                        feedbackRows: postSaleFeedbackRows(for: entry.offer, currentRole: .seller),
                        feedbackActionTitle: entry.offer.sellerFeedback == nil ? "Leave feedback" : "Update feedback",
                        onCompleteServiceTask: { task in
                            completeSellerPostSaleTask(task, for: entry)
                        },
                        onManageConciergeService: { serviceKind in
                            openSellerConciergeBooking(serviceKind, for: entry)
                        },
                        onOpenConciergeQuote: { serviceKind in
                            openSellerConciergeQuote(serviceKind, for: entry)
                        },
                        onApproveConciergeQuote: { serviceKind in
                            approveSellerConciergeQuote(serviceKind, for: entry)
                        },
                        onUploadConciergeInvoice: { serviceKind in
                            uploadSellerConciergeInvoice(serviceKind, for: entry)
                        },
                        onOpenConciergeInvoice: { serviceKind in
                            openSellerConciergeInvoice(serviceKind, for: entry)
                        },
                        onUploadConciergePaymentProof: { serviceKind in
                            uploadSellerConciergePaymentProof(serviceKind, for: entry)
                        },
                        onOpenConciergePaymentProof: { serviceKind in
                            openSellerConciergePaymentProof(serviceKind, for: entry)
                        },
                        onCancelConciergeService: { serviceKind in
                            cancelSellerConciergeService(serviceKind, for: entry)
                        },
                        onRecordConciergeRefund: { serviceKind in
                            recordSellerConciergeRefund(serviceKind, for: entry)
                        },
                        onLogConciergeIssue: { serviceKind in
                            logSellerConciergeIssue(serviceKind, for: entry)
                        },
                        onResolveConciergeIssue: { serviceKind in
                            resolveSellerConciergeIssue(serviceKind, for: entry)
                        },
                        onLogConciergeFollowUp: { serviceKind in
                            logSellerConciergeFollowUp(serviceKind, for: entry)
                        },
                        onSnoozeConciergeReminder: { serviceKind in
                            snoozeSellerConciergeReminder(serviceKind, for: entry)
                        },
                        onConfirmConciergeProvider: { serviceKind in
                            confirmSellerConciergeProvider(serviceKind, note: "", for: entry)
                        },
                        onExportConciergeReceipt: { serviceKind in
                            exportSellerConciergeReceipt(serviceKind, for: entry)
                        },
                        onOpenConciergeConfirmation: { serviceKind in
                            openSellerConciergeConfirmation(serviceKind, for: entry)
                        },
                        onCompleteConciergeService: { serviceKind in
                            completeSellerConciergeService(serviceKind, for: entry)
                        },
                        onLeaveFeedback: {
                            postSaleFeedbackContext = PostSaleFeedbackContext(
                                offerID: entry.offer.id,
                                listingID: entry.listing.id,
                                listingTitle: entry.listing.title,
                                counterpartName: entry.buyer.name,
                                currentRole: .seller,
                                existingEntry: entry.offer.sellerFeedback
                            )
                        },
                        onOpenDocument: { document in
                            openExecutionDocument(document, for: entry)
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, buyer: entry.buyer)
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        },
                        onShareArchive: {
                            prepareSellerArchiveShare(for: entry)
                        }
                    )
                }
            }
        }
    }

    private func toggleSellerAttentionSelection(_ item: SellerConciergeAttentionItem) {
        if selectedAttentionItemIDs.contains(item.id) {
            selectedAttentionItemIDs.remove(item.id)
        } else {
            selectedAttentionItemIDs.insert(item.id)
        }
    }

    @ViewBuilder
    private func sellerAttentionBatchActionButtons(
        selectedItems: [SellerConciergeAttentionItem]
    ) -> some View {
        Button(isBatchReplacingAttentionItems ? "Switching..." : "Review backups") {
            replaceSelectedSellerAttentionItems(selectedItems)
        }
        .buttonStyle(.borderedProminent)
        .tint(BrandPalette.teal)
        .disabled(selectedItems.isEmpty || isBatchReplacingAttentionItems)

        Button("Log selected") {
            logSelectedSellerAttentionItems(selectedItems)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.contains(where: \.row.canLogFollowUp) == false || isBatchReplacingAttentionItems)

        Button("Snooze 24h") {
            snoozeSelectedSellerAttentionItems(selectedItems)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.contains(where: \.row.canSnoozeReminder) == false || isBatchReplacingAttentionItems)

        Button("Confirm selected") {
            confirmSelectedSellerAttentionItems(selectedItems)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.contains(where: \.row.canConfirmProvider) == false || isBatchReplacingAttentionItems)
    }

    private func replaceSelectedSellerAttentionItems(_ items: [SellerConciergeAttentionItem]) {
        guard !items.isEmpty else {
            sellerHubAlert = SellerHubAlert(
                title: "Nothing selected",
                message: "Select one or more provider rows first to review ranked backup changes."
            )
            return
        }

        batchReplacementReviewContext = makeSellerBatchReplacementReviewContext(items)
    }

    private func makeSellerBatchReplacementReviewContext(
        _ items: [SellerConciergeAttentionItem],
        refreshSummary: ConciergeBatchReviewRefreshSummary? = nil,
        approvalRefreshSummary: ConciergeBatchReviewApprovalRefreshSummary? = nil,
        initialStagedEntryIDs: [String] = [],
        initialApprovedStagedEntryFingerprints: [String: String] = [:],
        initialRefreshHighlightedStagedEntryIDs: [String] = [],
        initialVisitedRefreshBookingEntryIDs: [String] = [],
        initialHasHiddenCompletedBookingLane: Bool = false,
        initialHasActiveBookingLaneReactivation: Bool = false,
        initialHasDismissedBookingLaneReactivationCompletion: Bool = false,
        initialReactivatedRefreshBookingEntryIDs: [String] = [],
        initialReactivationCompletionReviewLastItemID: String? = nil,
        initialReviewedReactivationCompletionItemIDs: [String] = [],
        entriesOverride: [ConciergeBatchReplacementReviewEntry]? = nil
    ) -> ConciergeBatchReplacementReviewContext {
        ConciergeBatchReplacementReviewContext(
            title: "Review ranked backups",
            hubTitle: "Seller Hub",
            strategy: store.currentUser.conciergeReplacementStrategy,
            entries: entriesOverride ?? items.map(makeSellerBatchReplacementReviewEntry),
            initialStagedEntryIDs: initialStagedEntryIDs,
            initialApprovedStagedEntryFingerprints: initialApprovedStagedEntryFingerprints,
            initialRefreshHighlightedStagedEntryIDs: initialRefreshHighlightedStagedEntryIDs,
            initialVisitedRefreshBookingEntryIDs: initialVisitedRefreshBookingEntryIDs,
            initialHasHiddenCompletedBookingLane: initialHasHiddenCompletedBookingLane,
            initialHasActiveBookingLaneReactivation: initialHasActiveBookingLaneReactivation,
            initialHasDismissedBookingLaneReactivationCompletion: initialHasDismissedBookingLaneReactivationCompletion,
            initialReactivatedRefreshBookingEntryIDs: initialReactivatedRefreshBookingEntryIDs,
            initialReactivationCompletionReviewLastItemID: initialReactivationCompletionReviewLastItemID,
            initialReviewedReactivationCompletionItemIDs: initialReviewedReactivationCompletionItemIDs,
            refreshSummary: refreshSummary,
            approvalRefreshSummary: approvalRefreshSummary
        )
    }

    private func makeSellerBatchReplacementReviewEntry(
        _ item: SellerConciergeAttentionItem
    ) -> ConciergeBatchReplacementReviewEntry {
        let booking = item.entry.offer.conciergeBooking(for: item.row.kind)
        let fingerprint = booking.map {
            conciergeReplacementPreviewFingerprint(
                for: $0,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
        }
        let cachedSuggestion: ConciergeReplacementSuggestion?
        if let booking,
           conciergeAttentionPrimaryAction(for: booking) == .switchProvider,
           let fingerprint,
           suggestedReplacementPreviewFingerprints[item.id] == fingerprint {
            cachedSuggestion = suggestedReplacementPreviews[item.id]
        } else {
            cachedSuggestion = nil
        }

        let manualReviewReason: String?
        let isLoadingSuggestion: Bool
        if let booking {
            if conciergeAttentionPrimaryAction(for: booking) != .switchProvider {
                manualReviewReason = "This provider thread is not currently in switch-provider mode, so it still needs manual review from the booking."
                isLoadingSuggestion = false
            } else if cachedSuggestion != nil {
                manualReviewReason = nil
                isLoadingSuggestion = false
            } else {
                manualReviewReason = nil
                isLoadingSuggestion = true
            }
        } else {
            manualReviewReason = "This concierge booking is no longer available in the settled archive."
            isLoadingSuggestion = false
        }

        return ConciergeBatchReplacementReviewEntry(
            id: item.id,
            offerID: item.entry.offer.id,
            listing: item.entry.listing,
            serviceKind: item.row.kind,
            counterpartLabel: "Buyer",
            counterpartName: item.entry.buyer.name,
            currentBooking: booking,
            reviewFingerprint: fingerprint,
            suggestedReplacement: cachedSuggestion,
            isLoadingSuggestion: isLoadingSuggestion,
            manualReviewReason: manualReviewReason
        )
    }

    private func confirmSellerBatchReplacementReview(
        _ entries: [ConciergeBatchReplacementReviewEntry],
        returnContext: ConciergeBatchReviewReturnContext
    ) {
        let actionableEntries = entries.filter(\.canApplySuggestedReplacement)
        guard !actionableEntries.isEmpty else {
            sellerHubAlert = SellerHubAlert(
                title: "No backups ready",
                message: "No selected provider rows finished with a ranked backup yet, so these bookings still need manual review."
            )
            return
        }

        batchReplacementReviewContext = nil
        isBatchReplacingAttentionItems = true

        Task {
            await performSellerBatchReplacement(actionableEntries, returnContext: returnContext)
        }
    }

    private func openSellerBatchReplacementReviewEntry(
        _ entry: ConciergeBatchReplacementReviewEntry,
        returnContext: ConciergeBatchReviewReturnContext
    ) {
        guard let offer = store.offer(id: entry.offerID),
              let listing = store.listing(id: offer.listingID),
              let buyer = store.user(id: offer.buyerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Booking unavailable",
                message: "That concierge booking is no longer available for manual review."
            )
            return
        }

        let currentBooking = offer.conciergeBooking(for: entry.serviceKind)
        let focus: PostSaleConciergeBookingFocus
        if let currentBooking,
           conciergeAttentionPrimaryAction(for: currentBooking) == .switchProvider {
            focus = .replacement
        } else {
            focus = .standard
        }

        let preferredProviderID = focus == .replacement ? entry.suggestedReplacement?.provider.id : nil
        let manualReviewContext = conciergeManualReviewContext(
            hubTitle: "Seller Hub",
            entry: entry,
            focus: focus
        )
        batchReplacementReviewContext = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            conciergeBookingContext = PostSaleConciergeBookingContext(
                offerID: offer.id,
                listing: listing,
                serviceKind: entry.serviceKind,
                counterpartName: buyer.name,
                focus: focus,
                preferredProviderID: preferredProviderID,
                preferredReplacementStrategy: store.currentUser.conciergeReplacementStrategy,
                currentBooking: currentBooking,
                manualReviewContext: manualReviewContext,
                batchReviewReturnContext: returnContext
            )
        }
    }

    private func reopenSellerBatchReview(
        _ returnContext: ConciergeBatchReviewReturnContext,
        successTitle: String,
        successMessage: String
    ) {
        let refreshedItems = sellerAttentionItems.filter { returnContext.itemIDs.contains($0.id) }
        let survivingIDs = Set(refreshedItems.map(\.id))
        selectedAttentionItemIDs = survivingIDs

        guard refreshedItems.isEmpty == false else {
            batchReplacementReviewContext = nil
            let clearedCount = returnContext.itemIDs.count
            sellerHubAlert = SellerHubAlert(
                title: "\(successTitle) • Review complete",
                message: "\(successMessage) \(clearedCount) selected review row\(clearedCount == 1 ? "" : "s") cleared from \(returnContext.hubTitle)."
            )
            return
        }

        let refreshedEntries = refreshedItems.map(makeSellerBatchReplacementReviewEntry)
        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: returnContext.previousSnapshots.map { ($0.id, $0) }
        )
        let refreshedEntriesWithChangeHighlights = refreshedEntries.map { entry in
            var updatedEntry = entry
            if let previousSnapshot = previousSnapshotsByID[entry.id] {
                updatedEntry.rowChangeSummary = conciergeBatchReviewRowChangeSummary(
                    previousSnapshot: previousSnapshot,
                    refreshedEntry: entry
                )
            }
            return updatedEntry
        }
        let approvalRefreshState = conciergeBatchReviewStagedRefreshState(
            previousStagedEntryIDs: returnContext.stagedEntryIDs,
            previousApprovalFingerprints: returnContext.stagedApprovalFingerprints,
            previousRefreshHighlightedEntryIDs: returnContext.refreshHighlightedStagedEntryIDs,
            refreshedEntries: refreshedEntriesWithChangeHighlights
        )
        let refreshSummary = conciergeBatchReviewRefreshSummary(
            hubTitle: returnContext.hubTitle,
            actionTitle: successTitle,
            actionMessage: successMessage,
            previousSelectionCount: returnContext.itemIDs.count,
            refreshedEntries: refreshedEntriesWithChangeHighlights,
            itemTitlesByID: returnContext.itemTitlesByID,
            itemReferencesByID: returnContext.itemReferencesByID,
            currentStagedEntryIDs: approvalRefreshState.stagedEntryIDs,
            reviewedRefreshHighlightCount: returnContext.reviewedRefreshHighlightEntryIDs.count,
            appliedRefreshHighlightCount: returnContext.appliedRefreshHighlightEntryIDs.count,
            reviewedRefreshHighlightIDs: returnContext.reviewedRefreshHighlightEntryIDs,
            appliedRefreshHighlightIDs: returnContext.appliedRefreshHighlightEntryIDs
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            batchReplacementReviewContext = makeSellerBatchReplacementReviewContext(
                refreshedItems,
                refreshSummary: refreshSummary,
                approvalRefreshSummary: approvalRefreshState.summary,
                initialStagedEntryIDs: approvalRefreshState.stagedEntryIDs,
                initialApprovedStagedEntryFingerprints: approvalRefreshState.approvalFingerprints,
                initialRefreshHighlightedStagedEntryIDs: approvalRefreshState.refreshHighlightedEntryIDs,
                initialVisitedRefreshBookingEntryIDs: returnContext.visitedRefreshBookingEntryIDs,
                initialHasHiddenCompletedBookingLane: returnContext.hasHiddenCompletedBookingLane,
                initialHasActiveBookingLaneReactivation: returnContext.hasActiveBookingLaneReactivation,
                initialHasDismissedBookingLaneReactivationCompletion: returnContext.hasDismissedBookingLaneReactivationCompletion,
                initialReactivatedRefreshBookingEntryIDs: returnContext.reactivatedRefreshBookingEntryIDs,
                initialReactivationCompletionReviewLastItemID: returnContext.reactivationCompletionReviewLastItemID,
                initialReviewedReactivationCompletionItemIDs: returnContext.reviewedReactivationCompletionItemIDs,
                entriesOverride: refreshedEntriesWithChangeHighlights
            )
        }
    }

    private func closeSellerBatchReviewEntries(
        _ entryIDs: [String],
        remainingCount: Int
    ) {
        let idSet = Set(entryIDs)
        selectedAttentionItemIDs.subtract(idSet)

        guard remainingCount == 0 else {
            return
        }

        batchReplacementReviewContext = nil
        let closedCount = entryIDs.count
        sellerHubAlert = SellerHubAlert(
            title: "Review complete",
            message: "Closed \(closedCount) safe review row\(closedCount == 1 ? "" : "s"). Seller Hub only has unresolved concierge items selected now."
        )
    }

    @MainActor
    private func performSellerBatchReplacement(
        _ entries: [ConciergeBatchReplacementReviewEntry],
        returnContext: ConciergeBatchReviewReturnContext? = nil
    ) async {
        defer { isBatchReplacingAttentionItems = false }

        var successCount = 0
        var unavailableCount = 0
        var succeededIDs: [String] = []

        for entry in entries {
            guard let reviewedSuggestion = entry.suggestedReplacement,
                  let offer = store.offer(id: entry.offerID),
                  let booking = offer.conciergeBooking(for: entry.serviceKind),
                  conciergeAttentionPrimaryAction(for: booking) == .switchProvider else {
                unavailableCount += 1
                continue
            }

            let currentFingerprint = conciergeReplacementPreviewFingerprint(
                for: booking,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
            guard entry.reviewFingerprint == currentFingerprint,
                  let buyer = store.user(id: offer.buyerID),
                  let outcome = store.bookPostSaleConciergeService(
                    offerID: offer.id,
                    userID: store.currentUserID,
                    serviceKind: entry.serviceKind,
                    provider: reviewedSuggestion.provider,
                    scheduledFor: booking.scheduledFor,
                    notes: booking.notes,
                    estimatedCost: booking.estimatedCost
                  ) else {
                unavailableCount += 1
                continue
            }

            messaging.sendMessage(
                listing: entry.listing,
                from: store.currentUser,
                to: buyer,
                body: outcome.threadMessage,
                isSystem: true
            )

            successCount += 1
            succeededIDs.append(entry.id)
            suggestedReplacementPreviews.removeValue(forKey: entry.id)
            suggestedReplacementPreviewFingerprints.removeValue(forKey: entry.id)
        }

        let manualReviewCount = entries.count - successCount - unavailableCount
        selectedAttentionItemIDs.subtract(succeededIDs)

        var messageParts: [String] = []
        if successCount > 0 {
            messageParts.append(
                "Switched \(successCount) concierge booking\(successCount == 1 ? "" : "s") to the best ranked backup from the attention queue."
            )
        }
        if manualReviewCount > 0 {
            messageParts.append(
                "\(manualReviewCount) booking\(manualReviewCount == 1 ? "" : "s") still need manual review because no ranked backup was available when the review sheet finished."
            )
        }
        if unavailableCount > 0 {
            messageParts.append(
                "\(unavailableCount) booking\(unavailableCount == 1 ? "" : "s") changed after review and were skipped so the switch stayed safe."
            )
        }

        let alertTitle = successCount == 0 ? "Replacement unavailable" : "Batch replacement complete"
        let alertMessage = messageParts.isEmpty
            ? "Those provider rows are no longer ready to switch."
            : messageParts.joined(separator: " ")

        if successCount > 0, let returnContext {
            reopenSellerBatchReview(
                returnContext,
                successTitle: alertTitle,
                successMessage: alertMessage
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: alertTitle,
                message: alertMessage
            )
        }
    }

    private func logSelectedSellerAttentionItems(_ items: [SellerConciergeAttentionItem]) {
        let actionableItems = items.filter { $0.row.canLogFollowUp }
        guard !actionableItems.isEmpty else {
            sellerHubAlert = SellerHubAlert(
                title: "Nothing to log",
                message: "Select at least one provider row that is ready for follow-up."
            )
            return
        }

        var successCount = 0
        for item in actionableItems {
            guard let outcome = store.logPostSaleConciergeFollowUp(
                offerID: item.entry.offer.id,
                userID: store.currentUserID,
                serviceKind: item.row.kind,
                note: ""
            ) else {
                continue
            }

            messaging.sendMessage(
                listing: item.entry.listing,
                from: store.currentUser,
                to: item.entry.buyer,
                body: outcome.threadMessage,
                isSystem: true
            )
            successCount += 1
        }

        selectedAttentionItemIDs.subtract(actionableItems.map(\.id))
        sellerHubAlert = SellerHubAlert(
            title: successCount == 0 ? "Follow-up unavailable" : "Batch follow-up logged",
            message: successCount == 0
                ? "Those provider rows are no longer ready for follow-up."
                : "Logged provider follow-up for \(successCount) concierge booking\(successCount == 1 ? "" : "s") from the attention queue."
        )
    }

    private func snoozeSelectedSellerAttentionItems(_ items: [SellerConciergeAttentionItem]) {
        let actionableItems = items.filter { $0.row.canSnoozeReminder }
        guard !actionableItems.isEmpty else {
            sellerHubAlert = SellerHubAlert(
                title: "Nothing to snooze",
                message: "Select at least one provider row that can be snoozed for later."
            )
            return
        }

        var successCount = 0
        let snoozeUntil = Date().addingTimeInterval(60 * 60 * 24)
        for item in actionableItems {
            guard let outcome = store.snoozePostSaleConciergeFollowUp(
                offerID: item.entry.offer.id,
                userID: store.currentUserID,
                serviceKind: item.row.kind,
                until: snoozeUntil
            ) else {
                continue
            }

            messaging.sendMessage(
                listing: item.entry.listing,
                from: store.currentUser,
                to: item.entry.buyer,
                body: outcome.threadMessage,
                isSystem: true
            )
            successCount += 1
        }

        selectedAttentionItemIDs.subtract(actionableItems.map(\.id))
        sellerHubAlert = SellerHubAlert(
            title: successCount == 0 ? "Snooze unavailable" : "Batch snooze complete",
            message: successCount == 0
                ? "Those provider rows can no longer be snoozed."
                : "Snoozed \(successCount) concierge reminder\(successCount == 1 ? "" : "s") for 24 hours from the attention queue."
        )
    }

    private func confirmSelectedSellerAttentionItems(_ items: [SellerConciergeAttentionItem]) {
        let actionableItems = items.filter { $0.row.canConfirmProvider }
        guard !actionableItems.isEmpty else {
            sellerHubAlert = SellerHubAlert(
                title: "Nothing to confirm",
                message: "Select at least one provider row that is ready to be marked confirmed."
            )
            return
        }

        var successCount = 0
        for item in actionableItems {
            guard let outcome = store.confirmPostSaleConciergeProvider(
                offerID: item.entry.offer.id,
                userID: store.currentUserID,
                serviceKind: item.row.kind,
                note: ""
            ) else {
                continue
            }

            messaging.sendMessage(
                listing: item.entry.listing,
                from: store.currentUser,
                to: item.entry.buyer,
                body: outcome.threadMessage,
                isSystem: true
            )
            successCount += 1
        }

        selectedAttentionItemIDs.subtract(actionableItems.map(\.id))
        sellerHubAlert = SellerHubAlert(
            title: successCount == 0 ? "Confirmation unavailable" : "Batch confirmation complete",
            message: successCount == 0
                ? "Those provider rows are no longer ready to be confirmed."
                : "Marked \(successCount) concierge provider\(successCount == 1 ? "" : "s") confirmed from the attention queue."
        )
    }

    private var negotiationBoard: some View {
        let entries = sellerNegotiationEntries
        let awaitingSellerAction = entries.filter {
            $0.offer.status != .accepted && $0.offer.contractPacket?.isFullySigned != true
        }.count
        let financeReadyCount = entries.filter { $0.buyer.hasVerifiedCheck(.finance) }.count
        let preferredCount = entries.filter { $0.offer.sellerRelationshipStatus == .preferred }.count
        let comparisonGroupCount = sellerOfferComparisonGroups.filter { $0.entries.count > 1 }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Negotiation board")
                .font(.headline)

            if entries.isEmpty {
                EmptyPanel(message: "Buyer offers will appear here with ranked seller actions once your private listings start receiving interest.")
            } else {
                AdaptiveTagGrid(minimum: 150) {
                    MiniStatPanel(
                        title: "Action now",
                        value: "\(awaitingSellerAction)",
                        subtitle: "Offers waiting on your next move"
                    )
                    MiniStatPanel(
                        title: "Finance ready",
                        value: "\(financeReadyCount)",
                        subtitle: "Buyers with finance verification complete"
                    )
                    MiniStatPanel(
                        title: "Preferred",
                        value: "\(preferredCount)",
                        subtitle: "Offers you've marked as the current best fit"
                    )
                    MiniStatPanel(
                        title: "Compare live",
                        value: "\(comparisonGroupCount)",
                        subtitle: "Listings with multiple offers ready for side-by-side review"
                    )
                }

                HighlightInformationCard(
                    title: "Ranked by seller priority",
                    message: "Offers are ranked using buyer trust, contract readiness, offer status, price strength, and recency so you can focus on the best next move first.",
                    supporting: "Accept, counter, request changes, or jump into the secure thread directly from this board."
                )

                Text("Priority queue")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    SellerOfferComparisonCard(
                        rank: index + 1,
                        entry: entry,
                        canAccept: canAcceptOffer(entry.offer),
                        onSetRelationshipStatus: { status in
                            updateSellerRelationshipStatus(status, for: entry)
                        },
                        onAccept: {
                            handleSellerNegotiationSubmission(
                                listing: entry.listing,
                                offer: entry.offer,
                                action: .accept,
                                amount: entry.offer.amount,
                                conditions: entry.offer.conditions
                            )
                        },
                        onCounter: {
                            negotiationComposer = SellerNegotiationComposerContext(
                                listing: entry.listing,
                                offer: entry.offer,
                                action: .counter
                            )
                        },
                        onRequestChanges: {
                            negotiationComposer = SellerNegotiationComposerContext(
                                listing: entry.listing,
                                offer: entry.offer,
                                action: .requestChanges
                            )
                        },
                        onOpenListing: {
                            selectedListing = entry.listing
                        },
                        onOpenThread: {
                            openConversation(for: entry.listing, buyer: entry.buyer)
                        }
                    )
                }
            }
        }
    }

    private var comparisonWorkspace: some View {
        let groups = sellerOfferComparisonGroups.filter { $0.entries.count > 1 }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Compare buyers by listing")
                .font(.headline)

            if groups.isEmpty {
                EmptyPanel(message: "Once a listing has multiple offers, they will appear here side by side so you can compare price, trust, legal readiness, and next actions.")
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        let preferredCount = group.entries.filter { $0.offer.sellerRelationshipStatus == .preferred }.count
                        let shortlistedCount = group.entries.filter { $0.offer.sellerRelationshipStatus == .shortlisted }.count

                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.listing.title)
                                .font(.headline)
                            Text(group.listing.address.fullLine)
                                .foregroundStyle(.secondary)

                            AdaptiveTagGrid(minimum: 120) {
                                InfoPill(label: "Ask \(currencyString(group.listing.askingPrice))")
                                InfoPill(label: "\(group.entries.count) offers live")
                                InfoPill(label: "\(preferredCount) preferred")
                                InfoPill(label: "\(shortlistedCount) shortlisted")
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                    SellerOfferComparisonCard(
                                        rank: index + 1,
                                        entry: entry,
                                        canAccept: canAcceptOffer(entry.offer),
                                        onSetRelationshipStatus: { status in
                                            updateSellerRelationshipStatus(status, for: entry)
                                        },
                                        onAccept: {
                                            handleSellerNegotiationSubmission(
                                                listing: entry.listing,
                                                offer: entry.offer,
                                                action: .accept,
                                                amount: entry.offer.amount,
                                                conditions: entry.offer.conditions
                                            )
                                        },
                                        onCounter: {
                                            negotiationComposer = SellerNegotiationComposerContext(
                                                listing: entry.listing,
                                                offer: entry.offer,
                                                action: .counter
                                            )
                                        },
                                        onRequestChanges: {
                                            negotiationComposer = SellerNegotiationComposerContext(
                                                listing: entry.listing,
                                                offer: entry.offer,
                                                action: .requestChanges
                                            )
                                        },
                                        onOpenListing: {
                                            selectedListing = entry.listing
                                        },
                                        onOpenThread: {
                                            openConversation(for: entry.listing, buyer: entry.buyer)
                                        }
                                    )
                                    .frame(width: 320, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(BrandPalette.card)
                    )
                }
            }
        }
    }

    private var pricingControlPanel: some View {
        let repricableListings = store.sellerListings(for: store.currentUserID)
            .filter { $0.status == .active || $0.status == .draft }
        let listingsWithChanges = repricableListings.filter { $0.priceJourney.count > 1 }.count
        let latestUpdatedListing = repricableListings
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

        return VStack(alignment: .leading, spacing: 12) {
            Text("Pricing controls")
                .font(.headline)

            AdaptiveTagGrid(minimum: 150) {
                MiniStatPanel(
                    title: "Reprice ready",
                    value: "\(repricableListings.count)",
                    subtitle: "Active and draft listings can be updated instantly"
                )
                MiniStatPanel(
                    title: "Price changes",
                    value: "\(listingsWithChanges)",
                    subtitle: "Listings already showing a live price journey"
                )
                MiniStatPanel(
                    title: "Latest move",
                    value: latestUpdatedListing.map { shortDateString($0.updatedAt) } ?? "No changes yet",
                    subtitle: latestUpdatedListing.map(\.title) ?? "Your next update will appear here"
                )
            }

            HighlightInformationCard(
                title: "Update asking prices without leaving the deal room",
                message: "Open any seller listing to change the guide price, add a buyer-facing note, and keep the pricing history visible for future buyers and reviewers.",
                supporting: "Active buyer threads are notified automatically when a listing price changes."
            )
        }
    }

    private var sellerListings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your listings")
                .font(.headline)

            let listings = store.sellerListings(for: store.currentUserID)

            if listings.isEmpty {
                EmptyPanel(message: "Create your first private listing to start receiving buyer interest and testing the seller workflow.")
            }

            ForEach(listings) { listing in
                let listingOffers = store.offers.filter { $0.listingID == listing.id }
                let financeReadyBuyerCount = listingOffers
                    .compactMap { store.user(id: $0.buyerID) }
                    .filter { $0.hasVerifiedCheck(.finance) }
                    .count
                let liveDealRoomCount = listingOffers
                    .filter { $0.contractPacket != nil || ($0.buyerLegalSelection != nil && $0.sellerLegalSelection != nil) }
                    .count

                SellerListingCard(
                    listing: listing,
                    seller: store.currentUser,
                    offerCount: listingOffers.count,
                    financeReadyBuyerCount: financeReadyBuyerCount,
                    liveDealRoomCount: liveDealRoomCount,
                    onOpenListing: {
                        selectedListing = listing
                    },
                    onUpdatePrice: {
                        repricingContext = ListingRepriceContext(listing: listing)
                    }
                )
            }
        }
    }

    private func notifyImpactedConversations(for outcome: ListingRepriceOutcome) {
        let seller = store.currentUser
        let buyerIDs = Set(outcome.impactedOffers.map(\.buyerID))

        for buyerID in buyerIDs {
            guard let buyer = store.user(id: buyerID) else { continue }
            _ = messaging.sendMessage(
                listing: outcome.listing,
                from: seller,
                to: buyer,
                body: outcome.threadMessage,
                isSystem: true
            )
        }
    }

    private func handleSellerNegotiationSubmission(
        listing: PropertyListing,
        offer: OfferRecord,
        action: SellerOfferAction,
        amount: Int,
        conditions: String
    ) {
        if let moderationIssue = MarketplaceSafetyPolicy.moderationIssue(for: conditions) {
            sellerHubAlert = SellerHubAlert(
                title: "Offer needs changes",
                message: moderationIssue.localizedDescription
            )
            return
        }

        guard let outcome = store.respondToOffer(
            offerID: offer.id,
            userID: store.currentUserID,
            action: action,
            amount: amount,
            conditions: conditions
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Response unavailable",
                message: "Could not update this offer right now."
            )
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
            sellerHubAlert = SellerHubAlert(
                title: "Negotiation updated",
                message: "\(outcome.noticeMessage) Contract packet refreshed in secure messages."
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: "Negotiation updated",
                message: outcome.noticeMessage
            )
        }
    }

    private func updateSellerRelationshipStatus(
        _ status: SellerBuyerRelationshipStatus,
        for entry: SellerOfferBoardEntry
    ) {
        guard let outcome = store.updateSellerRelationshipStatus(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            status: status
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Buyer status unavailable",
                message: "Could not update this buyer status right now."
            )
            return
        }

        sellerHubAlert = SellerHubAlert(
            title: "Buyer status updated",
            message: outcome.noticeMessage
        )
    }

    private func canAcceptOffer(_ offer: OfferRecord) -> Bool {
        canSellerAccept(offer: offer, among: store.offers)
    }

    private func nextChecklistItem(for offer: OfferRecord) -> SaleChecklistItem? {
        offer.settlementChecklist.first { $0.status != .completed }
    }

    private func executionPrimaryAction(for entry: SellerOfferBoardEntry) -> SellerDealExecutionActionDescriptor? {
        guard let nextItem = nextChecklistItem(for: entry.offer) else {
            return nil
        }

        let buyer = store.user(id: entry.offer.buyerID)
        let seller = store.user(id: entry.offer.sellerID)
        let missingContractIssueSteps = contractIssueMissingSteps(buyer: buyer, seller: seller)

        switch nextItem.id {
        case "seller-representative":
            guard entry.offer.sellerLegalSelection == nil else {
                return nil
            }
            return SellerDealExecutionActionDescriptor(
                title: "Choose seller legal rep",
                supporting: "Pick your conveyancer or solicitor so the legal handoff can keep moving.",
                kind: .chooseSellerLegalRep
            )
        case "buyer-representative":
            return SellerDealExecutionActionDescriptor(
                title: "Prompt buyer for legal rep",
                supporting: "Ask the buyer to choose their conveyancer so the contract packet can be issued.",
                kind: .nudgeBuyer(
                    checklistItemID: nextItem.id,
                    body: "Seller requested that the buyer choose a legal representative so the contract packet can be issued for this private sale."
                )
            )
        case "contract-packet":
            if seller?.hasVerifiedCheck(.ownership) != true {
                return SellerDealExecutionActionDescriptor(
                    title: "Upload ownership proof",
                    supporting: "Seller ownership review still needs evidence before the contract packet can issue.",
                    kind: .uploadVerification(.ownership)
                )
            }

            if entry.offer.sellerLegalSelection == nil {
                return SellerDealExecutionActionDescriptor(
                    title: "Choose seller legal rep",
                    supporting: "Your legal representative still needs to be selected before the contract can issue.",
                    kind: .chooseSellerLegalRep
                )
            }

            if !missingContractIssueSteps.isEmpty {
                return SellerDealExecutionActionDescriptor(
                    title: "Prompt buyer to unblock contract",
                    supporting: missingContractIssueSteps.joined(separator: " • "),
                    kind: .nudgeBuyer(
                        checklistItemID: nextItem.id,
                        body: "Seller is ready to move forward. Buyer-side setup is still blocking the contract packet: \(missingContractIssueSteps.joined(separator: "; "))."
                    )
                )
            }

            return nil
        case "workspace-invites", "workspace-active":
            return inviteExecutionAction(for: entry.offer, checklistItemID: nextItem.id)
        case "contract-signatures":
            if let packet = entry.offer.contractPacket,
               entry.offer.status == .accepted,
               packet.signedAt(for: store.currentUserID) == nil,
               !packet.isFullySigned {
                return SellerDealExecutionActionDescriptor(
                    title: "Sign contract packet",
                    supporting: "Your signature is still needed before the deal can move toward settlement.",
                    kind: .signContract
                )
            }

            return SellerDealExecutionActionDescriptor(
                title: "Prompt buyer to sign",
                supporting: "Your sign-off is recorded. Ask the buyer to complete the remaining signature.",
                kind: .nudgeBuyer(
                    checklistItemID: nextItem.id,
                    body: "Seller requested that the buyer review and sign the contract packet so the private sale can keep moving toward settlement."
                )
            )
        case "legal-review-pack":
            return SellerDealExecutionActionDescriptor(
                title: "Request legal review pack",
                supporting: "Ask the buyer to follow up so the reviewed contract and settlement adjustment PDFs are uploaded.",
                kind: .nudgeBuyer(
                    checklistItemID: nextItem.id,
                    body: "Seller requested an update on the legal review pack so the private sale can keep moving."
                )
            )
        case "settlement-statement":
            return SellerDealExecutionActionDescriptor(
                title: "Request settlement statement",
                supporting: "Ask the buyer to follow up with legal reps so the settlement statement PDF is uploaded.",
                kind: .nudgeBuyer(
                    checklistItemID: nextItem.id,
                    body: "Seller requested the settlement statement so final settlement paperwork can be completed."
                )
            )
        case "settlement-complete":
            return SellerDealExecutionActionDescriptor(
                title: "Confirm settlement complete",
                supporting: "Use the settlement statement and signed contract to close the file once funds and keys have been exchanged.",
                kind: .confirmSettlement
            )
        default:
            return nil
        }
    }

    private func executionBlockingSummary(for entry: SellerOfferBoardEntry) -> String? {
        guard let nextItem = nextChecklistItem(for: entry.offer) else {
            return nil
        }

        if nextItem.id == "contract-packet" {
            let missingSteps = contractIssueMissingSteps(
                buyer: store.user(id: entry.offer.buyerID),
                seller: store.user(id: entry.offer.sellerID)
            )
            if !missingSteps.isEmpty {
                return "Still blocked: \(missingSteps.joined(separator: " • "))"
            }
        }

        return nextItem.supporting
    }

    private func inviteExecutionAction(
        for offer: OfferRecord,
        checklistItemID: String
    ) -> SellerDealExecutionActionDescriptor? {
        guard let invite = prioritizedInvite(for: offer, checklistItemID: checklistItemID) else {
            return nil
        }

        let audience = invite.role.audienceLabel.lowercased()
        if invite.isUnavailable {
            return SellerDealExecutionActionDescriptor(
                title: "Regenerate \(audience) invite",
                supporting: "The current invite can no longer be opened, so a fresh share code is needed.",
                kind: .regenerateInvite(invite.role)
            )
        }

        let title = invite.hasBeenShared ? "Resend \(audience) invite" : "Share \(audience) invite"
        let supporting: String
        if invite.needsFollowUp {
            supporting = "This invite has not been opened yet. Resend it and keep the legal workspace moving."
        } else if invite.hasBeenShared {
            supporting = "The invite is already live. Resend it if the legal rep still needs the latest link and code."
        } else {
            supporting = "Send the invite link and code so the legal workspace can become active."
        }

        return SellerDealExecutionActionDescriptor(
            title: title,
            supporting: supporting,
            kind: .shareInvite(invite.role)
        )
    }

    private func prioritizedInvite(
        for offer: OfferRecord,
        checklistItemID: String
    ) -> SaleWorkspaceInvite? {
        let invites = offer.invites.sorted { left, right in
            if left.createdAt == right.createdAt {
                return left.role.rawValue < right.role.rawValue
            }
            return left.createdAt > right.createdAt
        }

        if checklistItemID == "workspace-invites" {
            return invites.first(where: \.isUnavailable)
                ?? invites.first(where: { !$0.hasBeenShared })
                ?? invites.first(where: \.needsFollowUp)
                ?? invites.first(where: { !$0.isAcknowledged })
                ?? invites.first
        }

        return invites.first(where: \.isUnavailable)
            ?? invites.first(where: \.needsFollowUp)
            ?? invites.first(where: { !$0.isAcknowledged })
            ?? invites.first(where: { !$0.isActivated })
            ?? invites.first
    }

    private func performExecutionAction(
        _ action: SellerDealExecutionActionDescriptor,
        for entry: SellerOfferBoardEntry
    ) {
        switch action.kind {
        case .chooseSellerLegalRep:
            executionLegalSearchContext = LegalSearchContext(offerID: entry.offer.id, role: .seller)
        case let .shareInvite(role):
            guard let invite = entry.offer.invites
                .filter({ $0.role == role })
                .sorted(by: { $0.createdAt > $1.createdAt })
                .first else {
                sellerHubAlert = SellerHubAlert(
                    title: "Invite unavailable",
                    message: "That legal workspace invite is no longer available."
                )
                return
            }

            executionShareInviteContext = SaleInviteShareContext(
                listingID: entry.listing.id,
                offerID: entry.offer.id,
                role: invite.role,
                title: invite.role.title,
                shareMessage: invite.shareMessage
            )
        case let .regenerateInvite(role):
            handleExecutionInviteManagement(
                listing: entry.listing,
                offer: entry.offer,
                role: role,
                action: .regenerate
            )
        case .signContract:
            handleExecutionContractSigning(listing: entry.listing, offer: entry.offer)
        case .confirmSettlement:
            handleExecutionSettlementCompletion(listing: entry.listing, offer: entry.offer)
        case let .uploadVerification(kind):
            completeExecutionVerificationCheck(kind)
        case let .nudgeBuyer(checklistItemID, body):
            sendExecutionBuyerNudge(
                listing: entry.listing,
                offer: entry.offer,
                checklistItemID: checklistItemID,
                body: body
            )
        }
    }

    private func handleExecutionLegalSelection(
        listing: PropertyListing,
        offerID: UUID,
        role: UserRole,
        professional: LegalProfessional
    ) {
        guard role == .seller,
              let outcome = store.selectLegalProfessional(
                offerID: offerID,
                userID: store.currentUserID,
                professional: professional
              ),
              let updatedOffer = store.offer(id: offerID),
              let buyer = store.user(id: updatedOffer.buyerID),
              let seller = store.user(id: updatedOffer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Selection unavailable",
                message: "Could not save that legal representative right now."
            )
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
            sellerHubAlert = SellerHubAlert(
                title: "Legal rep saved",
                message: "Seller legal representative saved. The contract packet has been sent in secure messages."
            )
        } else if updatedOffer.isLegallyCoordinated {
            let missingSteps = contractIssueMissingSteps(buyer: buyer, seller: seller)
            sellerHubAlert = SellerHubAlert(
                title: "Legal rep saved",
                message: missingSteps.isEmpty
                    ? "Seller legal representative saved for this deal."
                    : "Seller legal representative saved. Contract issue is waiting on: \(missingSteps.joined(separator: ", "))."
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: "Legal rep saved",
                message: "Seller legal representative saved for this deal."
            )
        }
    }

    private func handleExecutionInviteManagement(
        listing: PropertyListing,
        offer: OfferRecord,
        role: LegalInviteRole,
        action: SaleInviteManagementAction
    ) {
        guard let outcome = store.manageSaleInvite(
            offerID: offer.id,
            role: role,
            action: action,
            triggeredBy: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Invite unavailable",
                message: "Could not update that legal workspace invite right now."
            )
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

        sellerHubAlert = SellerHubAlert(
            title: "Invite updated",
            message: outcome.noticeMessage
        )
    }

    private func handleExecutionInviteShare(
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
            sellerHubAlert = SellerHubAlert(
                title: "Invite unavailable",
                message: "Could not track that invite share right now."
            )
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

        sellerHubAlert = SellerHubAlert(
            title: "Invite shared",
            message: outcome.noticeMessage
        )
    }

    private func handleExecutionContractSigning(
        listing: PropertyListing,
        offer: OfferRecord
    ) {
        guard let outcome = store.signContractPacket(
            offerID: offer.id,
            userID: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Signing unavailable",
                message: "Could not record the contract sign-off right now."
            )
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

        sellerHubAlert = SellerHubAlert(
            title: "Contract updated",
            message: outcome.noticeMessage
        )
    }

    private func handleExecutionSettlementCompletion(
        listing: PropertyListing,
        offer: OfferRecord
    ) {
        guard let outcome = store.completeSettlement(
            offerID: offer.id,
            userID: store.currentUserID
        ),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Settlement unavailable",
                message: "Could not close out settlement right now."
            )
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
                checklistItemID: "settlement-complete"
            )
        )

        sellerHubAlert = SellerHubAlert(
            title: "Settlement complete",
            message: outcome.noticeMessage
        )
    }

    private func sendExecutionBuyerNudge(
        listing: PropertyListing,
        offer: OfferRecord,
        checklistItemID: String,
        body: String
    ) {
        guard let buyer = store.user(id: offer.buyerID),
              let seller = store.user(id: offer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Buyer unavailable",
                message: "Could not send that reminder right now."
            )
            return
        }

        messaging.sendMessage(
            listing: listing,
            from: seller,
            to: buyer,
            body: body,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: offer.id,
                checklistItemID: checklistItemID
            )
        )

        sellerHubAlert = SellerHubAlert(
            title: "Buyer notified",
            message: "A secure follow-up was sent to the buyer for this milestone."
        )
    }

    private func completeExecutionVerificationCheck(_ kind: VerificationCheckKind) {
        if kind.requiresDocumentUpload {
            pendingVerificationUploadKind = kind
            return
        }

        guard let outcome = store.completeVerificationCheck(
            userID: store.currentUserID,
            kind: kind
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Check already complete",
                message: "That trust check is already complete."
            )
            return
        }

        for unlocked in outcome.unlockedContractPackets {
            guard let unlockedListing = store.listing(id: unlocked.offer.listingID),
                  let buyer = store.user(id: unlocked.offer.buyerID),
                  let seller = store.user(id: unlocked.offer.sellerID) else {
                continue
            }

            messaging.sendContractPacket(
                listing: unlockedListing,
                offerID: unlocked.offer.id,
                buyer: buyer,
                seller: seller,
                packet: unlocked.packet,
                triggeredBy: store.currentUser
            )
        }

        sellerHubAlert = SellerHubAlert(
            title: "Verification updated",
            message: outcome.unlockedContractPackets.isEmpty
                ? outcome.noticeMessage
                : "\(outcome.noticeMessage) The contract packet has been refreshed in secure messages."
        )
    }

    private func handleImportedVerificationDocument(_ result: Result<[URL], Error>) {
        guard let kind = pendingVerificationUploadKind else {
            return
        }

        defer { pendingVerificationUploadKind = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                sellerHubAlert = SellerHubAlert(
                    title: "No PDF selected",
                    message: "Choose a PDF to continue the verification step."
                )
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? defaultVerificationUploadFileName(for: kind)
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let outcome = store.uploadVerificationDocument(
                    userID: store.currentUserID,
                    kind: kind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf"
                ) else {
                    sellerHubAlert = SellerHubAlert(
                        title: "Upload unavailable",
                        message: "Could not attach that verification PDF right now."
                    )
                    return
                }

                for unlocked in outcome.unlockedContractPackets {
                    guard let unlockedListing = store.listing(id: unlocked.offer.listingID),
                          let buyer = store.user(id: unlocked.offer.buyerID),
                          let seller = store.user(id: unlocked.offer.sellerID) else {
                        continue
                    }

                    messaging.sendContractPacket(
                        listing: unlockedListing,
                        offerID: unlocked.offer.id,
                        buyer: buyer,
                        seller: seller,
                        packet: unlocked.packet,
                        triggeredBy: store.currentUser
                    )
                }

                sellerHubAlert = SellerHubAlert(
                    title: "Verification updated",
                    message: outcome.unlockedContractPackets.isEmpty
                        ? outcome.noticeMessage
                        : "\(outcome.noticeMessage) The contract packet has been refreshed in secure messages."
                )
            } catch {
                sellerHubAlert = SellerHubAlert(
                    title: "Upload unavailable",
                    message: "Could not read that verification PDF right now."
                )
            }
        case .failure:
            sellerHubAlert = SellerHubAlert(
                title: "Upload cancelled",
                message: "The PDF picker was cancelled."
            )
        }
    }

    private func defaultVerificationUploadFileName(for kind: VerificationCheckKind) -> String {
        switch kind {
        case .finance:
            return "finance-proof.pdf"
        case .ownership:
            return "ownership-proof.pdf"
        case .identity:
            return "identity-check.pdf"
        case .mobile:
            return "mobile-check.pdf"
        case .legal:
            return "legal-check.pdf"
        }
    }

    private func keyExecutionDocuments(for offer: OfferRecord) -> [SaleDocument] {
        let preferredOrder: [SaleDocumentKind] = [
            .settlementStatementPDF,
            .signedContractPDF,
            .reviewedContractPDF,
            .settlementAdjustmentPDF,
            .contractPacketPDF
        ]

        let documentsByKind = store.saleDocuments(for: offer.id).reduce(into: [SaleDocumentKind: SaleDocument]()) { partialResult, document in
            if let existing = partialResult[document.kind], existing.createdAt >= document.createdAt {
                return
            }
            partialResult[document.kind] = document
        }

        return preferredOrder.compactMap { documentsByKind[$0] }
    }

    private func conciergeRows(for offer: OfferRecord) -> [ArchiveConciergeRow] {
        PostSaleConciergeServiceKind.allCases.map { serviceKind in
            let booking = offer.conciergeBooking(for: serviceKind)
            let detail: String

            if let booking {
                let rescheduleSuffix = conciergeRescheduleSummary(for: booking).map { " \($0)" } ?? ""
                let issueSuffix = conciergeIssueSummary(for: booking).map { " \($0)" } ?? ""
                let confirmationSuffix = conciergeProviderConfirmationSummary(for: booking).map { " \($0)" } ?? ""
                let responseSlaSuffix = conciergeResponseSLASummary(for: booking).map { " \($0)" } ?? ""
                let followUpSuffix = conciergeFollowUpSummary(for: booking).map { " \($0)" } ?? ""
                if booking.isCancelled {
                        let cancelledDetail = booking.cancelledAt.map { " cancelled \(relativeDateString($0))" } ?? " cancelled"
                        let reasonDetail = booking.cancellationReason.map { " Reason: \($0)." } ?? ""
                    let refundDetail: String
                    if booking.isRefunded {
                        refundDetail = booking.refundAmount.map {
                            " Refund recorded: \(currencyString($0))."
                        } ?? " Refund recorded."
                    } else if booking.isPaid {
                        refundDetail = " Refund pending."
                    } else {
                        refundDetail = ""
                    }
                    detail = "\(booking.provider.name)\(cancelledDetail).\(reasonDetail)\(refundDetail)\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(rescheduleSuffix)\(issueSuffix)"
                } else if booking.isCompleted {
                    if let completedAt = booking.completedAt {
                        let quoteDetail = booking.isQuoteApproved ? " Quote approved." : " Quote approval pending."
                        let invoiceDetail = booking.invoiceAmount.map {
                            " Invoice total: \(currencyString($0))."
                        } ?? (booking.hasInvoiceAttachment ? " Invoice on file." : " Invoice not uploaded.")
                        let paymentDetail: String
                        if booking.isPaid {
                            let paidLine = booking.paidAmount.map { " Payment recorded: \(currencyString($0))." } ?? " Payment recorded."
                            paymentDetail = paidLine + (booking.hasPaymentProof ? " Proof on file." : "")
                        } else {
                            paymentDetail = booking.hasPaymentProof ? " Payment proof uploaded." : " Payment proof pending."
                        }
                        detail = "\(booking.provider.name) completed \(relativeDateString(completedAt)).\(quoteDetail)\(invoiceDetail)\(paymentDetail)\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(rescheduleSuffix)\(issueSuffix)"
                    } else {
                        detail = "\(booking.provider.name) has been marked complete for this settled deal.\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(rescheduleSuffix)\(issueSuffix)"
                    }
                } else {
                    let schedule = "\(shortDateString(booking.scheduledFor)) at \(timeString(booking.scheduledFor))"
                    let costSuffix = booking.estimatedCost.map { " Quote: \(currencyString($0))." } ?? ""
                    let quoteApprovalSuffix = booking.isQuoteApproved ? " Quote approved." : (booking.estimatedCost != nil ? " Quote approval pending." : "")
                    let invoiceSuffix = booking.invoiceAmount.map {
                        " Invoice total: \(currencyString($0))."
                    } ?? (booking.hasInvoiceAttachment ? " Invoice on file." : " Invoice not uploaded.")
                    let paymentSuffix: String
                    if booking.isPaid {
                        paymentSuffix = booking.paidAmount.map {
                            " Paid: \(currencyString($0))."
                        } ?? " Paid."
                    } else if booking.hasPaymentProof {
                        paymentSuffix = " Payment proof uploaded."
                    } else {
                        paymentSuffix = ""
                    }
                    let notesSuffix = booking.notes.isEmpty ? "" : " Notes: \(booking.notes)"
                    detail = "\(booking.provider.name) booked for \(schedule).\(costSuffix)\(quoteApprovalSuffix)\(invoiceSuffix)\(paymentSuffix)\(confirmationSuffix)\(responseSlaSuffix)\(followUpSuffix)\(notesSuffix)\(rescheduleSuffix)\(issueSuffix)"
                }
            } else {
                detail = serviceKind.detail
            }

            return ArchiveConciergeRow(
                kind: serviceKind,
                title: serviceKind.title,
                detail: detail,
                statusText: conciergeStatusText(for: booking),
                actionTitle: booking == nil ? "Book" : ((booking?.isCompleted == true || booking?.isCancelled == true) ? "Rebook" : "Update"),
                isBooked: booking != nil,
                isCompleted: booking?.isCompleted == true,
                isCancelled: booking?.isCancelled == true,
                isQuoteApproved: booking?.isQuoteApproved == true,
                isProviderConfirmed: booking?.isProviderConfirmed == true,
                isReminderSnoozed: booking?.isReminderSnoozed == true,
                isResponseDueSoon: booking?.isResponseDueSoon == true,
                needsFollowUp: booking?.needsResponseFollowUp == true,
                isPaid: booking?.isPaid == true,
                isRefunded: booking?.isRefunded == true,
                hasBeenRescheduled: booking?.hasBeenRescheduled == true,
                hasOpenIssue: booking?.hasOpenIssue == true,
                hasResolvedIssue: booking?.hasResolvedIssue == true,
                issueKindTitle: booking?.issueKind?.title,
                providerHistoryCount: booking?.providerHistoryCountValue ?? 0,
                latestProviderAuditSummary: booking.flatMap(conciergeProviderAuditSummary(for:)),
                estimatedCost: booking?.estimatedCost,
                invoiceAmount: booking?.invoiceAmount,
                paidAmount: booking?.paidAmount,
                refundAmount: booking?.refundAmount,
                canApproveQuote: booking?.estimatedCost != nil && booking?.isQuoteApproved != true && booking?.isCancelled != true && booking?.isRefunded != true,
                canCancel: booking != nil && booking?.isCompleted != true && booking?.isCancelled != true,
                canRecordRefund: booking != nil &&
                    booking?.isRefunded != true &&
                    ((booking?.isPaid == true) || (booking?.hasPaymentProof == true) || (booking?.invoiceAmount != nil) || (booking?.hasInvoiceAttachment == true)),
                canLogIssue: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isRefunded != true &&
                    booking?.hasOpenIssue != true,
                canResolveIssue: booking?.hasOpenIssue == true,
                canLogFollowUp: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isCompleted != true &&
                    booking?.isProviderConfirmed != true &&
                    ((booking?.needsResponseFollowUp == true) ||
                     (booking?.isResponseDueSoon == true) ||
                     (booking?.lastFollowUpAt != nil)),
                canSnoozeReminder: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isCompleted != true &&
                    booking?.isProviderConfirmed != true &&
                    booking?.isReminderSnoozed != true &&
                    ((booking?.needsResponseFollowUp == true) || (booking?.isResponseDueSoon == true)),
                canConfirmProvider: booking != nil &&
                    booking?.isCancelled != true &&
                    booking?.isCompleted != true &&
                    booking?.isProviderConfirmed != true,
                canMarkDone: booking != nil && booking?.isCompleted != true && booking?.isCancelled != true && booking?.hasOpenIssue != true,
                canUploadInvoice: booking != nil && booking?.isCancelled != true,
                canUploadPaymentProof: booking != nil &&
                    ((booking?.invoiceAmount != nil) || (booking?.hasInvoiceAttachment == true)) &&
                    booking?.hasPaymentProof != true &&
                    booking?.isRefunded != true,
                hasInvoiceDocument: booking?.hasInvoiceAttachment == true,
                hasPaymentProofDocument: booking?.hasPaymentProof == true,
                hasQuoteDocument: booking?.estimatedCost != nil,
                hasConfirmationDocument: booking?.isCompleted == true
            )
        }
    }

    private func postSaleServiceRows(for offer: OfferRecord) -> [ArchiveServiceRow] {
        PostSaleServiceTaskKind.allCases.map { task in
            let completedAt = offer.completedAt(for: task)
            return ArchiveServiceRow(
                kind: task,
                title: task.title,
                detail: completedAt == nil
                    ? task.detail
                    : "\(task.title) completed \(relativeDateString(completedAt!)).",
                isCompleted: completedAt != nil
            )
        }
    }

    private func postSaleFeedbackRows(
        for offer: OfferRecord,
        currentRole: UserRole
    ) -> [ArchiveFeedbackRow] {
        let myFeedback = offer.feedback(for: currentRole)
        let counterpartRole: UserRole = currentRole == .buyer ? .seller : .buyer
        let counterpartFeedback = offer.feedback(for: counterpartRole)

        return [
            ArchiveFeedbackRow(
                id: "me",
                title: "Your feedback",
                detail: myFeedback.map {
                    "\($0.rating)-star rating • \(shortDateString($0.submittedAt))\n\($0.notes)"
                } ?? "No feedback saved yet for this settled deal.",
                isSubmitted: myFeedback != nil
            ),
            ArchiveFeedbackRow(
                id: "counterpart",
                title: counterpartRole == .buyer ? "Buyer feedback" : "Seller feedback",
                detail: counterpartFeedback.map {
                    "\($0.rating)-star rating • \(shortDateString($0.submittedAt))\n\($0.notes)"
                } ?? "No feedback has been shared by the other side yet.",
                isSubmitted: counterpartFeedback != nil
            )
        ]
    }

    private func archiveDocuments(for offer: OfferRecord) -> [SaleDocument] {
        let preferredOrder: [SaleDocumentKind] = [
            .settlementSummaryPDF,
            .handoverChecklistPDF,
            .settlementStatementPDF,
            .signedContractPDF,
            .reviewedContractPDF,
            .settlementAdjustmentPDF,
            .contractPacketPDF
        ]

        let documentsByKind = store.saleDocuments(for: offer.id).reduce(into: [SaleDocumentKind: SaleDocument]()) { partialResult, document in
            if let existing = partialResult[document.kind], existing.createdAt >= document.createdAt {
                return
            }
            partialResult[document.kind] = document
        }

        return preferredOrder.compactMap { documentsByKind[$0] }
    }

    private func openExecutionDocument(
        _ document: SaleDocument,
        for entry: SellerOfferBoardEntry
    ) {
        guard let buyer = store.user(id: entry.offer.buyerID),
              let seller = store.user(id: entry.offer.sellerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Document unavailable",
                message: "That sale document is not ready to open yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.render(
                document: document,
                listing: entry.listing,
                offer: entry.offer,
                buyer: buyer,
                seller: seller
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Document unavailable",
                message: "Could not prepare that sale document preview right now."
            )
        }
    }

    private func openConversation(for listing: PropertyListing, buyer: UserProfile) {
        let seller = store.currentUser
        let thread = messaging.ensureConversation(listing: listing, buyer: buyer, seller: seller)
        selectedConversationID = thread.id
        selectedTab = .messages
    }

    private func prepareSellerArchiveShare(for entry: SellerOfferBoardEntry) {
        let documents = archiveDocuments(for: entry.offer)
        let conciergeBookings = entry.offer.conciergeBookings
        guard !documents.isEmpty || !conciergeBookings.isEmpty else {
            sellerHubAlert = SellerHubAlert(
                title: "Archive unavailable",
                message: "There are no closeout documents ready to export for this settled sale yet."
            )
            return
        }

        do {
            let rendered = try documents.map {
                try SaleDocumentRenderer.render(
                    document: $0,
                    listing: entry.listing,
                    offer: entry.offer,
                    buyer: entry.buyer,
                    seller: store.currentUser
                )
            } + conciergeBookings.map {
                try SaleDocumentRenderer.renderPostSaleConciergeReceipt(
                    booking: $0,
                    listing: entry.listing,
                    offer: entry.offer,
                    buyer: entry.buyer,
                    seller: store.currentUser
                )
            }
            archiveShareContext = SaleArchiveShareContext(
                title: "Real O Who closeout pack",
                fileURLs: rendered.map(\.url)
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Archive unavailable",
                message: "Could not prepare the closeout pack right now."
            )
        }
    }

    private func completeSellerPostSaleTask(
        _ task: PostSaleServiceTaskKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let outcome = store.completePostSaleServiceTask(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            task: task
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Service unavailable",
                message: "That post-sale service step is already complete or not ready yet."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Archive updated",
            message: outcome.noticeMessage
        )
    }

    private func openSellerConciergeBooking(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry,
        focus: PostSaleConciergeBookingFocus = .standard,
        preferredProviderID: String? = nil
    ) {
        conciergeBookingContext = PostSaleConciergeBookingContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.buyer.name,
            focus: focus,
            preferredProviderID: preferredProviderID,
            preferredReplacementStrategy: store.currentUser.conciergeReplacementStrategy,
            currentBooking: entry.offer.conciergeBooking(for: serviceKind)
        )
    }

    private func handleSellerConciergePrimaryAction(
        _ serviceKind: PostSaleConciergeServiceKind,
        booking: PostSaleConciergeBooking?,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking else {
            openSellerConciergeBooking(serviceKind, for: entry)
            return
        }

        switch conciergeAttentionPrimaryAction(for: booking) {
        case .switchProvider:
            openSellerConciergeBooking(serviceKind, for: entry, focus: .replacement)
        case .callProvider:
            if let callURL = conciergeProviderCallURL(booking.provider) {
                openURL(callURL)
            } else {
                openSellerConciergeBooking(serviceKind, for: entry)
            }
        case .reviewBooking, .viewBooking:
            openSellerConciergeBooking(serviceKind, for: entry)
        }
    }

    private func prepareSellerSuggestedReplacement(
        _ serviceKind: PostSaleConciergeServiceKind,
        booking: PostSaleConciergeBooking,
        itemID: String,
        cachedSuggestion: ConciergeReplacementSuggestion? = nil,
        for entry: SellerOfferBoardEntry
    ) {
        if let cachedSuggestion {
            openSellerConciergeBooking(
                serviceKind,
                for: entry,
                focus: .replacement,
                preferredProviderID: cachedSuggestion.provider.id
            )
            sellerHubAlert = SellerHubAlert(
                title: "Best backup ready",
                message: "\(cachedSuggestion.provider.name) is already ranked as the strongest replacement for this \(serviceKind.title.lowercased()) booking."
            )
            return
        }

        preparingSuggestedReplacementItemID = itemID

        Task {
            do {
                let providers = try await store.searchPostSaleConciergeProviders(
                    for: entry.listing,
                    serviceKind: serviceKind
                )
                let bestProvider = bestConciergeReplacementProvider(
                    for: booking,
                    listing: entry.listing,
                    candidates: providers,
                    strategy: store.currentUser.conciergeReplacementStrategy
                )

                await MainActor.run {
                    preparingSuggestedReplacementItemID = nil
                    openSellerConciergeBooking(
                        serviceKind,
                        for: entry,
                        focus: .replacement,
                        preferredProviderID: bestProvider?.id
                    )
                    sellerHubAlert = SellerHubAlert(
                        title: bestProvider == nil ? "Replacement options opened" : "Best backup ready",
                        message: bestProvider == nil
                            ? "No ranked backup was available yet, so the full replacement sheet is open for manual selection."
                            : "\(bestProvider!.name) is preselected as the strongest replacement for this \(serviceKind.title.lowercased()) booking."
                    )
                }
            } catch {
                await MainActor.run {
                    preparingSuggestedReplacementItemID = nil
                    openSellerConciergeBooking(serviceKind, for: entry, focus: .replacement)
                    sellerHubAlert = SellerHubAlert(
                        title: "Replacement search unavailable",
                        message: "Could not rank local backups right now, but the replacement sheet is open so you can choose one manually."
                    )
                }
            }
        }
    }

    @MainActor
    private func prefetchSellerSuggestedReplacementPreview(
        itemID: String,
        serviceKind: PostSaleConciergeServiceKind,
        booking: PostSaleConciergeBooking,
        entry: SellerOfferBoardEntry
    ) async {
        let fingerprint = conciergeReplacementPreviewFingerprint(
            for: booking,
            strategy: store.currentUser.conciergeReplacementStrategy
        )
        guard conciergeAttentionPrimaryAction(for: booking) == .switchProvider,
              suggestedReplacementPreviewFingerprints[itemID] != fingerprint ||
                suggestedReplacementPreviews[itemID] == nil,
              loadingSuggestedReplacementPreviewIDs.contains(itemID) == false else {
            return
        }

        loadingSuggestedReplacementPreviewIDs.insert(itemID)
        defer { loadingSuggestedReplacementPreviewIDs.remove(itemID) }

        do {
            let providers = try await store.searchPostSaleConciergeProviders(
                for: entry.listing,
                serviceKind: serviceKind
            )
            let rankedProviders = rankedConciergeReplacementProviders(
                for: booking,
                listing: entry.listing,
                candidates: providers,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
            guard let bestProvider = rankedProviders.first else {
                return
            }

            suggestedReplacementPreviews[itemID] = conciergeReplacementSuggestion(
                for: bestProvider,
                currentBooking: booking,
                listing: entry.listing,
                rankedCandidates: rankedProviders,
                strategy: store.currentUser.conciergeReplacementStrategy
            )
            suggestedReplacementPreviewFingerprints[itemID] = fingerprint
        } catch {
            return
        }
    }

    private func handleSellerReminderTarget(_ target: SaleReminderNavigationTarget?) {
        guard let target,
              let serviceKind = target.conciergeServiceKind else {
            return
        }
        defer { onResolveReminderTarget(target) }

        guard let offer = store.offer(id: target.offerID),
              offer.sellerID == store.currentUserID,
              let listing = store.listing(id: offer.listingID),
              let buyer = store.user(id: offer.buyerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Reminder unavailable",
                message: "That concierge reminder is no longer available."
            )
            return
        }

        let booking = offer.conciergeBooking(for: serviceKind)
        if let booking {
            conciergeBookingContext = PostSaleConciergeBookingContext(
                offerID: offer.id,
                listing: listing,
                serviceKind: serviceKind,
                counterpartName: buyer.name,
                focus: .standard,
                preferredProviderID: nil,
                preferredReplacementStrategy: store.currentUser.conciergeReplacementStrategy,
                currentBooking: booking
            )

            let alertTitle: String
            let alertMessage: String
            if booking.needsResponseFollowUp {
                alertTitle = "\(serviceKind.title) follow-up due"
                alertMessage = "\(booking.provider.name) has not confirmed this booking yet. Open the booking to log a provider follow-up or snooze the reminder."
            } else if booking.isResponseDueSoon, let responseDueAt = booking.responseDueAt {
                alertTitle = "\(serviceKind.title) reply due soon"
                alertMessage = "\(booking.provider.name) is expected to reply by \(responseDueAt.formatted(date: .abbreviated, time: .shortened)). Open the booking to keep the handover moving."
            } else {
                alertTitle = "\(serviceKind.title) booking opened"
                alertMessage = "This booking is open so you can review the current provider status."
            }

            sellerHubAlert = SellerHubAlert(
                title: alertTitle,
                message: alertMessage
            )
            return
        }

        sellerHubAlert = SellerHubAlert(
            title: "Reminder unavailable",
            message: "This provider reminder is no longer active."
        )
    }

    private func bookSellerPostSaleConciergeService(
        context: PostSaleConciergeBookingContext,
        provider: PostSaleConciergeProvider,
        scheduledFor: Date,
        notes: String,
        estimatedCost: Int?
    ) {
        guard let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID),
              let outcome = store.bookPostSaleConciergeService(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                provider: provider,
                scheduledFor: scheduledFor,
                notes: notes,
                estimatedCost: estimatedCost
              ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Booking unavailable",
                message: "Could not save that moving concierge booking right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenSellerBatchReview(
                batchReviewReturnContext,
                successTitle: "Booking saved",
                successMessage: outcome.noticeMessage
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: "Booking saved",
                message: outcome.noticeMessage
            )
        }
    }

    private func confirmSellerConciergeProvider(
        context: PostSaleConciergeBookingContext,
        note: String
    ) {
        guard let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID),
              let outcome = store.confirmPostSaleConciergeProvider(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                note: note
              ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Confirmation unavailable",
                message: "That concierge booking is not ready for provider confirmation right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenSellerBatchReview(
                batchReviewReturnContext,
                successTitle: "Provider confirmed",
                successMessage: outcome.noticeMessage
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: "Provider confirmed",
                message: outcome.noticeMessage
            )
        }
    }

    private func logSellerConciergeFollowUp(
        context: PostSaleConciergeBookingContext
    ) {
        guard let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID),
              let outcome = store.logPostSaleConciergeFollowUp(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                note: ""
              ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Follow-up unavailable",
                message: "That concierge booking is not ready for provider follow-up right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenSellerBatchReview(
                batchReviewReturnContext,
                successTitle: "Follow-up logged",
                successMessage: outcome.noticeMessage
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: "Follow-up logged",
                message: outcome.noticeMessage
            )
        }
    }

    private func snoozeSellerConciergeReminder(
        context: PostSaleConciergeBookingContext
    ) {
        guard let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID),
              let outcome = store.snoozePostSaleConciergeFollowUp(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                until: Date().addingTimeInterval(60 * 60 * 24)
              ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Snooze unavailable",
                message: "That concierge follow-up cannot be snoozed right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenSellerBatchReview(
                batchReviewReturnContext,
                successTitle: "Reminder snoozed",
                successMessage: outcome.noticeMessage
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: "Reminder snoozed",
                message: outcome.noticeMessage
            )
        }
    }

    private func openSellerConciergeResolution(
        context: PostSaleConciergeBookingContext,
        mode: PostSaleConciergeResolutionMode
    ) {
        guard let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID),
              let booking = offer.conciergeBooking(for: context.serviceKind) else {
            sellerHubAlert = SellerHubAlert(
                title: "Review unavailable",
                message: "That concierge booking is no longer available for a review update."
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            conciergeResolutionContext = PostSaleConciergeResolutionContext(
                offerID: offer.id,
                listing: context.listing,
                serviceKind: context.serviceKind,
                counterpartName: buyer.name,
                booking: booking,
                mode: mode,
                batchReviewReturnContext: context.batchReviewReturnContext
            )
        }
    }

    private func openSellerConciergeQuote(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              booking.estimatedCost != nil else {
            sellerHubAlert = SellerHubAlert(
                title: "Quote unavailable",
                message: "There is no quote summary ready for that concierge booking yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderPostSaleConciergeQuote(
                booking: booking,
                listing: entry.listing,
                offer: entry.offer,
                buyer: entry.buyer,
                seller: store.currentUser
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Quote unavailable",
                message: "Could not prepare that quote summary right now."
            )
        }
    }

    private func approveSellerConciergeQuote(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let outcome = store.approvePostSaleConciergeQuote(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Approval unavailable",
                message: "That concierge quote is not ready to approve right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Quote approved",
            message: outcome.noticeMessage
        )
    }

    private func uploadSellerConciergeInvoice(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        conciergeInvoiceUploadContext = PostSaleConciergeInvoiceUploadContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind
        )
    }

    private func openSellerConciergeInvoice(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              let fileName = booking.invoiceFileName,
              let attachmentBase64 = booking.invoiceAttachmentBase64 else {
            sellerHubAlert = SellerHubAlert(
                title: "Invoice unavailable",
                message: "There is no uploaded invoice on file for that concierge booking yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderAttachment(
                title: "\(serviceKind.title) invoice",
                fileName: fileName,
                attachmentBase64: attachmentBase64
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Invoice unavailable",
                message: "Could not prepare that invoice PDF right now."
            )
        }
    }

    private func uploadSellerConciergePaymentProof(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        conciergePaymentUploadContext = PostSaleConciergePaymentUploadContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind
        )
    }

    private func openSellerConciergePaymentProof(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              let fileName = booking.paymentProofFileName,
              let attachmentBase64 = booking.paymentProofAttachmentBase64 else {
            sellerHubAlert = SellerHubAlert(
                title: "Payment proof unavailable",
                message: "There is no uploaded payment proof on file for that concierge booking yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderAttachment(
                title: "\(serviceKind.title) payment proof",
                fileName: fileName,
                attachmentBase64: attachmentBase64
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Payment proof unavailable",
                message: "Could not prepare that payment proof PDF right now."
            )
        }
    }

    private func cancelSellerConciergeService(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            sellerHubAlert = SellerHubAlert(
                title: "Cancellation unavailable",
                message: "There is no concierge booking to cancel right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.buyer.name,
            booking: booking,
            mode: .cancel
        )
    }

    private func recordSellerConciergeRefund(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            sellerHubAlert = SellerHubAlert(
                title: "Refund unavailable",
                message: "There is no concierge booking ready for a refund record right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.buyer.name,
            booking: booking,
            mode: .refund
        )
    }

    private func logSellerConciergeIssue(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            sellerHubAlert = SellerHubAlert(
                title: "Issue unavailable",
                message: "There is no concierge booking ready for an issue log right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.buyer.name,
            booking: booking,
            mode: .logIssue
        )
    }

    private func resolveSellerConciergeIssue(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            sellerHubAlert = SellerHubAlert(
                title: "Issue unavailable",
                message: "There is no concierge booking issue to resolve right now."
            )
            return
        }

        conciergeResolutionContext = PostSaleConciergeResolutionContext(
            offerID: entry.offer.id,
            listing: entry.listing,
            serviceKind: serviceKind,
            counterpartName: entry.buyer.name,
            booking: booking,
            mode: .resolveIssue
        )
    }

    private func confirmSellerConciergeProvider(
        _ serviceKind: PostSaleConciergeServiceKind,
        note: String,
        for entry: SellerOfferBoardEntry?
    ) {
        guard let entry else {
            sellerHubAlert = SellerHubAlert(
                title: "Confirmation unavailable",
                message: "That concierge booking is no longer available."
            )
            return
        }

        guard let outcome = store.confirmPostSaleConciergeProvider(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind,
            note: note
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Confirmation unavailable",
                message: "That concierge booking is not ready for provider confirmation right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Provider confirmed",
            message: outcome.noticeMessage
        )
    }

    private func logSellerConciergeFollowUp(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let outcome = store.logPostSaleConciergeFollowUp(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind,
            note: ""
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Follow-up unavailable",
                message: "That concierge booking is not ready for provider follow-up right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Follow-up logged",
            message: outcome.noticeMessage
        )
    }

    private func snoozeSellerConciergeReminder(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let outcome = store.snoozePostSaleConciergeFollowUp(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind,
            until: Date().addingTimeInterval(60 * 60 * 24)
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Snooze unavailable",
                message: "That concierge follow-up cannot be snoozed right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Reminder snoozed",
            message: outcome.noticeMessage
        )
    }

    private func exportSellerConciergeReceipt(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind) else {
            sellerHubAlert = SellerHubAlert(
                title: "Receipt unavailable",
                message: "There is no concierge booking receipt ready to export yet."
            )
            return
        }

        do {
            let receipt = try SaleDocumentRenderer.renderPostSaleConciergeReceipt(
                booking: booking,
                listing: entry.listing,
                offer: entry.offer,
                buyer: entry.buyer,
                seller: store.currentUser
            )
            archiveShareContext = SaleArchiveShareContext(
                title: "Real O Who concierge receipt",
                fileURLs: [receipt.url]
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Receipt unavailable",
                message: "Could not prepare that concierge receipt right now."
            )
        }
    }

    private func openSellerConciergeConfirmation(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let booking = entry.offer.conciergeBooking(for: serviceKind),
              booking.isCompleted else {
            sellerHubAlert = SellerHubAlert(
                title: "Proof unavailable",
                message: "That concierge booking has not been completed yet."
            )
            return
        }

        do {
            preparedDocument = try SaleDocumentRenderer.renderPostSaleConciergeConfirmation(
                booking: booking,
                listing: entry.listing,
                offer: entry.offer,
                buyer: entry.buyer,
                seller: store.currentUser
            )
        } catch {
            sellerHubAlert = SellerHubAlert(
                title: "Proof unavailable",
                message: "Could not prepare that service completion proof right now."
            )
        }
    }

    private func completeSellerConciergeService(
        _ serviceKind: PostSaleConciergeServiceKind,
        for entry: SellerOfferBoardEntry
    ) {
        guard let outcome = store.completePostSaleConciergeBooking(
            offerID: entry.offer.id,
            userID: store.currentUserID,
            serviceKind: serviceKind
        ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Update unavailable",
                message: "Could not mark that concierge booking complete right now."
            )
            return
        }

        messaging.sendMessage(
            listing: entry.listing,
            from: store.currentUser,
            to: entry.buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Archive updated",
            message: outcome.noticeMessage
        )
    }

    private func handleSellerConciergeResolution(
        context: PostSaleConciergeResolutionContext,
        issueKind: PostSaleConciergeIssueKind?,
        note: String,
        amount: Int?
    ) {
        guard let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID) else {
            sellerHubAlert = SellerHubAlert(
                title: "Archive unavailable",
                message: "That concierge update is no longer available."
            )
            return
        }

        let outcome: PostSaleConciergeBookingOutcome?
        let successTitle: String

        switch context.mode {
        case .cancel:
            outcome = store.cancelPostSaleConciergeBooking(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                reason: note
            )
            successTitle = "Booking cancelled"
        case .refund:
            outcome = store.recordPostSaleConciergeRefund(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                refundAmount: amount,
                note: note
            )
            successTitle = "Refund recorded"
        case .logIssue:
            outcome = store.logPostSaleConciergeIssue(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                issueKind: issueKind ?? .other,
                note: note
            )
            successTitle = "Issue logged"
        case .resolveIssue:
            outcome = store.resolvePostSaleConciergeIssue(
                offerID: context.offerID,
                userID: store.currentUserID,
                serviceKind: context.serviceKind,
                resolutionNote: note
            )
            successTitle = "Issue resolved"
        }

        guard let outcome else {
            sellerHubAlert = SellerHubAlert(
                title: "Update unavailable",
                message: "Could not save that concierge update right now."
            )
            return
        }

        messaging.sendMessage(
            listing: context.listing,
            from: store.currentUser,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        if let batchReviewReturnContext = context.batchReviewReturnContext {
            reopenSellerBatchReview(
                batchReviewReturnContext,
                successTitle: successTitle,
                successMessage: outcome.noticeMessage
            )
        } else {
            sellerHubAlert = SellerHubAlert(
                title: successTitle,
                message: outcome.noticeMessage
            )
        }
    }

    private func handleImportedConciergeInvoice(_ result: Result<[URL], Error>) {
        guard let context = conciergeInvoiceUploadContext else {
            return
        }

        defer { conciergeInvoiceUploadContext = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let listing = store.listing(id: context.listing.id),
                  let offer = store.offer(id: context.offerID),
                  let buyer = store.user(id: offer.buyerID) else {
                sellerHubAlert = SellerHubAlert(
                    title: "Invoice unavailable",
                    message: "No PDF was selected."
                )
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? "concierge-invoice.pdf"
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let estimatedCost = offer.conciergeBooking(for: context.serviceKind)?.estimatedCost
                guard let outcome = store.uploadPostSaleConciergeInvoice(
                    offerID: context.offerID,
                    userID: store.currentUserID,
                    serviceKind: context.serviceKind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf",
                    invoiceAmount: estimatedCost
                ) else {
                    sellerHubAlert = SellerHubAlert(
                        title: "Invoice unavailable",
                        message: "Could not save that invoice right now."
                    )
                    return
                }

                messaging.sendMessage(
                    listing: listing,
                    from: store.currentUser,
                    to: buyer,
                    body: outcome.threadMessage,
                    isSystem: true
                )

                sellerHubAlert = SellerHubAlert(
                    title: "Invoice saved",
                    message: outcome.noticeMessage
                )
            } catch {
                sellerHubAlert = SellerHubAlert(
                    title: "Invoice unavailable",
                    message: "Could not read that invoice PDF right now."
                )
            }
        case .failure:
            sellerHubAlert = SellerHubAlert(
                title: "Invoice unavailable",
                message: "Could not import that invoice PDF right now."
            )
        }
    }

    private func handleImportedConciergePaymentProof(_ result: Result<[URL], Error>) {
        guard let context = conciergePaymentUploadContext else {
            return
        }

        defer { conciergePaymentUploadContext = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let listing = store.listing(id: context.listing.id),
                  let offer = store.offer(id: context.offerID),
                  let buyer = store.user(id: offer.buyerID) else {
                sellerHubAlert = SellerHubAlert(
                    title: "Payment proof unavailable",
                    message: "No PDF was selected."
                )
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? "concierge-payment-proof.pdf"
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let paidAmount = offer.conciergeBooking(for: context.serviceKind)?.invoiceAmount ??
                    offer.conciergeBooking(for: context.serviceKind)?.estimatedCost
                guard let outcome = store.uploadPostSaleConciergePaymentProof(
                    offerID: context.offerID,
                    userID: store.currentUserID,
                    serviceKind: context.serviceKind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf",
                    paidAmount: paidAmount
                ) else {
                    sellerHubAlert = SellerHubAlert(
                        title: "Payment proof unavailable",
                        message: "Could not save that payment proof right now."
                    )
                    return
                }

                messaging.sendMessage(
                    listing: listing,
                    from: store.currentUser,
                    to: buyer,
                    body: outcome.threadMessage,
                    isSystem: true
                )

                sellerHubAlert = SellerHubAlert(
                    title: "Payment proof saved",
                    message: outcome.noticeMessage
                )
            } catch {
                sellerHubAlert = SellerHubAlert(
                    title: "Payment proof unavailable",
                    message: "Could not read that payment proof PDF right now."
                )
            }
        case .failure:
            sellerHubAlert = SellerHubAlert(
                title: "Payment proof unavailable",
                message: "Could not import that payment proof PDF right now."
            )
        }
    }

    private func submitSellerPostSaleFeedback(
        context: PostSaleFeedbackContext,
        rating: Int,
        notes: String
    ) {
        guard let listing = store.listing(id: context.listingID),
              let offer = store.offer(id: context.offerID),
              let buyer = store.user(id: offer.buyerID),
              let outcome = store.submitPostSaleFeedback(
                offerID: context.offerID,
                userID: store.currentUserID,
                rating: rating,
                notes: notes
              ) else {
            sellerHubAlert = SellerHubAlert(
                title: "Feedback unavailable",
                message: "Could not save post-sale feedback right now."
            )
            return
        }

        messaging.sendMessage(
            listing: listing,
            from: store.currentUser,
            to: buyer,
            body: outcome.threadMessage,
            isSystem: true
        )

        sellerHubAlert = SellerHubAlert(
            title: "Feedback saved",
            message: outcome.noticeMessage
        )
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
    @EnvironmentObject private var taskSnapshots: SaleTaskSnapshotSyncStore

    @State private var isDeletingAccount = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var deleteAccountErrorMessage: String?
    @State private var verificationNotice: ListingNotice?
    @State private var pendingVerificationUploadKind: VerificationCheckKind?
    @State private var preparedVerificationDocument: PreparedSaleDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Account",
                        subtitle: "This app opens straight into a built-in local starter profile so buyers and sellers can use the marketplace immediately."
                    )

                    brandPromise
                    if let notice = store.authLifecycleNotice {
                        HighlightInformationCard(
                            title: "Account updated",
                            message: notice,
                            supporting: "Your latest listing, offer, and messaging context is ready across the app."
                        )
                    }
                    currentAccountCard
                    reviewAccessCard
                    reminderControlCard
                    replacementStrategyControlCard
                    verificationCenterCard
                    safetyControlsCard
                    dataAndPrivacyCard
                    launchAccessCard
                    marketplaceArchitecture
                    legalLinks
                }
                .padding(20)
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Account")
            .alert("Delete account?", isPresented: $isShowingDeleteAccountConfirmation) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteCurrentAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the active local starter profile data from this device. Real O Who will stay usable with the built-in marketplace sample data.")
            }
            .alert(
                "Couldn’t delete account",
                isPresented: Binding(
                    get: { deleteAccountErrorMessage != nil },
                    set: { if !$0 { deleteAccountErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteAccountErrorMessage ?? "")
            }
            .alert(item: $verificationNotice) { notice in
                Alert(title: Text("Verification updated"), message: Text(notice.message), dismissButton: .default(Text("OK")))
            }
            .sheet(item: $preparedVerificationDocument) { document in
                SaleDocumentPreviewSheet(document: document)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { pendingVerificationUploadKind != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingVerificationUploadKind = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedVerificationDocument(result)
            }
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
                        colors: [BrandPalette.card, BrandPalette.panel],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var currentAccountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active profile")
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

                Text("Trust status: \(trustSummaryLine(for: store.currentUser))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandPalette.teal)

                Text("Concierge reminder mode: \(store.currentUser.conciergeReminderIntensity.title)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandPalette.navy)

                Text("Concierge backup mode: \(store.currentUser.conciergeReplacementStrategy.title)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandPalette.teal)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private var reviewAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("App Review access")
                .font(.headline)

            Text("Switch between the built-in buyer and seller demo profiles here. No username or password is required to review both account types.")
                .foregroundStyle(.secondary)

            if let buyer = preferredDemoProfile(for: .buyer) {
                Button {
                    switchToDemoProfile(buyer)
                } label: {
                    PersonaCard(user: buyer, isSelected: buyer.id == store.currentUserID)
                }
                .buttonStyle(.plain)
            }

            if let seller = preferredDemoProfile(for: .seller) {
                Button {
                    switchToDemoProfile(seller)
                } label: {
                    PersonaCard(user: seller, isSelected: seller.id == store.currentUserID)
                }
                .buttonStyle(.plain)
            }

            HighlightInformationCard(
                title: store.currentUser.role == .seller ? "Seller demo is active" : "Buyer demo is active",
                message: store.currentUser.role == .seller
                    ? "Open Sell to review listing management, offer ranking, repricing, legal handoff, contract execution, settlement, and concierge follow-through."
                    : "Open Browse, Saved, and Messages for buyer flows, or tap the seller demo above to unlock Seller Hub immediately.",
                supporting: "This switch changes the in-app demo profile only and does not require a separate sign-in session."
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private var reminderControlCard: some View {
        let dashboard = store.currentUserConciergeReminderDashboard

        return VStack(alignment: .leading, spacing: 14) {
            Text("Reminder preferences")
                .font(.headline)

            Text("Choose how strongly Real O Who should surface concierge provider follow-ups after settlement.")
                .foregroundStyle(.secondary)

            Picker(
                "Concierge reminder mode",
                selection: Binding(
                    get: { store.currentUser.conciergeReminderIntensity },
                    set: { newValue in
                        store.updateConciergeReminderIntensity(
                            userID: store.currentUserID,
                            intensity: newValue
                        )
                    }
                )
            ) {
                ForEach(ConciergeReminderIntensity.allCases) { intensity in
                    Text(intensity.shortTitle).tag(intensity)
                }
            }
            .pickerStyle(.segmented)

            Text(store.currentUser.conciergeReminderIntensity.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 150) {
                MiniStatPanel(
                    title: "Urgent",
                    value: "\(dashboard.overdueCount)",
                    subtitle: dashboard.overdueCount == 0
                        ? "No overdue provider replies"
                        : "Overdue concierge follow-ups"
                )

                if store.currentUser.conciergeReminderIntensity.showsDueSoonAttention {
                    MiniStatPanel(
                        title: "Due soon",
                        value: "\(dashboard.dueSoonCount)",
                        subtitle: "Upcoming provider reply windows"
                    )
                }

                MiniStatPanel(
                    title: "Snoozed",
                    value: "\(dashboard.snoozedCount)",
                    subtitle: "Paused concierge reminder windows"
                )
            }

            if dashboard.hasEscalatedAttention {
                HighlightInformationCard(
                    title: "Concierge attention active",
                    message: dashboard.headline,
                    supporting: dashboard.supportingLine
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private var replacementStrategyControlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Backup provider strategy")
                .font(.headline)

            Text("Choose how Real O Who should rank concierge replacement providers when a settled-deal booking needs a safer backup.")
                .foregroundStyle(.secondary)

            Picker(
                "Concierge backup mode",
                selection: Binding(
                    get: { store.currentUser.conciergeReplacementStrategy },
                    set: { newValue in
                        store.updateConciergeReplacementStrategy(
                            userID: store.currentUserID,
                            strategy: newValue
                        )
                    }
                )
            ) {
                ForEach(ConciergeReplacementStrategy.allCases) { strategy in
                    Text(strategy.title).tag(strategy)
                }
            }
            .pickerStyle(.segmented)

            Text(store.currentUser.conciergeReplacementStrategy.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HighlightInformationCard(
                title: "\(store.currentUser.conciergeReplacementStrategy.title) mode is active",
                message: "Queue-generated backup suggestions and replacement sheets now open using this preference by default.",
                supporting: "You can still override the ranking inside any replacement flow without changing the rest of the app."
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private var verificationCenterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verification centre")
                .font(.headline)

            Text("Real O Who uses simple trust signals so buyers and sellers can see who is ready to move from enquiry into a private-sale deal room.")
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 150) {
                MiniStatPanel(
                    title: "Trust score",
                    value: "\(store.currentUser.trustScore)%",
                    subtitle: trustHeadline(for: store.currentUser)
                )
                MiniStatPanel(
                    title: "Checks",
                    value: "\(store.currentUser.verifiedCheckCount)/\(store.currentUser.verificationChecks.count)",
                    subtitle: store.currentUser.pendingCheckCount == 0 ? "Everything in this starter profile is review-ready" : "\(store.currentUser.pendingCheckCount) checks still pending"
                )
            }

            VerificationChecklistView(
                user: store.currentUser,
                onAction: handleVerificationAction,
                onPreviewDocument: previewVerificationDocument
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private var safetyControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety controls")
                .font(.headline)

            Text("Secure Messages includes an abusive-language filter, in-thread reporting, blocking, and direct support links so App Review and customers can find moderation tools quickly.")
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 150) {
                FeatureTile(
                    title: "Safety filter",
                    subtitle: "Threatening or abusive message text is blocked from posting and hidden if it appears in a synced thread."
                )
                FeatureTile(
                    title: "Report tools",
                    subtitle: "Use the menu inside Secure Messages to report a conversation or a specific incoming message."
                )
                FeatureTile(
                    title: "Block control",
                    subtitle: "Block an abusive buyer or seller from the same Secure Messages menu."
                )
                FeatureTile(
                    title: "Support links",
                    subtitle: "Website, support, privacy, and email contact stay visible in Account for App Review and customer support."
                )
            }
        }
    }

    private var dataAndPrivacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data and privacy")
                .font(.headline)

            Text("Local profile deletion is available directly in the app so users can remove the active starter profile and its sale data from this device without leaving Real O Who.")
                .foregroundStyle(.secondary)

            Button(isDeletingAccount ? "Deleting Account..." : "Delete Account") {
                isShowingDeleteAccountConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDeletingAccount)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
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
                    title: "Local starter profile",
                    subtitle: "The app launches directly into a working local buyer profile with saved state, listings, offers, and messages."
                )
            }
        }
    }

    private var launchAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Launch-ready access")
                .font(.headline)

            Text("No sign-in is required for App Review. Real O Who opens directly into a local starter profile with working browse, saved homes, seller tools, messaging, and legal workflow content.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 150) {
                FeatureTile(
                    title: "Browse now",
                    subtitle: "Open the Browse tab to search live sample listings, view pricing, and inspect market detail cards."
                )
                FeatureTile(
                    title: "Message safely",
                    subtitle: "Open Messages to review secure sample conversations with reporting and blocking controls."
                )
                FeatureTile(
                    title: "Sell privately",
                    subtitle: "Use Sell to review listing management, offers, contract signing, and legal handoff workflows. If seller mode is not active, switch profiles in App Review access above."
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
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
    private func deleteCurrentAccount() async {
        let deletedUserID = store.currentUserID
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await store.deleteCurrentAccount()
            messaging.removeUserData(for: deletedUserID)
            taskSnapshots.removeState(for: SaleTaskSnapshotSyncStore.viewerID(forUser: deletedUserID))
        } catch {
            deleteAccountErrorMessage = error.localizedDescription
        }
    }

    private func completeVerificationCheck(_ kind: VerificationCheckKind) {
        guard let outcome = store.completeVerificationCheck(
            userID: store.currentUserID,
            kind: kind
        ) else {
            verificationNotice = ListingNotice(message: "That trust check is already complete.")
            return
        }

        for unlocked in outcome.unlockedContractPackets {
            guard let listing = store.listing(id: unlocked.offer.listingID),
                  let buyer = store.user(id: unlocked.offer.buyerID),
                  let seller = store.user(id: unlocked.offer.sellerID) else {
                continue
            }

            messaging.sendContractPacket(
                listing: listing,
                offerID: unlocked.offer.id,
                buyer: buyer,
                seller: seller,
                packet: unlocked.packet,
                triggeredBy: store.currentUser
            )
        }

        verificationNotice = ListingNotice(message: outcome.noticeMessage)
    }

    private func handleVerificationAction(_ kind: VerificationCheckKind) {
        if kind.requiresDocumentUpload {
            pendingVerificationUploadKind = kind
        } else {
            completeVerificationCheck(kind)
        }
    }

    private func previewVerificationDocument(_ kind: VerificationCheckKind) {
        guard let check = store.currentUser.verificationCheck(for: kind),
              let fileName = check.evidenceFileName,
              let attachmentBase64 = check.evidenceAttachmentBase64 else {
            verificationNotice = ListingNotice(message: "There is no PDF on file for that verification step yet.")
            return
        }

        do {
            preparedVerificationDocument = try SaleDocumentRenderer.renderAttachment(
                title: check.title,
                fileName: fileName,
                attachmentBase64: attachmentBase64
            )
        } catch {
            verificationNotice = ListingNotice(message: "Could not prepare that verification PDF right now.")
        }
    }

    private func preferredDemoProfile(for role: UserRole) -> UserProfile? {
        if store.currentUser.role == role {
            return store.currentUser
        }

        switch role {
        case .buyer:
            return store.buyers.first
        case .seller:
            return store.sellers.first
        }
    }

    private func switchToDemoProfile(_ user: UserProfile) {
        guard store.currentUserID != user.id else {
            return
        }

        store.setCurrentUser(user.id)
    }

    private func handleImportedVerificationDocument(_ result: Result<[URL], Error>) {
        guard let kind = pendingVerificationUploadKind else {
            return
        }

        defer { pendingVerificationUploadKind = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                verificationNotice = ListingNotice(message: "No PDF was selected.")
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? defaultVerificationUploadFileName(for: kind)
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let outcome = store.uploadVerificationDocument(
                    userID: store.currentUserID,
                    kind: kind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf"
                ) else {
                    verificationNotice = ListingNotice(message: "Could not attach that verification PDF right now.")
                    return
                }

                for unlocked in outcome.unlockedContractPackets {
                    guard let listing = store.listing(id: unlocked.offer.listingID),
                          let buyer = store.user(id: unlocked.offer.buyerID),
                          let seller = store.user(id: unlocked.offer.sellerID) else {
                        continue
                    }

                    messaging.sendContractPacket(
                        listing: listing,
                        offerID: unlocked.offer.id,
                        buyer: buyer,
                        seller: seller,
                        packet: unlocked.packet,
                        triggeredBy: store.currentUser
                    )
                }

                verificationNotice = ListingNotice(message: outcome.noticeMessage)
            } catch {
                verificationNotice = ListingNotice(message: "Could not read that verification PDF right now.")
            }
        case .failure:
            verificationNotice = ListingNotice(message: "The PDF picker was cancelled.")
        }
    }

    private func defaultVerificationUploadFileName(for kind: VerificationCheckKind) -> String {
        switch kind {
        case .finance:
            return "finance-proof.pdf"
        case .ownership:
            return "ownership-evidence.pdf"
        case .identity:
            return "identity-check.pdf"
        case .mobile:
            return "mobile-confirmation.pdf"
        case .legal:
            return "legal-readiness.pdf"
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
    @State private var pendingVerificationUploadKind: VerificationCheckKind?
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
                                privateSaleSavingsCard(for: listing, offer: relevantOffer)
                                pricingTransparencyCard(for: listing, offer: relevantOffer)
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
                                } else if updatedOffer.isLegallyCoordinated {
                                    let missingSteps = contractIssueMissingSteps(
                                        buyer: buyer,
                                        seller: seller
                                    )
                                    notice = ListingNotice(
                                        message: missingSteps.isEmpty
                                            ? "Your legal representative has been saved for this sale."
                                            : "Your legal representative has been saved. Contract issue is waiting on: \(missingSteps.joined(separator: ", "))."
                                    )
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
                    .fileImporter(
                        isPresented: Binding(
                            get: { pendingVerificationUploadKind != nil },
                            set: { isPresented in
                                if !isPresented {
                                    pendingVerificationUploadKind = nil
                                }
                            }
                        ),
                        allowedContentTypes: [.pdf],
                        allowsMultipleSelection: false
                    ) { result in
                        handleImportedVerificationDocument(result)
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
                Label("\(seller.name) • \(trustSummaryLine(for: seller))", systemImage: "checkmark.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                AdaptiveTagGrid(minimum: 120) {
                    ForEach(Array(seller.highlightedVerificationChecks.prefix(3))) { check in
                        VerificationPill(check: check)
                    }
                }
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
                    Button(messageSellerButtonTitle) {
                        openConversation(for: listing)
                    }
                    .buttonStyle(.borderedProminent)

                    if store.currentUser.role != .buyer {
                        Text("Messaging opens from the buyer demo side so the full buyer-to-seller chat flow stays reviewable.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

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
                .fill(BrandPalette.card)
        )
    }

    private func privateSaleSavingsCard(
        for listing: PropertyListing,
        offer: OfferRecord?
    ) -> some View {
        let economics = privateSaleEconomics(for: offer?.amount ?? listing.askingPrice)
        let priceBasisLabel = offer == nil ? "Ask basis" : "Offer basis"

        return VStack(alignment: .leading, spacing: 14) {
            Text("Private-sale savings")
                .font(.headline)

            Text("Real O Who is designed to show the owner what stays in their pocket, not just the headline sale price.")
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 150) {
                MiniStatPanel(
                    title: priceBasisLabel,
                    value: currencyString(economics.priceBasis),
                    subtitle: offer == nil ? "Current asking price" : "Current live offer"
                )
                MiniStatPanel(
                    title: "Indicative fee avoided",
                    value: currencyString(economics.estimatedTraditionalCost),
                    subtitle: "Traditional agent commission + marketing"
                )
                MiniStatPanel(
                    title: "Indicative seller keeps",
                    value: currencyString(economics.estimatedSellerNet),
                    subtitle: "Price basis less traditional sale costs"
                )
            }

            HighlightInformationCard(
                title: "Comparison model",
                message: "Indicative only, based on a common Australian comparison of 2.2% commission plus $4,500 in marketing and admin costs.",
                supporting: "This can become configurable later when flat-fee and optional service bundles are added."
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private func pricingTransparencyCard(
        for listing: PropertyListing,
        offer: OfferRecord?
    ) -> some View {
        let affordabilityGuide = BuyerAffordabilityGuide(priceBasis: offer?.amount ?? listing.askingPrice)
        let estimateRangeLabel = "\(currencyString(listing.marketPulse.valueEstimateLow)) - \(currencyString(listing.marketPulse.valueEstimateHigh))"
        let medianDelta = listing.askingPrice - listing.marketPulse.suburbMedian
        let offerGap = offer.map { $0.amount - listing.askingPrice }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Transparent pricing")
                .font(.headline)

            Text("Track how the owner price moved, where it sits against local value signals, and what the repayments can look like before you move into a private offer.")
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 150) {
                MiniStatPanel(
                    title: "Current ask",
                    value: currencyString(listing.askingPrice),
                    subtitle: priceJourneyHeadline(for: listing)
                )
                MiniStatPanel(
                    title: "Value range",
                    value: estimateRangeLabel,
                    subtitle: pricePositionSummary(for: listing)
                )
                MiniStatPanel(
                    title: "Vs suburb median",
                    value: signedCurrencyString(medianDelta),
                    subtitle: medianDelta == 0
                        ? "Aligned with the local suburb median"
                        : (medianDelta > 0 ? "Above current suburb median" : "Below current suburb median")
                )
                if let offerGap {
                    MiniStatPanel(
                        title: "Offer gap",
                        value: signedCurrencyString(offerGap),
                        subtitle: offerGap == 0
                            ? "Offer matches the current ask"
                            : (offerGap > 0 ? "Offer is above the current ask" : "Offer is below the current ask")
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Price journey")
                    .font(.headline)

                ForEach(listing.sortedPriceJourney) { event in
                    PriceJourneyRow(
                        event: event,
                        currentAskingPrice: listing.askingPrice
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Buyer affordability guide")
                    .font(.headline)

                Text("Use these indicative repayment scenarios to sense-check whether the current ask or offer sits inside your comfort zone before you negotiate directly.")
                    .foregroundStyle(.secondary)

                AdaptiveTagGrid(minimum: 160) {
                    ForEach(affordabilityGuide.scenarios) { scenario in
                        AffordabilityScenarioCard(scenario: scenario)
                    }
                }
            }

            HighlightInformationCard(
                title: "Indicative only",
                message: "Repayments are modeled using a 30-year loan at 6.1% interest and do not include fees, insurance, or local duties.",
                supporting: offer == nil
                    ? "Switch into an active deal room to compare the current offer against the ask here too."
                    : "This guide automatically follows the live offer amount while the deal room is active."
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private func saleWorkspaceCard(for listing: PropertyListing, offer: OfferRecord) -> some View {
        let isBuyerView = offer.buyerID == store.currentUserID
        let buyer = store.user(id: offer.buyerID)
        let seller = store.user(id: offer.sellerID)
        let selectedLegalCount = [offer.buyerLegalSelection, offer.sellerLegalSelection]
            .compactMap { $0 }
            .count
        let signedCount = [offer.contractPacket?.buyerSignedAt, offer.contractPacket?.sellerSignedAt]
            .compactMap { $0 }
            .count
        let completedTaskCount = offer.settlementChecklist.filter { $0.status == .completed }.count

        return VStack(alignment: .leading, spacing: 14) {
            Text("Verified private-sale deal room")
                .font(.headline)

            Text(
                isBuyerView
                    ? "Your offer, seller responses, participant trust signals, and legal handoff stay together here."
                    : "Accept the offer, request changes, or send a counteroffer without leaving the verified private-sale workspace."
            )
            .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: "Ask \(currencyString(listing.askingPrice))")
                InfoPill(label: "Offer \(currencyString(offer.amount))")
                InfoPill(label: offer.status.title)
                if let buyer {
                    InfoPill(label: buyer.hasVerifiedCheck(.finance) ? "Priority buyer" : "Buyer finance pending")
                }
                if let seller {
                    InfoPill(label: seller.hasVerifiedCheck(.ownership) ? "Seller ownership checked" : "Seller ownership pending")
                }
            }

            AdaptiveTagGrid(minimum: 150) {
                if let buyer {
                    MiniStatPanel(
                        title: "Buyer",
                        value: trustHeadline(for: buyer),
                        subtitle: trustSummaryLine(for: buyer)
                    )
                }
                if let seller {
                    MiniStatPanel(
                        title: "Seller",
                        value: trustHeadline(for: seller),
                        subtitle: trustSummaryLine(for: seller)
                    )
                }
                MiniStatPanel(
                    title: "Legal reps",
                    value: "\(selectedLegalCount)/2 chosen",
                    subtitle: selectedLegalCount == 2 ? "Both sides are represented" : "Shared contract issue unlocks at 2"
                )
                MiniStatPanel(
                    title: "Documents",
                    value: "\(offer.documents.count)",
                    subtitle: offer.documents.isEmpty ? "No shared PDFs yet" : "Shared across the sale room"
                )
                MiniStatPanel(
                    title: "Signatures",
                    value: "\(signedCount)/2 signed",
                    subtitle: signedCount == 2 ? "Contract fully signed" : "Contract packet progress"
                )
                MiniStatPanel(
                    title: "Checklist",
                    value: "\(completedTaskCount)/\(offer.settlementChecklist.count)",
                    subtitle: "Shared milestones complete"
                )
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
                .fill(BrandPalette.card)
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
        let canAcceptCurrentOffer = canSellerAccept(offer: offer, among: store.offers)

        if offer.contractPacket?.isFullySigned == true {
            HighlightInformationCard(
                title: "Sale complete",
                message: "Both sides have signed the contract packet and the listing is now marked sold.",
                supporting: "Use the secure thread for any final settlement notes."
            )
        } else {
            HighlightInformationCard(
                title: offer.status == .accepted
                    ? "Offer accepted"
                    : (canAcceptCurrentOffer ? "Seller controls" : "Warm follow-up"),
                message: offer.status == .accepted
                    ? "The current terms have been accepted. You can still open the secure thread and finish the legal handoff."
                    : (canAcceptCurrentOffer
                        ? "Choose whether to accept the current terms, request changes, or send a counteroffer back to the buyer."
                        : "Another buyer is already active on this listing. Keep this buyer warm from Seller Hub or secure messages while the live deal progresses."),
                supporting: canAcceptCurrentOffer
                    ? "Any seller response is posted into secure messages automatically."
                    : "Accept stays unavailable until the active deal is released or completed."
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
            .disabled(offer.status == .accepted || !canAcceptCurrentOffer)

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
        let buyer = store.user(id: offer.buyerID)
        let seller = store.user(id: offer.sellerID)
        let buyerFinanceReady = buyer?.hasVerifiedCheck(.finance) == true
        let sellerOwnershipReady = seller?.hasVerifiedCheck(.ownership) == true
        let missingTrustSteps = contractIssueMissingSteps(buyer: buyer, seller: seller)

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
                if offer.isLegallyCoordinated && !missingTrustSteps.isEmpty {
                    HighlightInformationCard(
                        title: "Verification still required",
                        message: "The contract packet unlocks once buyer finance readiness and seller ownership review are both complete.",
                        supporting: missingTrustSteps.joined(separator: " • ")
                    )
                } else {
                    HighlightInformationCard(
                        title: "Contract not sent yet",
                        message: "Once both sides choose their legal representative, the contract packet is sent to both parties in the secure conversation thread.",
                        supporting: "Current step: \(mySelection == nil ? "choose your legal representative" : "waiting for the other side to choose theirs")"
                    )
                }
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

            if offer.isLegallyCoordinated && offer.contractPacket == nil && !missingTrustSteps.isEmpty {
                HStack(spacing: 12) {
                    if actingRole == .buyer && !buyerFinanceReady {
                        Button("Upload finance proof") {
                            completeWorkflowVerificationCheck(
                                .finance
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if actingRole == .seller && !sellerOwnershipReady {
                        Button("Upload ownership proof") {
                            completeWorkflowVerificationCheck(
                                .ownership
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
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
                .fill(BrandPalette.card)
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
                .fill(BrandPalette.card)
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
                .fill(BrandPalette.card)
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
                .fill(BrandPalette.card)
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
                .fill(BrandPalette.card)
        )
    }

    private func openConversation(for listing: PropertyListing, offer: OfferRecord? = nil) {
        guard let seller = store.user(id: listing.sellerID) else { return }

        let buyer: UserProfile?
        if let offer {
            buyer = store.user(id: offer.buyerID)
        } else if store.currentUser.role == .buyer {
            buyer = store.currentUser
        } else if let buyerDemo = preferredMessagingBuyerProfile() {
            store.setCurrentUser(buyerDemo.id)
            buyer = buyerDemo
        } else {
            buyer = nil
        }

        guard let buyer else {
            notice = ListingNotice(
                message: "Buyer messaging is unavailable right now. Open Account, then switch to the buyer demo profile in App Review access and try again."
            )
            return
        }

        let thread = messaging.ensureConversation(listing: listing, buyer: buyer, seller: seller)
        onOpenMessages(thread.id)
        dismiss()
    }

    private var messageSellerButtonTitle: String {
        store.currentUser.role == .buyer
            ? "Message Seller"
            : "Switch to Buyer Demo and Message Seller"
    }

    private func preferredMessagingBuyerProfile() -> UserProfile? {
        if store.currentUser.role == .buyer {
            return store.currentUser
        }

        return store.buyers.first
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
        if let moderationIssue = MarketplaceSafetyPolicy.moderationIssue(for: conditions) {
            notice = ListingNotice(message: moderationIssue.localizedDescription)
            return
        }

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

    private func completeWorkflowVerificationCheck(_ kind: VerificationCheckKind) {
        if kind.requiresDocumentUpload {
            pendingVerificationUploadKind = kind
            return
        }

        guard let outcome = store.completeVerificationCheck(
            userID: store.currentUserID,
            kind: kind
        ) else {
            notice = ListingNotice(message: "That trust check is already complete.")
            return
        }

        for unlocked in outcome.unlockedContractPackets {
            guard let unlockedListing = store.listing(id: unlocked.offer.listingID),
                  let buyer = store.user(id: unlocked.offer.buyerID),
                  let seller = store.user(id: unlocked.offer.sellerID) else {
                continue
            }

            messaging.sendContractPacket(
                listing: unlockedListing,
                offerID: unlocked.offer.id,
                buyer: buyer,
                seller: seller,
                packet: unlocked.packet,
                triggeredBy: store.currentUser
            )
        }

        notice = ListingNotice(
            message: outcome.unlockedContractPackets.isEmpty
                ? outcome.noticeMessage
                : "\(outcome.noticeMessage) Open secure messages to see the updated contract packet."
        )
    }

    private func handleImportedVerificationDocument(_ result: Result<[URL], Error>) {
        guard let kind = pendingVerificationUploadKind else {
            return
        }

        defer { pendingVerificationUploadKind = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                notice = ListingNotice(message: "No PDF was selected.")
                return
            }

            let fileName = url.lastPathComponent.isEmpty
                ? defaultVerificationUploadFileName(for: kind)
                : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let outcome = store.uploadVerificationDocument(
                    userID: store.currentUserID,
                    kind: kind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf"
                ) else {
                    notice = ListingNotice(message: "Could not attach that verification PDF right now.")
                    return
                }

                for unlocked in outcome.unlockedContractPackets {
                    guard let unlockedListing = store.listing(id: unlocked.offer.listingID),
                          let buyer = store.user(id: unlocked.offer.buyerID),
                          let seller = store.user(id: unlocked.offer.sellerID) else {
                        continue
                    }

                    messaging.sendContractPacket(
                        listing: unlockedListing,
                        offerID: unlocked.offer.id,
                        buyer: buyer,
                        seller: seller,
                        packet: unlocked.packet,
                        triggeredBy: store.currentUser
                    )
                }

                notice = ListingNotice(
                    message: outcome.unlockedContractPackets.isEmpty
                        ? outcome.noticeMessage
                        : "\(outcome.noticeMessage) Open secure messages to see the updated contract packet."
                )
            } catch {
                notice = ListingNotice(message: "Could not read that verification PDF right now.")
            }
        case .failure:
            notice = ListingNotice(message: "The PDF picker was cancelled.")
        }
    }

    private func handleSellerOfferSubmission(
        listing: PropertyListing,
        offer: OfferRecord?,
        action: SellerOfferAction,
        amount: Int,
        conditions: String
    ) {
        if let moderationIssue = MarketplaceSafetyPolicy.moderationIssue(for: conditions) {
            notice = ListingNotice(message: moderationIssue.localizedDescription)
            return
        }

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

    private func defaultVerificationUploadFileName(for kind: VerificationCheckKind) -> String {
        switch kind {
        case .finance:
            return "finance-proof.pdf"
        case .ownership:
            return "ownership-evidence.pdf"
        case .identity:
            return "identity-check.pdf"
        case .mobile:
            return "mobile-confirmation.pdf"
        case .legal:
            return "legal-readiness.pdf"
        }
    }
}

private struct ConversationThreadView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService
    @Environment(\.openURL) private var openURL

    let threadID: UUID
    let onOpenSaleTask: (SaleReminderNavigationTarget) -> Void

    @State private var draft = ""
    @State private var moderationNotice: String?
    @State private var reportContext: ConversationSafetyReportContext?
    @State private var reportConfirmationMessage: String?
    @State private var isShowingBlockConfirmation = false

    var body: some View {
        if let thread = messaging.thread(id: threadID) {
            let listing = store.listing(id: thread.listingID)
            let currentUser = store.currentUser
            let counterpart = thread.participantIDs.first { $0 != currentUser.id }.flatMap { store.user(id: $0) }
            let isBlocked = counterpart.map { messaging.isUserBlocked($0.id, for: currentUser.id) } ?? false

            VStack(spacing: 0) {
                if let listing {
                    ConversationHeader(listing: listing, counterpart: counterpart, encryptionLabel: thread.encryptionLabel)
                }

                if let moderationNotice {
                    HighlightInformationCard(
                        title: "Message blocked",
                        message: moderationNotice,
                        supporting: "Real O Who blocks abusive or threatening text before it can be posted."
                    )
                    .padding([.horizontal, .top], 16)
                }

                if let reportConfirmationMessage {
                    HighlightInformationCard(
                        title: "Safety report saved",
                        message: reportConfirmationMessage,
                        supporting: "Support contact details stay available in Account and in this thread menu."
                    )
                    .padding([.horizontal, .top], 16)
                }

                if isBlocked, let counterpart {
                    HighlightInformationCard(
                        title: "User blocked",
                        message: "You’ve blocked \(counterpart.name). Existing messages stay visible, but new direct messages are disabled until you unblock them.",
                        supporting: "Use the menu in the top-right corner if you need to unblock or file another report."
                    )
                    .padding([.horizontal, .top], 16)
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
                                .contextMenu {
                                    if !message.isSystem,
                                       message.senderID != currentUser.id,
                                       let counterpart {
                                        Button {
                                            reportContext = ConversationSafetyReportContext(
                                                conversationID: thread.id,
                                                listingID: thread.listingID,
                                                reportedUserID: counterpart.id,
                                                title: "Report message from \(counterpart.name)",
                                                messageID: message.id
                                            )
                                        } label: {
                                            Label("Report Message", systemImage: "flag.fill")
                                        }

                                        if isBlocked {
                                            Button {
                                                messaging.unblockUser(counterpart.id, for: currentUser.id)
                                            } label: {
                                                Label("Unblock \(counterpart.name)", systemImage: "person.crop.circle.badge.checkmark")
                                            }
                                        } else {
                                            Button(role: .destructive) {
                                                isShowingBlockConfirmation = true
                                            } label: {
                                                Label("Block \(counterpart.name)", systemImage: "hand.raised.fill")
                                            }
                                        }
                                    }
                                }
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

                if isBlocked, let counterpart {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Messaging paused")
                                .font(.subheadline.weight(.semibold))
                            Text("Unblock \(counterpart.name) from the menu if you want to resume direct contact.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(BrandPalette.input)
                } else {
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("Message buyer or seller", text: $draft, axis: .vertical)
                            .textFieldStyle(.roundedBorder)

                        Button("Send") {
                            guard let listing,
                                  let counterpart else { return }

                            if let moderationIssue = messaging.moderationIssue(forDraft: draft) {
                                moderationNotice = moderationIssue.localizedDescription
                                return
                            }

                            _ = messaging.sendMessage(
                                listing: listing,
                                from: currentUser,
                                to: counterpart,
                                body: draft
                            )
                            moderationNotice = nil
                            draft = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(16)
                    .background(BrandPalette.input)
                }
            }
            .navigationTitle(counterpart?.name ?? "Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let counterpart {
                            Button {
                                reportContext = ConversationSafetyReportContext(
                                    conversationID: thread.id,
                                    listingID: thread.listingID,
                                    reportedUserID: counterpart.id,
                                    title: "Report conversation with \(counterpart.name)",
                                    messageID: nil
                                )
                            } label: {
                                Label("Report Conversation", systemImage: "flag.fill")
                            }

                            if isBlocked {
                                Button {
                                    messaging.unblockUser(counterpart.id, for: currentUser.id)
                                } label: {
                                    Label("Unblock \(counterpart.name)", systemImage: "person.crop.circle.badge.checkmark")
                                }
                            } else {
                                Button(role: .destructive) {
                                    isShowingBlockConfirmation = true
                                } label: {
                                    Label("Block \(counterpart.name)", systemImage: "hand.raised.fill")
                                }
                            }
                        }

                        Button {
                            openURL(LegalLinks.support)
                        } label: {
                            Label("Safety & Support", systemImage: "questionmark.bubble")
                        }

                        Button {
                            openURL(LegalLinks.mail)
                        } label: {
                            Label("Email Support", systemImage: "envelope.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $reportContext) { context in
                ConversationSafetyReportSheet(
                    context: context,
                    onSubmit: { reason, notes in
                        _ = messaging.reportConversation(
                            conversationID: context.conversationID,
                            listingID: context.listingID,
                            reporterID: currentUser.id,
                            reportedUserID: context.reportedUserID,
                            messageID: context.messageID,
                            reason: reason,
                            notes: notes
                        )
                        reportConfirmationMessage = context.messageID == nil
                            ? "We saved your conversation report. You can still contact support directly if the issue needs urgent help."
                            : "We saved your message report. You can still contact support directly if the issue needs urgent help."
                    }
                )
            }
            .alert("Block this user?", isPresented: $isShowingBlockConfirmation) {
                Button("Block User", role: .destructive) {
                    if let counterpart {
                        messaging.blockUser(counterpart.id, for: currentUser.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Blocking stops new direct messages in this thread until you choose to unblock the other person.")
            }
        } else {
            EmptyPanel(message: "Conversation unavailable.")
                .padding()
        }
    }
}

private struct ConversationSafetyReportContext: Identifiable {
    let conversationID: UUID
    let listingID: UUID
    let reportedUserID: UUID
    let title: String
    let messageID: UUID?

    var id: String {
        "\(conversationID.uuidString)-\(messageID?.uuidString ?? "conversation")"
    }
}

private struct ConversationSafetyReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: ConversationSafetyReportContext
    let onSubmit: (MarketplaceSafetyReportReason, String) -> Void

    @State private var reason: MarketplaceSafetyReportReason = .harassment
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(MarketplaceSafetyReportReason.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Details") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 140)
                    Text("Add a few words so support can understand what happened. This note is saved with the report on the device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Report Safety Issue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(reason, notes)
                        dismiss()
                    }
                }
            }
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

private struct PostSaleConciergeSheet: View {
    @EnvironmentObject private var store: MarketplaceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind
    let counterpartName: String
    let focus: PostSaleConciergeBookingFocus
    let preferredProviderID: String?
    let preferredReplacementStrategy: ConciergeReplacementStrategy
    let currentBooking: PostSaleConciergeBooking?
    let manualReviewContext: ConciergeManualReviewContext?
    let onConfirmProvider: ((String) -> Void)?
    let onLogFollowUp: (() -> Void)?
    let onSnoozeReminder: (() -> Void)?
    let onLogIssue: (() -> Void)?
    let onResolveIssue: (() -> Void)?
    let onSubmit: (PostSaleConciergeProvider, Date, String, Int?) -> Void

    @State private var results: [PostSaleConciergeProvider] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProviderID: String?
    @State private var scheduledFor: Date
    @State private var notes: String
    @State private var estimatedCostText: String
    @State private var providerConfirmationNote: String
    @State private var replacementStrategy: ConciergeReplacementStrategy

    init(
        listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind,
        counterpartName: String,
        focus: PostSaleConciergeBookingFocus = .standard,
        preferredProviderID: String? = nil,
        preferredReplacementStrategy: ConciergeReplacementStrategy = .smart,
        currentBooking: PostSaleConciergeBooking?,
        manualReviewContext: ConciergeManualReviewContext? = nil,
        onConfirmProvider: ((String) -> Void)? = nil,
        onLogFollowUp: (() -> Void)? = nil,
        onSnoozeReminder: (() -> Void)? = nil,
        onLogIssue: (() -> Void)? = nil,
        onResolveIssue: (() -> Void)? = nil,
        onSubmit: @escaping (PostSaleConciergeProvider, Date, String, Int?) -> Void
    ) {
        self.listing = listing
        self.serviceKind = serviceKind
        self.counterpartName = counterpartName
        self.focus = focus
        self.preferredProviderID = preferredProviderID
        self.preferredReplacementStrategy = preferredReplacementStrategy
        self.currentBooking = currentBooking
        self.manualReviewContext = manualReviewContext
        self.onConfirmProvider = onConfirmProvider
        self.onLogFollowUp = onLogFollowUp
        self.onSnoozeReminder = onSnoozeReminder
        self.onLogIssue = onLogIssue
        self.onResolveIssue = onResolveIssue
        self.onSubmit = onSubmit
        _selectedProviderID = State(
            initialValue: preferredProviderID ?? (focus == .replacement ? nil : currentBooking?.provider.id)
        )
        _scheduledFor = State(initialValue: currentBooking?.scheduledFor ?? Self.defaultScheduleDate(for: serviceKind))
        _notes = State(initialValue: currentBooking?.notes ?? "")
        _estimatedCostText = State(initialValue: currentBooking?.estimatedCost.map(String.init) ?? "")
        _providerConfirmationNote = State(initialValue: currentBooking?.providerConfirmationNote ?? "")
        _replacementStrategy = State(initialValue: preferredReplacementStrategy)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && results.isEmpty && currentBooking == nil {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Searching local \(serviceKind.title.lowercased()) support near \(listing.address.suburb).")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HighlightInformationCard(
                                title: focus == .replacement ? "Switch \(serviceKind.title.lowercased()) provider" : "\(serviceKind.title) booking",
                                message: focus == .replacement
                                    ? "Choose a replacement provider directly from the settled archive. The outgoing provider trail, follow-ups, receipts, and issue history stay attached to this closed-out sale."
                                    : "Book or switch a local provider directly from the settled archive so the move, clean, utility connection, or key handover stays attached to this closed-out sale.",
                                supporting: "\(listing.address.fullLine) • Coordinating with \(counterpartName)"
                            )

                            if focus == .replacement, let currentBooking {
                                HighlightInformationCard(
                                    title: "Replacement mode is on",
                                    message: "Pick a new \(serviceKind.title.lowercased()) provider below to replace \(currentBooking.provider.name). The current provider remains visible here so you can compare before switching.",
                                    supporting: "The replacement will keep a full audit trail in the archive."
                                )
                            }

                            if let manualReviewContext {
                                HighlightInformationCard(
                                    title: manualReviewContext.title,
                                    message: manualReviewContext.message,
                                    supporting: manualReviewContext.supporting
                                )
                            }

                            if shouldShowQuickActionCard, let currentBooking {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(manualReviewContext == nil ? "Booking actions" : "Manual review actions")
                                        .font(.headline)

                                    Text(conciergeAttentionRecommendation(for: currentBooking).supporting)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    AdaptiveTagGrid(minimum: 150) {
                                        if let callURL = conciergeProviderCallURL(currentBooking.provider) {
                                            Button("Call provider") {
                                                openURL(callURL)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(BrandPalette.coral)
                                        }

                                        if let websiteURL = currentBooking.provider.websiteURL {
                                            Link("Website", destination: websiteURL)
                                                .buttonStyle(.bordered)
                                        }

                                        if let mapsURL = currentBooking.provider.mapsURL {
                                            Link("Maps", destination: mapsURL)
                                                .buttonStyle(.bordered)
                                        }

                                        if canLogFollowUpQuickAction, onLogFollowUp != nil {
                                            Button("Log follow-up") {
                                                performQuickAction(onLogFollowUp)
                                            }
                                            .buttonStyle(.bordered)
                                        }

                                        if canSnoozeQuickAction, onSnoozeReminder != nil {
                                            Button("Snooze 24h") {
                                                performQuickAction(onSnoozeReminder)
                                            }
                                            .buttonStyle(.bordered)
                                        }

                                        if currentBooking.hasOpenIssue, onResolveIssue != nil {
                                            Button("Resolve issue") {
                                                performQuickAction(onResolveIssue)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(BrandPalette.teal)
                                        } else if currentBooking.isCancelled == false,
                                                  currentBooking.isCompleted == false,
                                                  onLogIssue != nil {
                                            Button("Log issue") {
                                                performQuickAction(onLogIssue)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }

                                    Text("Quick actions close this sheet and update the archive from the active buyer or seller hub.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(BrandPalette.card)
                                )
                            }

                            if focus == .replacement {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Ranking strategy")
                                        .font(.headline)

                                    Picker("Ranking strategy", selection: $replacementStrategy) {
                                        ForEach(ConciergeReplacementStrategy.allCases) { strategy in
                                            Text(strategy.title).tag(strategy)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    if let currentBooking {
                                        Text(
                                            conciergeReplacementStrategySupportingLine(
                                                strategy: replacementStrategy,
                                                currentBooking: currentBooking
                                            )
                                        )
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(BrandPalette.card)
                                )

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Suggested replacements")
                                        .font(.headline)

                                    if replacementSuggestions.isEmpty {
                                        EmptyPanel(message: "No ranked replacement shortlist is ready yet. Refresh the search or keep the current provider if the handover is already back on track.")
                                    } else {
                                        Text(replacementSummaryLine)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)

                                        ForEach(replacementSuggestions) { suggestion in
                                            PostSaleConciergeProviderCard(
                                                provider: suggestion.provider,
                                                comparisonLabels: suggestion.labels,
                                                isSelected: selectedProviderID == suggestion.provider.id,
                                                actionTitle: selectedProviderID == suggestion.provider.id ? "Selected" : "Choose replacement",
                                                statusLine: suggestion.statusLine,
                                                safetySummary: suggestion.safetySummary,
                                                onSelect: {
                                                    selectedProviderID = suggestion.provider.id
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Schedule")
                                    .font(.headline)

                                DatePicker(
                                    "Service time",
                                    selection: $scheduledFor,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.graphical)
                                Text("Rescheduling the same provider keeps the saved quote, invoice, payment proof, and receipt history attached. Switching providers keeps the outgoing provider trail in the archive too.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Estimated cost")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("Example: 850", text: $estimatedCostText)
                                        .keyboardType(.numberPad)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(BrandPalette.panel)
                                        )
                                    Text("Optional. This becomes the quote summary in the archive and can be used as the invoice total if no separate amount is supplied.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Booking notes")
                                        .font(.subheadline.weight(.semibold))
                                    TextEditor(text: $notes)
                                        .frame(minHeight: 110)
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(BrandPalette.panel)
                                        )
                                    Text("Add access notes, preferred timing, or handover instructions. Leave it blank if you just want the booking recorded.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(BrandPalette.card)
                            )

                            if let currentBooking {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Current booking")
                                        .font(.headline)

                                    PostSaleConciergeProviderCard(
                                        provider: currentBooking.provider,
                                        comparisonLabels: providerComparisonLabels(for: currentBooking.provider),
                                        isSelected: selectedProviderID == currentBooking.provider.id,
                                        actionTitle: selectedProviderID == currentBooking.provider.id
                                            ? "Selected"
                                            : focus == .replacement
                                            ? "Keep current provider"
                                            : "Use current provider",
                                        statusLine: currentBooking.isCancelled
                                            ? "Cancelled \(currentBooking.cancelledAt.map(relativeDateString) ?? "recently")"
                                            : currentBooking.isCompleted
                                            ? "Completed \(currentBooking.completedAt.map(relativeDateString) ?? "recently")"
                                            : currentBooking.isProviderConfirmed
                                            ? "Confirmed \(currentBooking.providerConfirmedAt.map(relativeDateString) ?? "recently")"
                                            : "Booked for \(shortDateString(currentBooking.scheduledFor)) at \(timeString(currentBooking.scheduledFor))",
                                        safetySummary: nil,
                                        onSelect: {
                                            selectedProviderID = currentBooking.provider.id
                                        }
                                    )

                                    if currentBooking.estimatedCost != nil ||
                                        currentBooking.hasInvoiceAttachment ||
                                        currentBooking.isQuoteApproved ||
                                        currentBooking.isProviderConfirmed ||
                                        currentBooking.providerConfirmationNote != nil ||
                                        currentBooking.hasPaymentProof ||
                                        currentBooking.isPaid ||
                                        currentBooking.hasProviderHistory ||
                                        currentBooking.hasBeenRescheduled ||
                                        currentBooking.hasOpenIssue ||
                                        currentBooking.hasResolvedIssue ||
                                        currentBooking.isCancelled ||
                                        currentBooking.isRefunded {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let estimatedCost = currentBooking.estimatedCost {
                                                Text("Quote estimate: \(currencyString(estimatedCost))")
                                                    .font(.footnote.weight(.semibold))
                                            }
                                            if currentBooking.isQuoteApproved {
                                                Text("Quote approved: \(shortDateString(currentBooking.quoteApprovedAt ?? currentBooking.bookedAt))")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let providerConfirmationSummary = conciergeProviderConfirmationSummary(for: currentBooking) {
                                                Text(providerConfirmationSummary)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let responseSlaSummary = conciergeResponseSLASummary(for: currentBooking) {
                                                Text(responseSlaSummary)
                                                    .font(.footnote)
                                                    .foregroundStyle(currentBooking.needsResponseFollowUp ? .orange : .secondary)
                                            }
                                            if let followUpSummary = conciergeFollowUpSummary(for: currentBooking) {
                                                Text(followUpSummary)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if currentBooking.hasInvoiceAttachment {
                                                Text("Invoice on file: \(currentBooking.invoiceFileName ?? "PDF uploaded")")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if currentBooking.isPaid {
                                                Text("Payment recorded: \(currentBooking.paidAmount.map(currencyString) ?? "Amount not saved")")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            } else if currentBooking.hasPaymentProof {
                                                Text("Payment proof uploaded")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let rescheduleSummary = conciergeRescheduleSummary(for: currentBooking) {
                                                Text(rescheduleSummary)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let issueSummary = conciergeIssueSummary(for: currentBooking) {
                                                Text(issueSummary)
                                                    .font(.footnote)
                                                    .foregroundStyle(currentBooking.hasOpenIssue ? .orange : .secondary)
                                            }
                                            if currentBooking.isCancelled {
                                                Text("Cancellation: \(currentBooking.cancellationReason ?? "No reason saved")")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if currentBooking.isRefunded {
                                                Text("Refund recorded: \(currentBooking.refundAmount.map(currencyString) ?? "Amount not saved")")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    if currentBooking.isCancelled == false,
                                       currentBooking.isCompleted == false,
                                       currentBooking.isProviderConfirmed == false,
                                       let onConfirmProvider {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Provider confirmation")
                                                .font(.subheadline.weight(.semibold))
                                            Text("Call, check the website, or open maps to confirm the booking. Save an optional note so the archive records how the provider was confirmed.")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                            TextField("Optional confirmation note", text: $providerConfirmationNote)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(BrandPalette.panel)
                                                )
                                            Button("Mark provider confirmed") {
                                                onConfirmProvider(providerConfirmationNote)
                                                dismiss()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }

                                    if currentBooking.hasProviderHistory {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Provider history")
                                                .font(.subheadline.weight(.semibold))
                                            ForEach(Array((currentBooking.providerAuditHistory ?? []).prefix(2))) { auditEntry in
                                                Text(conciergeProviderAuditLine(auditEntry))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if currentBooking.providerHistoryCountValue > 2 {
                                                Text("\(currentBooking.providerHistoryCountValue - 2) more previous provider records are kept in the archive export.")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }

                            if let errorMessage {
                                EmptyPanel(message: errorMessage)
                            }

                            if let selectedReplacementImpactSummary {
                                ConciergeReplacementImpactPanel(summary: selectedReplacementImpactSummary)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text(focus == .replacement ? "All nearby alternatives" : "Nearby providers")
                                    .font(.headline)

                                if cheapestProvider != nil || topRatedProvider != nil || fastestProvider != nil {
                                    AdaptiveTagGrid(minimum: 150) {
                                        if let cheapestProvider,
                                           let priceGuide = conciergeProviderPriceGuide(cheapestProvider) {
                                            MiniStatPanel(
                                                title: "Best value",
                                                value: priceGuide,
                                                subtitle: cheapestProvider.name
                                            )
                                        }

                                        if let topRatedProvider,
                                           let rating = topRatedProvider.rating {
                                            MiniStatPanel(
                                                title: "Top rated",
                                                value: "\(rating.formatted(.number.precision(.fractionLength(1)))) stars",
                                                subtitle: topRatedProvider.name
                                            )
                                        }

                                        if let fastestProvider,
                                           let responseLine = conciergeProviderResponseLine(fastestProvider) {
                                            MiniStatPanel(
                                                title: "Fastest reply",
                                                value: responseLine,
                                                subtitle: fastestProvider.name
                                            )
                                        }
                                    }
                                }

                                if displayedResults.isEmpty {
                                    EmptyPanel(message: focus == .replacement
                                        ? "No alternate \(serviceKind.title.lowercased()) providers were found for this suburb yet. You can keep the current provider or refresh the search."
                                        : "No nearby \(serviceKind.title.lowercased()) providers were found for this suburb yet.")
                                } else {
                                    ForEach(displayedResults) { provider in
                                        PostSaleConciergeProviderCard(
                                            provider: provider,
                                            comparisonLabels: comparisonLabels(for: provider),
                                            isSelected: selectedProviderID == provider.id,
                                            actionTitle: selectedProviderID == provider.id
                                                ? "Selected"
                                                : focus == .replacement
                                                ? "Choose replacement"
                                                : "Choose provider",
                                            statusLine: provider.serviceKind.title,
                                            safetySummary: nil,
                                            onSelect: {
                                                selectedProviderID = provider.id
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                    .background(BrandPalette.background.ignoresSafeArea())
                }
            }
            .navigationTitle(serviceKind.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationButtonTitle) {
                        if let provider = selectedProvider {
                            onSubmit(provider, scheduledFor, notes, Int(estimatedCostText.filter(\.isNumber)))
                            dismiss()
                        }
                    }
                    .disabled(selectedProvider == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await loadResults() }
                    }
                }
            }
        }
        .task {
            await loadResults()
        }
        .onChange(of: replacementStrategy) { _, newValue in
            store.updateConciergeReplacementStrategy(
                userID: store.currentUserID,
                strategy: newValue
            )
        }
    }

    private var selectedProvider: PostSaleConciergeProvider? {
        if let currentBooking, currentBooking.provider.id == selectedProviderID {
            return currentBooking.provider
        }
        return results.first { $0.id == selectedProviderID }
    }

    private var displayedResults: [PostSaleConciergeProvider] {
        guard focus == .replacement, let currentBooking else {
            return results
        }

        return rankedConciergeReplacementProviders(
            for: currentBooking,
            listing: listing,
            candidates: results,
            strategy: replacementStrategy
        )
    }

    private var cheapestProvider: PostSaleConciergeProvider? {
        let match = displayedResults
            .compactMap { provider in
                provider.indicativePriceLow.map { (price: $0, provider: provider) }
            }
            .min { left, right in left.0 < right.0 }

        return match?.provider
    }

    private var topRatedProvider: PostSaleConciergeProvider? {
        let match = displayedResults
            .compactMap { provider in
                provider.rating.map { (rating: $0, provider: provider) }
            }
            .max { left, right in left.0 < right.0 }

        return match?.provider
    }

    private var fastestProvider: PostSaleConciergeProvider? {
        let match = displayedResults
            .compactMap { provider in
                provider.estimatedResponseHours.map { (hours: $0, provider: provider) }
            }
            .min { left, right in left.0 < right.0 }

        return match?.provider
    }

    private var confirmationButtonTitle: String {
        guard currentBooking != nil else {
            return "Book"
        }

        guard focus == .replacement else {
            return "Save"
        }

        if selectedProvider?.id == currentBooking?.provider.id {
            return "Keep provider"
        }

        return "Switch provider"
    }

    private var replacementSuggestions: [ConciergeReplacementSuggestion] {
        guard focus == .replacement, let currentBooking else {
            return []
        }

        return Array(displayedResults.prefix(3))
            .map { provider in
                conciergeReplacementSuggestion(
                    for: provider,
                    currentBooking: currentBooking,
                    listing: listing,
                    rankedCandidates: displayedResults,
                    strategy: replacementStrategy
                )
            }
    }

    private var replacementSummaryLine: String {
        guard let currentBooking else {
            return "Ranked by provider quality, response speed, and value for this handover."
        }

        return conciergeReplacementStrategySupportingLine(
            strategy: replacementStrategy,
            currentBooking: currentBooking
        )
    }

    private var selectedReplacementImpactSummary: ConciergeReplacementImpactSummary? {
        guard focus == .replacement,
              let currentBooking,
              let selectedProvider else {
            return nil
        }

        let parsedEstimatedCost = Int(estimatedCostText.filter(\.isNumber))
        let safetySummary: ConciergeReplacementSafetySummary?
        if selectedProvider.id == currentBooking.provider.id {
            safetySummary = nil
        } else {
            safetySummary = conciergeReplacementSafetySummary(
                for: selectedProvider,
                currentBooking: currentBooking,
                listing: listing,
                score: conciergeReplacementRankingScore(
                    for: selectedProvider,
                    currentBooking: currentBooking,
                    listing: listing,
                    strategy: replacementStrategy
                ),
                strategy: replacementStrategy
            )
        }

        return conciergeReplacementImpactSummary(
            for: selectedProvider,
            currentBooking: currentBooking,
            listing: listing,
            scheduledFor: scheduledFor,
            notes: notes,
            estimatedCost: parsedEstimatedCost,
            safetySummary: safetySummary
        )
    }

    private var canLogFollowUpQuickAction: Bool {
        guard let currentBooking else {
            return false
        }

        return currentBooking.isCancelled == false &&
            currentBooking.isCompleted == false &&
            currentBooking.isProviderConfirmed == false &&
            (currentBooking.needsResponseFollowUp ||
             currentBooking.isResponseDueSoon ||
             currentBooking.followUpCountValue > 0)
    }

    private var canSnoozeQuickAction: Bool {
        guard let currentBooking else {
            return false
        }

        return currentBooking.isCancelled == false &&
            currentBooking.isCompleted == false &&
            currentBooking.isProviderConfirmed == false &&
            (currentBooking.needsResponseFollowUp ||
             currentBooking.isResponseDueSoon ||
             currentBooking.isReminderSnoozed)
    }

    private var shouldShowQuickActionCard: Bool {
        guard let currentBooking else {
            return false
        }

        return manualReviewContext != nil ||
            conciergeProviderCallURL(currentBooking.provider) != nil ||
            currentBooking.provider.websiteURL != nil ||
            currentBooking.provider.mapsURL != nil ||
            (canLogFollowUpQuickAction && onLogFollowUp != nil) ||
            (canSnoozeQuickAction && onSnoozeReminder != nil) ||
            (currentBooking.hasOpenIssue && onResolveIssue != nil) ||
            (currentBooking.isCancelled == false &&
             currentBooking.isCompleted == false &&
             currentBooking.hasOpenIssue == false &&
             onLogIssue != nil)
    }

    private func comparisonLabels(for provider: PostSaleConciergeProvider) -> [String] {
        var labels: [String] = []

        if provider.id == cheapestProvider?.id {
            labels.append("Best value")
        }

        if provider.id == topRatedProvider?.id {
            labels.append("Top rated")
        }

        if provider.id == fastestProvider?.id {
            labels.append("Fastest reply")
        }

        return labels
    }

    private func providerComparisonLabels(for provider: PostSaleConciergeProvider) -> [String] {
        comparisonLabels(for: provider)
    }

    private func performQuickAction(_ action: (() -> Void)?) {
        dismiss()

        guard let action else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
        }
    }

    @MainActor
    private func loadResults() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            results = try await store.searchPostSaleConciergeProviders(for: listing, serviceKind: serviceKind)
            if selectedProvider == nil {
                if let preferredProviderID,
                   results.contains(where: { $0.id == preferredProviderID }) {
                    selectedProviderID = preferredProviderID
                } else if focus == .replacement {
                    selectedProviderID = replacementSuggestions.first?.provider.id
                } else {
                    selectedProviderID = results.first?.id
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }

        isLoading = false
    }

    private static func defaultScheduleDate(for serviceKind: PostSaleConciergeServiceKind) -> Date {
        let calendar = Calendar.current
        let dayOffset: Int
        let hour: Int

        switch serviceKind {
        case .removalist:
            dayOffset = 2
            hour = 9
        case .cleaner:
            dayOffset = 1
            hour = 11
        case .utilitiesConnection:
            dayOffset = 1
            hour = 8
        case .keyHandover:
            dayOffset = 0
            hour = 15
        }

        let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) ?? baseDate
    }
}

private struct PostSaleConciergeResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: PostSaleConciergeResolutionMode
    let booking: PostSaleConciergeBooking
    let onSubmit: (PostSaleConciergeIssueKind?, String, Int?) -> Void

    @State private var note: String
    @State private var amountText: String
    @State private var selectedIssueKind: PostSaleConciergeIssueKind

    init(
        mode: PostSaleConciergeResolutionMode,
        booking: PostSaleConciergeBooking,
        onSubmit: @escaping (PostSaleConciergeIssueKind?, String, Int?) -> Void
    ) {
        self.mode = mode
        self.booking = booking
        self.onSubmit = onSubmit
        _note = State(initialValue: {
            switch mode {
            case .cancel:
                return booking.cancellationReason ?? ""
            case .refund:
                return booking.refundNote ?? booking.cancellationReason ?? ""
            case .logIssue:
                return booking.issueNote ?? ""
            case .resolveIssue:
                return booking.issueResolutionNote ?? booking.issueNote ?? ""
            }
        }())
        _amountText = State(initialValue: {
            switch mode {
            case .cancel:
                return ""
            case .refund:
                return String(booking.refundAmount ?? booking.paidAmount ?? booking.invoiceAmount ?? booking.estimatedCost ?? 0)
            case .logIssue, .resolveIssue:
                return ""
            }
        }())
        _selectedIssueKind = State(initialValue: booking.issueKind ?? .other)
    }

    private var parsedAmount: Int? {
        Int(amountText.filter(\.isNumber))
    }

    private var canSubmit: Bool {
        switch mode {
        case .cancel:
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .refund:
            return parsedAmount != nil
        case .logIssue:
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .resolveIssue:
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Booking") {
                    LabeledContent("Provider") {
                        Text(booking.provider.name)
                    }
                    LabeledContent("Service") {
                        Text(booking.serviceKind.title)
                    }
                    LabeledContent("Current status") {
                        Text(conciergeStatusText(for: booking))
                    }
                }

                switch mode {
                case .cancel:
                    Section("Cancellation reason") {
                        TextEditor(text: $note)
                            .frame(minHeight: 140)
                        Text("Explain why the booking was cancelled so the settled archive keeps a clear service history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .refund:
                    Section("Refund details") {
                        TextField("Refund amount", text: $amountText)
                            .keyboardType(.numberPad)
                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                        Text("Use this to save the refunded amount and a short note, such as provider cancellation or billing correction.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .logIssue:
                    Section("Issue type") {
                        Picker("Issue type", selection: $selectedIssueKind) {
                            ForEach(PostSaleConciergeIssueKind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Section("Issue details") {
                        TextEditor(text: $note)
                            .frame(minHeight: 140)
                        Text("Capture what went wrong so the archive keeps a clear provider issue trail before you move into cancellation or refund handling.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .resolveIssue:
                    Section("Resolution") {
                        if let issueKind = booking.issueKind {
                            LabeledContent("Issue") {
                                Text(issueKind.title)
                            }
                        }
                        TextEditor(text: $note)
                            .frame(minHeight: 140)
                        Text("Save how the provider issue was resolved so the settled archive keeps the full follow-up history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle) {
                        onSubmit(mode == .logIssue ? selectedIssueKind : nil, note, mode == .refund ? parsedAmount : nil)
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var submitTitle: String {
        switch mode {
        case .cancel:
            return "Save cancellation"
        case .refund:
            return "Save refund"
        case .logIssue:
            return "Save issue"
        case .resolveIssue:
            return "Save resolution"
        }
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
    @State private var errorMessage: String?
    let onCreate: (ListingDraft) throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

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
                        do {
                            try onCreate(draft)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(!draft.canSubmit)
                }
            }
        }
    }
}

private struct RepriceListingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let listing: PropertyListing
    let onSave: (Int, String) throws -> Void

    @State private var newPriceText: String
    @State private var note = ""
    @State private var errorMessage: String?

    init(
        listing: PropertyListing,
        onSave: @escaping (Int, String) throws -> Void
    ) {
        self.listing = listing
        self.onSave = onSave
        _newPriceText = State(initialValue: String(listing.askingPrice))
    }

    private var parsedPrice: Int? {
        Int(newPriceText.filter(\.isNumber))
    }

    private var canSubmit: Bool {
        guard let parsedPrice else { return false }
        return parsedPrice > 0 && parsedPrice != listing.askingPrice
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Current position") {
                    LabeledContent("Listing") {
                        Text(listing.title)
                    }
                    LabeledContent("Current asking price") {
                        Text(currencyString(listing.askingPrice))
                            .font(.headline.weight(.bold))
                    }
                    LabeledContent("Value range") {
                        Text("\(currencyString(listing.marketPulse.valueEstimateLow)) - \(currencyString(listing.marketPulse.valueEstimateHigh))")
                    }
                    LabeledContent("Suburb median") {
                        Text(currencyString(listing.marketPulse.suburbMedian))
                    }
                }

                Section("Quick pricing moves") {
                    AdaptiveTagGrid(minimum: 140) {
                        quickPriceButton(title: "Guide low", amount: listing.marketPulse.valueEstimateLow)
                        quickPriceButton(title: "Suburb median", amount: listing.marketPulse.suburbMedian)
                        quickPriceButton(title: "Guide high", amount: listing.marketPulse.valueEstimateHigh)
                    }
                }

                Section("Update asking price") {
                    TextField("New asking price", text: $newPriceText)
                        .keyboardType(.numberPad)
                    TextField("Optional note for buyers", text: $note, axis: .vertical)
                    Text("Any active buyer conversation will receive this price update automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !listing.priceJourney.isEmpty {
                    Section("Recent price history") {
                        ForEach(Array(listing.priceJourney.prefix(3))) { event in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currencyString(event.amount))
                                        .font(.subheadline.weight(.semibold))
                                    Text(event.note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 12)

                                Text(shortDateString(event.recordedAt))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Update Price")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let parsedPrice else {
                            errorMessage = "Enter a valid asking price before saving."
                            return
                        }

                        do {
                            try onSave(parsedPrice, note)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private func quickPriceButton(title: String, amount: Int) -> some View {
        Button {
            newPriceText = String(amount)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(currencyString(amount))
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandPalette.panel)
            )
        }
        .buttonStyle(.plain)
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
                .fill(BrandPalette.card)
        )
    }
}

private struct PostSaleConciergeProviderCard: View {
    let provider: PostSaleConciergeProvider
    let comparisonLabels: [String]
    let isSelected: Bool
    let actionTitle: String
    let statusLine: String
    let safetySummary: ConciergeReplacementSafetySummary?
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(provider.name)
                        .font(.headline)
                    Text(provider.primarySpecialty)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandPalette.teal)
                    Text(provider.address)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let rating = provider.rating {
                        Text(rating.formatted(.number.precision(.fractionLength(1))))
                            .font(.headline.weight(.bold))
                        Text(provider.reviewCount.map { "\($0) reviews" } ?? "Local listing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AdaptiveTagGrid(minimum: 140) {
                if let priceGuide = conciergeProviderPriceGuide(provider) {
                    InfoPill(label: priceGuide)
                }
                if let responseLine = conciergeProviderResponseLine(provider) {
                    InfoPill(label: responseLine)
                }
                ForEach(comparisonLabels, id: \.self) { label in
                    InfoPill(label: label)
                }
                ForEach(provider.specialties, id: \.self) { specialty in
                    InfoPill(label: specialty)
                }
                InfoPill(label: provider.sourceLine)
            }

            if let safetySummary {
                ConciergeReplacementSafetyPanel(summary: safetySummary)
            }

            Text(provider.searchSummary)
                .foregroundStyle(.secondary)

            if let phoneNumber = provider.phoneNumber {
                Label(phoneNumber, systemImage: "phone.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if isSelected {
                    Button(actionTitle) {}
                        .buttonStyle(.bordered)
                        .disabled(true)
                } else {
                    Button(actionTitle) {
                        onSelect()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let callURL = conciergeProviderCallURL(provider) {
                    Link("Call", destination: callURL)
                        .buttonStyle(.bordered)
                }

                if let websiteURL = provider.websiteURL {
                    Link("Website", destination: websiteURL)
                        .buttonStyle(.bordered)
                }

                if let mapsURL = provider.mapsURL {
                    Link("Maps", destination: mapsURL)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
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

                Text(priceJourneyHeadline(for: listing))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(priceMovementTint(for: listing))

                Text(listing.primaryFactLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let seller {
                    Text("Private seller: \(seller.name) • \(trustSummaryLine(for: seller))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    AdaptiveTagGrid(minimum: 120) {
                        ForEach(Array(seller.highlightedVerificationChecks.prefix(2))) { check in
                            VerificationPill(check: check)
                        }
                    }
                }

                Text(listing.headline)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                AdaptiveTagGrid(minimum: 120) {
                    InfoPill(label: listing.propertyType.title)
                    InfoPill(label: "Demand \(listing.marketPulse.buyerDemandScore)")
                    InfoPill(label: listing.marketPulse.schoolInsight.catchmentName)
                    InfoPill(label: priceJourneyPillLabel(for: listing))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.card)
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
                    Text(trustSummaryLine(for: seller))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandPalette.teal)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 320, alignment: .leading)
    }
}

private struct SellerOfferComparisonCard: View {
    let rank: Int
    let entry: SellerOfferBoardEntry
    let canAccept: Bool
    let onSetRelationshipStatus: (SellerBuyerRelationshipStatus) -> Void
    let onAccept: () -> Void
    let onCounter: () -> Void
    let onRequestChanges: () -> Void
    let onOpenListing: () -> Void
    let onOpenThread: () -> Void

    private var offerGapLabel: String {
        let delta = entry.offer.amount - entry.listing.askingPrice
        if delta == 0 {
            return "On asking"
        }
        if delta > 0 {
            return "\(currencyString(delta)) above ask"
        }
        return "\(currencyString(abs(delta))) below ask"
    }

    private var legalSummary: String {
        let selectedCount = [entry.offer.buyerLegalSelection, entry.offer.sellerLegalSelection]
            .compactMap { $0 }
            .count
        if let packet = entry.offer.contractPacket {
            return packet.isFullySigned ? "Contract signed" : "Contract issued"
        }
        return "\(selectedCount)/2 legal reps selected"
    }

    private var checklistSummary: String {
        let completed = entry.offer.settlementChecklist.filter { $0.status == .completed }.count
        return "\(completed)/\(entry.offer.settlementChecklist.count) milestones complete"
    }

    private var actionsLocked: Bool {
        entry.offer.contractPacket?.isFullySigned == true || entry.offer.status == .accepted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("#\(rank) \(entry.priority.label)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(entry.priority.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(entry.priority.background)
                            )

                        Text(entry.offer.sellerRelationshipStatus.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(
                                sellerRelationshipTint(for: entry.offer.sellerRelationshipStatus)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        sellerRelationshipBackground(for: entry.offer.sellerRelationshipStatus)
                                    )
                            )
                    }
                    Text(entry.buyer.name)
                        .font(.headline)
                    Text(entry.listing.title)
                        .font(.subheadline.weight(.semibold))
                    Text(entry.listing.address.fullLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyString(entry.offer.amount))
                        .font(.title3.weight(.bold))
                    Text(offerGapLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(priceDeltaTint(for: entry.offer, askingPrice: entry.listing.askingPrice))
                    Text("Updated \(relativeDateString(entry.offer.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: entry.offer.status.title)
                InfoPill(label: entry.buyer.hasVerifiedCheck(.finance) ? "Finance ready" : "Finance pending")
                InfoPill(label: legalSummary)
                InfoPill(label: checklistSummary)
            }

            Text(entry.priority.detail)
                .foregroundStyle(.secondary)

            Text("Buyer trust: \(trustSummaryLine(for: entry.buyer))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandPalette.teal)

            Menu {
                ForEach(SellerBuyerRelationshipStatus.allCases) { status in
                    Button(status.title) {
                        onSetRelationshipStatus(status)
                    }
                }
            } label: {
                Label("Buyer status", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(.bordered)

            if !canAccept && !actionsLocked {
                Text("Another accepted buyer is already active on this listing. Keep this buyer warm here while the live deal progresses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .disabled(actionsLocked || !canAccept)

                Button("Counter") {
                    onCounter()
                }
                .buttonStyle(.bordered)
                .disabled(actionsLocked)

                Button("Request changes") {
                    onRequestChanges()
                }
                .buttonStyle(.bordered)
                .disabled(actionsLocked)
            }

            HStack(spacing: 10) {
                Button("Open secure thread") {
                    onOpenThread()
                }
                .buttonStyle(.bordered)

                Button("Open listing") {
                    onOpenListing()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
    }
}

private struct BuyerOfferQueueCard: View {
    let rank: Int
    let entry: BuyerTransactionEntry
    let onRespond: () -> Void
    let onOpenThread: () -> Void
    let onOpenListing: () -> Void

    private var offerGapLabel: String {
        let delta = entry.offer.amount - entry.listing.askingPrice
        if delta == 0 {
            return "On asking"
        }
        if delta > 0 {
            return "\(currencyString(delta)) above ask"
        }
        return "\(currencyString(abs(delta))) below ask"
    }

    private var legalSummary: String {
        let selectedCount = [entry.offer.buyerLegalSelection, entry.offer.sellerLegalSelection]
            .compactMap { $0 }
            .count
        if let packet = entry.offer.contractPacket {
            return packet.isFullySigned ? "Contract signed" : "Contract issued"
        }
        return "\(selectedCount)/2 legal reps selected"
    }

    private var responseButtonTitle: String {
        switch entry.offer.status {
        case .countered:
            return "Respond to counter"
        case .changesRequested:
            return "Send updated terms"
        case .accepted:
            return "Open deal"
        case .underOffer:
            return "Update offer"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("#\(rank) \(entry.priority.label)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(entry.priority.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(entry.priority.background)
                            )

                        Text(entry.offer.status.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(entry.priority.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(entry.priority.background.opacity(0.85))
                            )
                    }

                    Text(entry.listing.title)
                        .font(.headline)
                    Text(entry.listing.address.fullLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Private seller: \(entry.seller.name)")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyString(entry.offer.amount))
                        .font(.title3.weight(.bold))
                    Text(offerGapLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(priceDeltaTint(for: entry.offer, askingPrice: entry.listing.askingPrice))
                    Text("Updated \(relativeDateString(entry.offer.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: entry.seller.hasVerifiedCheck(.ownership) ? "Ownership checked" : "Ownership pending")
                InfoPill(label: entry.offer.buyerLegalSelection != nil ? "Buyer legal rep chosen" : "Buyer legal rep pending")
                InfoPill(label: legalSummary)
            }

            Text(entry.priority.detail)
                .foregroundStyle(.secondary)

            Text("Seller trust: \(trustSummaryLine(for: entry.seller))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandPalette.teal)

            HStack(spacing: 10) {
                Button(responseButtonTitle) {
                    onRespond()
                }
                .buttonStyle(.borderedProminent)

                Button("Open secure thread") {
                    onOpenThread()
                }
                .buttonStyle(.bordered)

                Button("Open listing") {
                    onOpenListing()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
    }
}

private struct BuyerDealExecutionCard: View {
    let entry: BuyerTransactionEntry
    let nextItem: SaleChecklistItem?
    let nextSnapshot: SaleTaskLiveSnapshot?
    let blockingSummary: String?
    let keyDocuments: [SaleDocument]
    let primaryActionTitle: String?
    let primaryActionSupporting: String?
    let onPrimaryAction: (() -> Void)?
    let onOpenDocument: (SaleDocument) -> Void
    let onOpenListing: () -> Void
    let onOpenThread: () -> Void

    private var signatureSummary: String {
        let signatureCount = [entry.offer.contractPacket?.buyerSignedAt, entry.offer.contractPacket?.sellerSignedAt]
            .compactMap { $0 }
            .count
        return "\(signatureCount)/2 signed"
    }

    private var legalSummary: String {
        entry.offer.isLegallyCoordinated ? "Both legal reps selected" : "Legal selection still pending"
    }

    private var stageTitle: String {
        if entry.offer.settlementCompletedAt != nil {
            return "Settlement complete"
        }
        if entry.offer.contractPacket?.isFullySigned == true {
            return "Signed and settling"
        }
        if entry.offer.contractPacket != nil {
            return "Contract in progress"
        }
        return "Accepted and moving to legal handoff"
    }

    private var completedMilestoneCount: Int {
        entry.offer.settlementChecklist.filter { $0.status == .completed }.count
    }

    private var milestoneCount: Int {
        entry.offer.settlementChecklist.count
    }

    private var milestoneProgress: Double {
        guard milestoneCount > 0 else { return 0 }
        return Double(completedMilestoneCount) / Double(milestoneCount)
    }

    private var settlementSummary: String {
        if entry.offer.settlementCompletedAt != nil {
            return "Settled"
        }

        if keyDocuments.contains(where: { $0.kind == .settlementStatementPDF }) {
            return "Statement ready"
        }

        return "Statement pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stageTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandPalette.teal.opacity(0.14))
                        )
                    Text(entry.listing.title)
                        .font(.headline)
                    Text("Seller: \(entry.seller.name)")
                        .font(.subheadline.weight(.semibold))
                    Text(entry.listing.address.fullLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(currencyString(entry.offer.amount))
                        .font(.title3.weight(.bold))
                    Text(signatureSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(legalSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: entry.priority.label)
                InfoPill(label: entry.seller.hasVerifiedCheck(.ownership) ? "Seller ownership checked" : "Seller ownership pending")
                InfoPill(label: settlementSummary)
                InfoPill(label: "\(completedMilestoneCount)/\(milestoneCount) milestones done")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Settlement progress")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(Int((milestoneProgress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: milestoneProgress)
                    .tint(BrandPalette.teal)
            }

            if let nextItem {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next milestone")
                        .font(.subheadline.weight(.semibold))
                    Text(nextItem.title)
                        .font(.subheadline.weight(.semibold))
                    Text(nextItem.nextAction ?? nextItem.detail)
                        .foregroundStyle(.secondary)
                    if let nextSnapshot {
                        Text(nextSnapshot.summary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: nextSnapshot.tone))
                    }
                    if let blockingSummary {
                        Text(blockingSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let targetSummary = nextItem.targetSummary {
                        Text(targetSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(nextItem.isOverdue ? .orange : .secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.panel)
                )
            }

            if !keyDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key documents")
                        .font(.subheadline.weight(.semibold))

                    AdaptiveTagGrid(minimum: 150) {
                        ForEach(keyDocuments) { document in
                            Button {
                                onOpenDocument(document)
                            } label: {
                                Label(documentButtonLabel(for: document), systemImage: document.kind.symbolName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if let primaryActionTitle, let onPrimaryAction {
                VStack(alignment: .leading, spacing: 10) {
                    if let primaryActionSupporting {
                        Text(primaryActionSupporting)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button(primaryActionTitle) {
                            onPrimaryAction()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open secure thread") {
                            onOpenThread()
                        }
                        .buttonStyle(.bordered)

                        Button("Open listing") {
                            onOpenListing()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button("Open secure thread") {
                        onOpenThread()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open listing") {
                        onOpenListing()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private func color(for tone: SaleTaskLiveSnapshotTone) -> Color {
        switch tone {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .critical:
            return .red
        case .success:
            return BrandPalette.teal
        }
    }

    private func documentButtonLabel(for document: SaleDocument) -> String {
        switch document.kind {
        case .settlementStatementPDF:
            return "Open settlement statement"
        case .settlementSummaryPDF:
            return "Open settlement summary"
        case .handoverChecklistPDF:
            return "Open handover checklist"
        case .signedContractPDF:
            return "Open signed contract"
        case .reviewedContractPDF:
            return "Open reviewed contract"
        case .settlementAdjustmentPDF:
            return "Open settlement adjustment"
        case .contractPacketPDF:
            return "Open contract packet"
        case .councilRatesNoticePDF:
            return "Open rates notice"
        case .identityCheckPackPDF:
            return "Open identity pack"
        case .buyerFinanceProofPDF:
            return "Open finance proof"
        case .sellerOwnershipEvidencePDF:
            return "Open ownership proof"
        }
    }
}

private struct DealArchiveCard: View {
    let title: String
    let subtitle: String
    let counterpartLabel: String
    let counterpartName: String
    let settlementDate: Date?
    let amount: Int
    let documents: [SaleDocument]
    let serviceRows: [ArchiveServiceRow]
    let conciergeRows: [ArchiveConciergeRow]
    let feedbackRows: [ArchiveFeedbackRow]
    let feedbackActionTitle: String
    let onCompleteServiceTask: (PostSaleServiceTaskKind) -> Void
    let onManageConciergeService: (PostSaleConciergeServiceKind) -> Void
    let onOpenConciergeQuote: (PostSaleConciergeServiceKind) -> Void
    let onApproveConciergeQuote: (PostSaleConciergeServiceKind) -> Void
    let onUploadConciergeInvoice: (PostSaleConciergeServiceKind) -> Void
    let onOpenConciergeInvoice: (PostSaleConciergeServiceKind) -> Void
    let onUploadConciergePaymentProof: (PostSaleConciergeServiceKind) -> Void
    let onOpenConciergePaymentProof: (PostSaleConciergeServiceKind) -> Void
    let onCancelConciergeService: (PostSaleConciergeServiceKind) -> Void
    let onRecordConciergeRefund: (PostSaleConciergeServiceKind) -> Void
    let onLogConciergeIssue: (PostSaleConciergeServiceKind) -> Void
    let onResolveConciergeIssue: (PostSaleConciergeServiceKind) -> Void
    let onLogConciergeFollowUp: (PostSaleConciergeServiceKind) -> Void
    let onSnoozeConciergeReminder: (PostSaleConciergeServiceKind) -> Void
    let onConfirmConciergeProvider: (PostSaleConciergeServiceKind) -> Void
    let onExportConciergeReceipt: (PostSaleConciergeServiceKind) -> Void
    let onOpenConciergeConfirmation: (PostSaleConciergeServiceKind) -> Void
    let onCompleteConciergeService: (PostSaleConciergeServiceKind) -> Void
    let onLeaveFeedback: () -> Void
    let onOpenDocument: (SaleDocument) -> Void
    let onOpenThread: () -> Void
    let onOpenListing: () -> Void
    let onShareArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Archive ready")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandPalette.teal.opacity(0.14))
                        )
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(counterpartLabel): \(counterpartName)")
                        .font(.subheadline.weight(.semibold))

                    if let conciergeSpendSummary,
                       conciergeSpendSummary.followUpDueCount > 0 || conciergeSpendSummary.dueSoonCount > 0 {
                        HStack(spacing: 8) {
                            if conciergeSpendSummary.followUpDueCount > 0 {
                                archiveUrgencyBadge(
                                    label: conciergeSpendSummary.followUpDueCount == 1
                                        ? "Urgent provider follow-up"
                                        : "\(conciergeSpendSummary.followUpDueCount) urgent follow-ups",
                                    tint: .orange
                                )
                            }

                            if conciergeSpendSummary.dueSoonCount > 0 {
                                archiveUrgencyBadge(
                                    label: conciergeSpendSummary.dueSoonCount == 1
                                        ? "1 due soon"
                                        : "\(conciergeSpendSummary.dueSoonCount) due soon",
                                    tint: BrandPalette.gold
                                )
                            }
                        }
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(currencyString(amount))
                        .font(.title3.weight(.bold))
                    Text(settlementDate.map { "Settled \(shortDateString($0))" } ?? "Settlement complete")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(documents.count) archive docs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HighlightInformationCard(
                title: "Closeout pack",
                message: "The final handover record, signed contract, settlement paperwork, and archive summary stay together here after the sale is fully closed.",
                supporting: "Preview any document below or export the complete pack in one tap."
            )

            if !documents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Archive documents")
                        .font(.subheadline.weight(.semibold))

                    AdaptiveTagGrid(minimum: 150) {
                        ForEach(documents) { document in
                            Button {
                                onOpenDocument(document)
                            } label: {
                                Label(archiveDocumentLabel(for: document), systemImage: document.kind.symbolName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if !serviceRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Post-sale follow-through")
                        .font(.subheadline.weight(.semibold))

                    ForEach(serviceRows) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: row.kind.symbolName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(row.isCompleted ? BrandPalette.teal : BrandPalette.gold)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            if row.isCompleted {
                                Text("Done")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandPalette.teal)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(BrandPalette.teal.opacity(0.12))
                                    )
                            } else {
                                Button("Mark done") {
                                    onCompleteServiceTask(row.kind)
                                }
                                .buttonStyle(.bordered)
                            }
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

            if let conciergeSpendSummary {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Concierge spend tracker")
                        .font(.subheadline.weight(.semibold))

                    AdaptiveTagGrid(minimum: 150) {
                        MiniStatPanel(
                            title: "Services booked",
                            value: "\(conciergeSpendSummary.bookedCount)",
                            subtitle: "\(conciergeSpendSummary.completedCount) completed • \(conciergeSpendSummary.refundedCount) refunded"
                        )

                        if let quotedTotal = conciergeSpendSummary.quotedTotal {
                            MiniStatPanel(
                                title: "Quoted total",
                                value: currencyString(quotedTotal),
                                subtitle: "Planner view across concierge bookings"
                            )
                        }

                        if let invoicedTotal = conciergeSpendSummary.invoicedTotal {
                            MiniStatPanel(
                                title: "Invoiced total",
                                value: currencyString(invoicedTotal),
                                subtitle: "Final receipts saved in the archive"
                            )
                        }

                        if let paidTotal = conciergeSpendSummary.paidTotal {
                            MiniStatPanel(
                                title: "Paid total",
                                value: currencyString(paidTotal),
                                subtitle: "Payment proof saved in the archive"
                            )
                        }

                        if let refundedTotal = conciergeSpendSummary.refundedTotal {
                            MiniStatPanel(
                                title: "Refunded total",
                                value: currencyString(refundedTotal),
                                subtitle: "Refund records saved in the archive"
                            )
                        }

                        if conciergeSpendSummary.openIssueCount > 0 {
                            MiniStatPanel(
                                title: "Issues open",
                                value: "\(conciergeSpendSummary.openIssueCount)",
                                subtitle: "Provider follow-up still active"
                            )
                        }

                        if conciergeSpendSummary.followUpDueCount > 0 {
                            MiniStatPanel(
                                title: "Follow-up due",
                                value: "\(conciergeSpendSummary.followUpDueCount)",
                                subtitle: "Provider reply windows need attention"
                            )
                        }

                        if conciergeSpendSummary.dueSoonCount > 0 {
                            MiniStatPanel(
                                title: "Due soon",
                                value: "\(conciergeSpendSummary.dueSoonCount)",
                                subtitle: "Provider reply windows surfacing early"
                            )
                        }

                        if conciergeSpendSummary.snoozedCount > 0 {
                            MiniStatPanel(
                                title: "Snoozed",
                                value: "\(conciergeSpendSummary.snoozedCount)",
                                subtitle: "Reminder windows paused for later"
                            )
                        }

                        if conciergeSpendSummary.providerHistoryCount > 0 {
                            MiniStatPanel(
                                title: "Past providers",
                                value: "\(conciergeSpendSummary.providerHistoryCount)",
                                subtitle: "Provider replacements kept on file"
                            )
                        }
                    }

                    if let varianceMessage = conciergeSpendSummary.varianceMessage {
                        Text(varianceMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if conciergeSpendSummary.approvedCount > 0 || conciergeSpendSummary.invoicedCount > 0 {
                        Text("\(conciergeSpendSummary.approvedCount) quote approvals and \(conciergeSpendSummary.invoicedCount) invoice records are attached to this settled deal.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !conciergeRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Moving concierge")
                        .font(.subheadline.weight(.semibold))

                    ForEach(conciergeRows) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: row.kind.symbolName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(
                                    row.needsFollowUp ? .orange :
                                        (row.hasOpenIssue ? .orange :
                                        (row.isRefunded ? BrandPalette.teal :
                                        (row.isCancelled ? .orange :
                                            (row.isCompleted ? BrandPalette.teal : BrandPalette.gold))
                                        ))
                                )
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if row.providerHistoryCount > 0,
                                   let latestProviderAuditSummary = row.latestProviderAuditSummary {
                                    Text(latestProviderAuditSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 12)

                            VStack(alignment: .trailing, spacing: 8) {
                                Text(row.statusText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(
                                        row.needsFollowUp ? .orange :
                                            (row.hasOpenIssue ? .orange :
                                                (row.isReminderSnoozed ? BrandPalette.gold :
                                                    (row.isCancelled ? .orange :
                                                        (row.isCompleted || row.hasResolvedIssue || row.isProviderConfirmed ? BrandPalette.teal : .secondary)
                                                    )
                                                )
                                            )
                                    )

                                if row.canMarkDone {
                                    Button(row.actionTitle) {
                                        onManageConciergeService(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                } else if row.isCompleted || row.isCancelled {
                                    Button(row.actionTitle) {
                                        onManageConciergeService(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button(row.actionTitle) {
                                        onManageConciergeService(row.kind)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                if row.hasQuoteDocument {
                                    Button("Open quote") {
                                        onOpenConciergeQuote(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canApproveQuote {
                                    Button("Approve quote") {
                                        onApproveConciergeQuote(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.hasInvoiceDocument {
                                    Button("Open invoice") {
                                        onOpenConciergeInvoice(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                } else if row.canUploadInvoice {
                                    Button("Upload invoice") {
                                        onUploadConciergeInvoice(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.hasPaymentProofDocument {
                                    Button("Open payment proof") {
                                        onOpenConciergePaymentProof(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                } else if row.canUploadPaymentProof {
                                    Button("Upload payment proof") {
                                        onUploadConciergePaymentProof(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canCancel {
                                    Button("Cancel booking") {
                                        onCancelConciergeService(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canRecordRefund {
                                    Button("Record refund") {
                                        onRecordConciergeRefund(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canLogIssue {
                                    Button("Log issue") {
                                        onLogConciergeIssue(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canResolveIssue {
                                    Button("Resolve issue") {
                                        onResolveConciergeIssue(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canLogFollowUp {
                                    Button("Log follow-up") {
                                        onLogConciergeFollowUp(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canSnoozeReminder {
                                    Button("Snooze 24h") {
                                        onSnoozeConciergeReminder(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canConfirmProvider {
                                    Button("Mark confirmed") {
                                        onConfirmConciergeProvider(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.isBooked {
                                    Button("Export receipt") {
                                        onExportConciergeReceipt(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.hasConfirmationDocument {
                                    Button("Open proof") {
                                        onOpenConciergeConfirmation(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if row.canMarkDone {
                                    Button("Mark done") {
                                        onCompleteConciergeService(row.kind)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
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

            if !feedbackRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Feedback")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 12)
                        Button(feedbackActionTitle) {
                            onLeaveFeedback()
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(feedbackRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 12)
                                Text(row.isSubmitted ? "Saved" : "Pending")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(row.isSubmitted ? BrandPalette.teal : .secondary)
                            }
                            Text(row.detail)
                                .font(.footnote)
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

            HStack(spacing: 10) {
                Button("Export closeout pack") {
                    onShareArchive()
                }
                .buttonStyle(.borderedProminent)

                Button("Open secure thread") {
                    onOpenThread()
                }
                .buttonStyle(.bordered)

                Button("Open listing") {
                    onOpenListing()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    @ViewBuilder
    private func archiveUrgencyBadge(label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }

    private func archiveDocumentLabel(for document: SaleDocument) -> String {
        switch document.kind {
        case .settlementSummaryPDF:
            return "Open settlement summary"
        case .handoverChecklistPDF:
            return "Open handover checklist"
        case .settlementStatementPDF:
            return "Open settlement statement"
        case .signedContractPDF:
            return "Open signed contract"
        case .reviewedContractPDF:
            return "Open reviewed contract"
        case .settlementAdjustmentPDF:
            return "Open settlement adjustment"
        case .contractPacketPDF:
            return "Open contract packet"
        case .councilRatesNoticePDF:
            return "Open rates notice"
        case .identityCheckPackPDF:
            return "Open identity pack"
        case .buyerFinanceProofPDF:
            return "Open finance proof"
        case .sellerOwnershipEvidencePDF:
            return "Open ownership proof"
        }
    }

    private var conciergeSpendSummary: ArchiveConciergeSpendSummary? {
        let bookedRows = conciergeRows.filter(\.isBooked)
        guard !bookedRows.isEmpty else {
            return nil
        }

        let quotedValues = bookedRows.compactMap(\.estimatedCost)
        let invoicedValues = bookedRows.compactMap(\.invoiceAmount)
        let paidValues = bookedRows.compactMap(\.paidAmount)
        let refundedValues = bookedRows.compactMap(\.refundAmount)

        return ArchiveConciergeSpendSummary(
            bookedCount: bookedRows.count,
            completedCount: bookedRows.filter(\.isCompleted).count,
            invoicedCount: bookedRows.filter { $0.invoiceAmount != nil || $0.hasInvoiceDocument }.count,
            approvedCount: bookedRows.filter(\.isQuoteApproved).count,
            paidCount: bookedRows.filter(\.isPaid).count,
            refundedCount: bookedRows.filter(\.isRefunded).count,
            openIssueCount: bookedRows.filter(\.hasOpenIssue).count,
            followUpDueCount: bookedRows.filter(\.needsFollowUp).count,
            dueSoonCount: bookedRows.filter(\.isResponseDueSoon).count,
            snoozedCount: bookedRows.filter(\.isReminderSnoozed).count,
            providerHistoryCount: bookedRows.map(\.providerHistoryCount).reduce(0, +),
            quotedTotal: quotedValues.isEmpty ? nil : quotedValues.reduce(0, +),
            invoicedTotal: invoicedValues.isEmpty ? nil : invoicedValues.reduce(0, +),
            paidTotal: paidValues.isEmpty ? nil : paidValues.reduce(0, +),
            refundedTotal: refundedValues.isEmpty ? nil : refundedValues.reduce(0, +)
        )
    }
}

private struct ConciergeReminderEscalationCard: View {
    let title: String
    let dashboard: ConciergeReminderDashboard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            HStack(spacing: 10) {
                if dashboard.overdueCount > 0 {
                    archiveUrgencyBadge(
                        label: dashboard.overdueCount == 1 ? "1 urgent follow-up" : "\(dashboard.overdueCount) urgent follow-ups",
                        tint: .orange
                    )
                }

                if dashboard.surfacedDueSoonCount > 0 {
                    archiveUrgencyBadge(
                        label: dashboard.surfacedDueSoonCount == 1
                            ? "1 due soon"
                            : "\(dashboard.surfacedDueSoonCount) due soon",
                        tint: BrandPalette.gold
                    )
                }
            }

            Text(dashboard.headline)
                .font(.subheadline.weight(.semibold))

            Text(dashboard.supportingLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }

    @ViewBuilder
    private func archiveUrgencyBadge(label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }
}

private struct PostSaleFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let listingTitle: String
    let counterpartName: String
    let existingEntry: PostSaleFeedbackEntry?
    let onSubmit: (Int, String) -> Void

    @State private var rating: Int
    @State private var notes: String

    init(
        title: String,
        listingTitle: String,
        counterpartName: String,
        existingEntry: PostSaleFeedbackEntry?,
        onSubmit: @escaping (Int, String) -> Void
    ) {
        self.title = title
        self.listingTitle = listingTitle
        self.counterpartName = counterpartName
        self.existingEntry = existingEntry
        self.onSubmit = onSubmit
        _rating = State(initialValue: existingEntry?.rating ?? 5)
        _notes = State(initialValue: existingEntry?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sale") {
                    Text(listingTitle)
                    Text("Counterpart: \(counterpartName)")
                        .foregroundStyle(.secondary)
                }

                Section("Rating") {
                    Picker("Rating", selection: $rating) {
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value) star\(value == 1 ? "" : "s")").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 140)
                    Text("Save a short note about how the private-sale transaction went so it stays attached to the settlement archive.")
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
                    Button(existingEntry == nil ? "Save" : "Update") {
                        onSubmit(rating, notes)
                        dismiss()
                    }
                    .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ActiveDealExecutionCard: View {
    let entry: SellerOfferBoardEntry
    let nextItem: SaleChecklistItem?
    let nextSnapshot: SaleTaskLiveSnapshot?
    let blockingSummary: String?
    let keyDocuments: [SaleDocument]
    let primaryActionTitle: String?
    let primaryActionSupporting: String?
    let onPrimaryAction: (() -> Void)?
    let onOpenDocument: (SaleDocument) -> Void
    let onOpenListing: () -> Void
    let onOpenThread: () -> Void

    private var signatureSummary: String {
        let signatureCount = [entry.offer.contractPacket?.buyerSignedAt, entry.offer.contractPacket?.sellerSignedAt]
            .compactMap { $0 }
            .count
        return "\(signatureCount)/2 signed"
    }

    private var legalSummary: String {
        entry.offer.isLegallyCoordinated ? "Both legal reps selected" : "Legal selection still pending"
    }

    private var stageTitle: String {
        if entry.offer.settlementCompletedAt != nil {
            return "Settlement complete"
        }
        if entry.offer.contractPacket?.isFullySigned == true {
            return "Sale complete"
        }
        if entry.offer.contractPacket != nil {
            return "Contract in progress"
        }
        return "Accepted and moving to legal handoff"
    }

    private var completedMilestoneCount: Int {
        entry.offer.settlementChecklist.filter { $0.status == .completed }.count
    }

    private var milestoneCount: Int {
        entry.offer.settlementChecklist.count
    }

    private var milestoneProgress: Double {
        guard milestoneCount > 0 else { return 0 }
        return Double(completedMilestoneCount) / Double(milestoneCount)
    }

    private var settlementSummary: String {
        if entry.offer.settlementCompletedAt != nil {
            return "Settled"
        }

        if keyDocuments.contains(where: { $0.kind == .settlementStatementPDF }) {
            return "Statement ready"
        }

        return "Statement pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stageTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandPalette.teal.opacity(0.14))
                        )
                    Text(entry.listing.title)
                        .font(.headline)
                    Text("Buyer: \(entry.buyer.name)")
                        .font(.subheadline.weight(.semibold))
                    Text(entry.listing.address.fullLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(currencyString(entry.offer.amount))
                        .font(.title3.weight(.bold))
                    Text(signatureSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(legalSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: entry.offer.sellerRelationshipStatus.title)
                InfoPill(label: entry.buyer.hasVerifiedCheck(.finance) ? "Finance ready" : "Finance pending")
                InfoPill(label: settlementSummary)
                InfoPill(label: "\(completedMilestoneCount)/\(milestoneCount) milestones done")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Settlement progress")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(Int((milestoneProgress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: milestoneProgress)
                    .tint(BrandPalette.teal)
            }

            if let nextItem {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next milestone")
                        .font(.subheadline.weight(.semibold))
                    Text(nextItem.title)
                        .font(.subheadline.weight(.semibold))
                    Text(nextItem.nextAction ?? nextItem.detail)
                        .foregroundStyle(.secondary)
                    if let nextSnapshot {
                        Text(nextSnapshot.summary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: nextSnapshot.tone))
                    }
                    if let blockingSummary {
                        Text(blockingSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let targetSummary = nextItem.targetSummary {
                        Text(targetSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(nextItem.isOverdue ? .orange : .secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.panel)
                )
            }

            if !keyDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key documents")
                        .font(.subheadline.weight(.semibold))

                    AdaptiveTagGrid(minimum: 150) {
                        ForEach(keyDocuments) { document in
                            Button {
                                onOpenDocument(document)
                            } label: {
                                Label(shortDocumentLabel(for: document), systemImage: document.kind.symbolName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if let primaryActionTitle, let onPrimaryAction {
                VStack(alignment: .leading, spacing: 10) {
                    if let primaryActionSupporting {
                        Text(primaryActionSupporting)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button(primaryActionTitle) {
                            onPrimaryAction()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open secure thread") {
                            onOpenThread()
                        }
                        .buttonStyle(.bordered)

                        Button("Open listing") {
                            onOpenListing()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button("Open secure thread") {
                        onOpenThread()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open listing") {
                        onOpenListing()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
    }

    private func color(for tone: SaleTaskLiveSnapshotTone) -> Color {
        switch tone {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .critical:
            return .red
        case .success:
            return BrandPalette.teal
        }
    }

    private func shortDocumentLabel(for document: SaleDocument) -> String {
        switch document.kind {
        case .settlementStatementPDF:
            return "Open settlement statement"
        case .settlementSummaryPDF:
            return "Open settlement summary"
        case .handoverChecklistPDF:
            return "Open handover checklist"
        case .signedContractPDF:
            return "Open signed contract"
        case .reviewedContractPDF:
            return "Open reviewed contract"
        case .settlementAdjustmentPDF:
            return "Open settlement adjustment"
        case .contractPacketPDF:
            return "Open contract packet"
        case .councilRatesNoticePDF:
            return "Open rates notice"
        case .identityCheckPackPDF:
            return "Open identity pack"
        case .buyerFinanceProofPDF:
            return "Open finance proof"
        case .sellerOwnershipEvidencePDF:
            return "Open ownership proof"
        }
    }
}

private struct SellerListingCard: View {
    let listing: PropertyListing
    let seller: UserProfile
    let offerCount: Int
    let financeReadyBuyerCount: Int
    let liveDealRoomCount: Int
    let onOpenListing: () -> Void
    let onUpdatePrice: () -> Void

    private var canReprice: Bool {
        listing.status == .active || listing.status == .draft
    }

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

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: currencyString(listing.askingPrice))
                InfoPill(label: "\(offerCount) offers")
                InfoPill(label: "\(financeReadyBuyerCount) finance-ready")
                InfoPill(label: "\(liveDealRoomCount) deal rooms")
                InfoPill(label: "Demand \(listing.marketPulse.buyerDemandScore)")
                InfoPill(label: priceJourneyPillLabel(for: listing))
            }

            Text(listing.headline)
                .foregroundStyle(.secondary)

            Text(priceJourneySupportLine(for: listing))
                .font(.footnote)
                .foregroundStyle(priceMovementTint(for: listing))

            Text("Seller trust profile: \(trustSummaryLine(for: seller))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandPalette.teal)

            HStack(spacing: 12) {
                Button("Open listing") {
                    onOpenListing()
                }
                .buttonStyle(.bordered)

                Button("Update price") {
                    onUpdatePrice()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canReprice)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
    }
}

private struct PriceJourneyRow: View {
    let event: ListingPriceEvent
    let currentAskingPrice: Int

    private var isCurrentPrice: Bool {
        event.amount == currentAskingPrice
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(currencyString(event.amount))
                        .font(.subheadline.weight(.semibold))
                    if isCurrentPrice {
                        Text("Current")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(BrandPalette.teal)
                            )
                    }
                }
                Text(event.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(shortDateString(event.recordedAt))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct AffordabilityScenarioCard: View {
    let scenario: BuyerAffordabilityScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scenario.title)
                .font(.subheadline.weight(.semibold))
            Text(currencyString(scenario.depositAmount))
                .font(.headline.weight(.bold))
            Text("Deposit")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Text("Loan \(currencyString(scenario.loanAmount))")
                .font(.subheadline.weight(.semibold))
            Text("\(currencyString(scenario.monthlyRepayment))/month • \(currencyString(scenario.weeklyRepayment))/week")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrandPalette.panel)
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
                .fill(BrandPalette.card)
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
                .fill(BrandPalette.card)
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
                Text(trustSummaryLine(for: user))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.teal)
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? BrandPalette.selection : BrandPalette.card)
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
            if let counterpart {
                Label(trustSummaryLine(for: counterpart), systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.teal)
            }
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

        return SaleTaskSnapshotSyncStore.viewerID(forUser: store.currentUserID)
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
                if let counterpart {
                    Label(trustSummaryLine(for: counterpart), systemImage: "checkmark.shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandPalette.teal)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.card)
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
    @EnvironmentObject private var messaging: EncryptedMessagingService

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

                    Group {
                        if isSafetyFilteredMessage {
                            Text(displayBody).italic()
                        } else {
                            Text(displayBody)
                        }
                    }
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

    private var displayBody: String {
        messaging.filteredDisplayBody(for: message)
    }

    private var isSafetyFilteredMessage: Bool {
        !message.isSystem && displayBody != message.body
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
        if let session = store.legalWorkspaceSession {
            return SaleTaskSnapshotSyncStore.viewerID(forInvite: session.inviteID)
        }

        return SaleTaskSnapshotSyncStore.viewerID(forUser: store.currentUserID)
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
        if isSafetyFilteredMessage {
            return .secondary
        }

        if message.isSystem {
            return .secondary
        }

        return isCurrentUser ? .white : .primary
    }

    private func saleTaskTheme(for target: SaleReminderNavigationTarget) -> SaleTaskTheme {
        if let conciergeServiceKind = target.conciergeServiceKind {
            switch conciergeServiceKind {
            case .removalist:
                return SaleTaskTheme(
                    accent: BrandPalette.navy,
                    background: Color(red: 0.93, green: 0.96, blue: 0.99),
                    badgeBackground: BrandPalette.navy.opacity(0.14),
                    badgeText: BrandPalette.navy,
                    stageLabel: "MOVING CONCIERGE"
                )
            case .cleaner:
                return SaleTaskTheme(
                    accent: BrandPalette.teal,
                    background: Color(red: 0.91, green: 0.98, blue: 0.95),
                    badgeBackground: BrandPalette.teal.opacity(0.16),
                    badgeText: BrandPalette.teal,
                    stageLabel: "CLEANING"
                )
            case .utilitiesConnection:
                return SaleTaskTheme(
                    accent: BrandPalette.gold,
                    background: Color(red: 1.0, green: 0.97, blue: 0.90),
                    badgeBackground: BrandPalette.gold.opacity(0.24),
                    badgeText: Color(red: 0.55, green: 0.38, blue: 0.05),
                    stageLabel: "UTILITIES"
                )
            case .keyHandover:
                return SaleTaskTheme(
                    accent: BrandPalette.coral,
                    background: Color(red: 1.0, green: 0.94, blue: 0.93),
                    badgeBackground: BrandPalette.coral.opacity(0.18),
                    badgeText: Color(red: 0.68, green: 0.22, blue: 0.20),
                    stageLabel: "HANDOVER"
                )
            }
        }

        return switch target.checklistItemID {
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

        if let conciergeServiceKind = target.conciergeServiceKind {
            if containsAny(["snoozed provider follow-up"]) {
                return SaleTaskStatus(
                    label: "Snoozed",
                    symbolName: "clock.fill",
                    tint: BrandPalette.navy,
                    background: BrandPalette.sky.opacity(0.22)
                )
            }

            if containsAny(["logged provider follow-up"]) {
                return SaleTaskStatus(
                    label: "Follow-up logged",
                    symbolName: "phone.arrow.up.right.fill",
                    tint: BrandPalette.gold,
                    background: BrandPalette.gold.opacity(0.18)
                )
            }

            if containsAny(["marked", "provider confirmed"]) {
                return SaleTaskStatus(
                    label: "Provider confirmed",
                    symbolName: "checkmark.circle.fill",
                    tint: BrandPalette.teal,
                    background: BrandPalette.teal.opacity(0.16)
                )
            }

            return SaleTaskStatus(
                label: "\(conciergeServiceKind.title) booking",
                symbolName: conciergeServiceKind.symbolName,
                tint: BrandPalette.navy,
                background: BrandPalette.navy.opacity(0.10)
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
        if let conciergeServiceKind = target.conciergeServiceKind {
            return "\(conciergeServiceKind.title) provider follow-up"
        }

        return switch target.checklistItemID {
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
        if let conciergeServiceKind = target.conciergeServiceKind {
            return conciergeServiceKind.symbolName
        }

        return switch target.checklistItemID {
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
        if let conciergeServiceKind = target.conciergeServiceKind {
            return "Open \(conciergeServiceKind.title) Booking"
        }

        return switch target.checklistItemID {
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
                .fill(BrandPalette.card)
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
                .fill(BrandPalette.input.opacity(0.9))
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
                    .fill(BrandPalette.card)
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
                    .fill(isSelected ? BrandPalette.teal : BrandPalette.card)
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
                .fill(BrandPalette.card)
        )
    }
}

private struct MiniStatPanel: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.headline.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }
}

private struct VerificationPill: View {
    let check: UserVerificationCheck

    private var tint: Color {
        switch check.status {
        case .verified:
            switch check.kind {
            case .finance, .ownership, .legal:
                return BrandPalette.teal
            case .identity, .mobile:
                return BrandPalette.navy
            }
        case .pending:
            return Color(red: 0.62, green: 0.46, blue: 0.06)
        }
    }

    private var background: Color {
        switch check.status {
        case .verified:
            switch check.kind {
            case .finance, .ownership, .legal:
                return BrandPalette.teal.opacity(0.12)
            case .identity, .mobile:
                return BrandPalette.navy.opacity(0.10)
            }
        case .pending:
            return BrandPalette.gold.opacity(0.22)
        }
    }

    var body: some View {
        Label(check.shortTitle, systemImage: check.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }
}

private struct VerificationChecklistView: View {
    let user: UserProfile
    var onAction: ((VerificationCheckKind) -> Void)? = nil
    var onPreviewDocument: ((VerificationCheckKind) -> Void)? = nil

    private var actionableKinds: Set<VerificationCheckKind> {
        [.identity, .mobile, .finance, .ownership]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(user.highlightedVerificationChecks) { check in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: check.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(check.status == .verified ? BrandPalette.teal : BrandPalette.gold)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.title)
                            .font(.subheadline.weight(.semibold))
                        Text(check.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(check.status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(check.status == .verified ? BrandPalette.teal : Color(red: 0.62, green: 0.46, blue: 0.06))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    check.status == .verified
                                        ? BrandPalette.teal.opacity(0.12)
                                        : BrandPalette.gold.opacity(0.22)
                                )
                        )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.panel)
                )

                if check.kind.requiresDocumentUpload, actionableKinds.contains(check.kind) {
                    HStack(spacing: 12) {
                        if check.hasEvidenceDocument, let onPreviewDocument {
                            Button("Preview PDF") {
                                onPreviewDocument(check.kind)
                            }
                            .buttonStyle(.bordered)
                        }

                        if let onAction {
                            if check.hasEvidenceDocument {
                                Button("Replace PDF") {
                                    onAction(check.kind)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(verificationActionTitle(for: check.kind, role: user.role)) {
                                    onAction(check.kind)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                } else if check.status == .pending {
                    if actionableKinds.contains(check.kind), let onAction {
                        Button(verificationActionTitle(for: check.kind, role: user.role)) {
                            onAction(check.kind)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Complete this step from the sale workflow.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                    .fill(BrandPalette.card)
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
                    .fill(BrandPalette.card)
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

private struct BuyerHubAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct SellerHubAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ListingRepriceContext: Identifiable {
    let listing: PropertyListing

    var id: UUID {
        listing.id
    }
}

private struct SellerNegotiationComposerContext: Identifiable {
    let listing: PropertyListing
    let offer: OfferRecord
    let action: SellerOfferAction

    var id: String {
        "\(offer.id.uuidString)-\(action.rawValue)"
    }

    var offerContext: OfferComposerContext {
        OfferComposerContext(
            mode: .seller(action),
            offer: offer,
            amount: offer.amount,
            conditions: offer.conditions
        )
    }
}

private struct SellerOfferPriority {
    let score: Int
    let label: String
    let detail: String
    let tint: Color
    let background: Color
}

private struct BuyerOfferPriority {
    let score: Int
    let label: String
    let detail: String
    let tint: Color
    let background: Color
}

private struct BuyerTransactionEntry: Identifiable {
    let listing: PropertyListing
    let offer: OfferRecord
    let seller: UserProfile
    let priority: BuyerOfferPriority

    var id: UUID {
        offer.id
    }
}

private struct SellerOfferBoardEntry: Identifiable {
    let listing: PropertyListing
    let offer: OfferRecord
    let buyer: UserProfile
    let priority: SellerOfferPriority

    var id: UUID {
        offer.id
    }
}

private enum ConciergeAttentionSeverity: Equatable {
    case overdue
    case dueSoon

    var title: String {
        switch self {
        case .overdue:
            return "Urgent follow-up"
        case .dueSoon:
            return "Due soon"
        }
    }

    var supportingLine: String {
        switch self {
        case .overdue:
            return "Provider reply is overdue"
        case .dueSoon:
            return "Provider reply window is approaching"
        }
    }

    var tint: Color {
        switch self {
        case .overdue:
            return BrandPalette.coral
        case .dueSoon:
            return BrandPalette.gold
        }
    }

    var background: Color {
        switch self {
        case .overdue:
            return BrandPalette.coral.opacity(0.14)
        case .dueSoon:
            return BrandPalette.gold.opacity(0.18)
        }
    }

    var symbolName: String {
        switch self {
        case .overdue:
            return "exclamationmark.triangle.fill"
        case .dueSoon:
            return "clock.badge.exclamationmark.fill"
        }
    }

    var sortRank: Int {
        switch self {
        case .overdue:
            return 0
        case .dueSoon:
            return 1
        }
    }
}

private enum ConciergeAttentionScopeFilter: String, CaseIterable, Identifiable {
    case all
    case urgent
    case dueSoon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .urgent:
            return "Urgent"
        case .dueSoon:
            return "Due soon"
        }
    }

    func matches(_ severity: ConciergeAttentionSeverity) -> Bool {
        switch self {
        case .all:
            return true
        case .urgent:
            return severity == .overdue
        case .dueSoon:
            return severity == .dueSoon
        }
    }
}

private enum ConciergeAttentionServiceFilter: String, CaseIterable, Identifiable {
    case all
    case removalist
    case cleaner
    case utilitiesConnection
    case keyHandover

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All services"
        case .removalist:
            return PostSaleConciergeServiceKind.removalist.title
        case .cleaner:
            return PostSaleConciergeServiceKind.cleaner.title
        case .utilitiesConnection:
            return PostSaleConciergeServiceKind.utilitiesConnection.title
        case .keyHandover:
            return PostSaleConciergeServiceKind.keyHandover.title
        }
    }

    var symbolName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .removalist:
            return PostSaleConciergeServiceKind.removalist.symbolName
        case .cleaner:
            return PostSaleConciergeServiceKind.cleaner.symbolName
        case .utilitiesConnection:
            return PostSaleConciergeServiceKind.utilitiesConnection.symbolName
        case .keyHandover:
            return PostSaleConciergeServiceKind.keyHandover.symbolName
        }
    }

    func matches(_ serviceKind: PostSaleConciergeServiceKind) -> Bool {
        switch self {
        case .all:
            return true
        case .removalist:
            return serviceKind == .removalist
        case .cleaner:
            return serviceKind == .cleaner
        case .utilitiesConnection:
            return serviceKind == .utilitiesConnection
        case .keyHandover:
            return serviceKind == .keyHandover
        }
    }
}

private enum ConciergeAttentionPrimaryActionKind: Equatable {
    case switchProvider
    case callProvider
    case reviewBooking
    case viewBooking

    var showsOpenBookingShortcut: Bool {
        switch self {
        case .switchProvider, .callProvider:
            return true
        case .reviewBooking, .viewBooking:
            return false
        }
    }
}

private struct ConciergeAttentionRecommendation {
    let title: String
    let supporting: String
    let primaryActionKind: ConciergeAttentionPrimaryActionKind
    let primaryActionTitle: String
    let tint: Color
    let background: Color
    let symbolName: String
}

private struct BuyerConciergeAttentionItem: Identifiable {
    let entry: BuyerTransactionEntry
    let row: ArchiveConciergeRow
    let severity: ConciergeAttentionSeverity

    var id: String {
        "\(entry.id.uuidString)-\(row.id)"
    }
}

private struct SellerConciergeAttentionItem: Identifiable {
    let entry: SellerOfferBoardEntry
    let row: ArchiveConciergeRow
    let severity: ConciergeAttentionSeverity

    var id: String {
        "\(entry.id.uuidString)-\(row.id)"
    }
}

private struct ConciergeAttentionFilterPanel: View {
    @Binding var severityFilter: ConciergeAttentionScopeFilter
    @Binding var serviceFilter: ConciergeAttentionServiceFilter

    let visibleCount: Int
    let totalCount: Int
    let selectedVisibleCount: Int
    let selectedTotalCount: Int
    let onSelectVisible: () -> Void
    let onClearSelection: () -> Void

    private var summaryLine: String {
        if visibleCount == totalCount {
            return "Showing all \(totalCount) concierge reminders in this queue."
        }
        return "Showing \(visibleCount) of \(totalCount) concierge reminders after filtering."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Queue filters")
                .font(.subheadline.weight(.semibold))

            Picker("Attention scope", selection: $severityFilter) {
                ForEach(ConciergeAttentionScopeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Menu {
                    ForEach(ConciergeAttentionServiceFilter.allCases) { filter in
                        Button {
                            serviceFilter = filter
                        } label: {
                            Label(filter.title, systemImage: filter.symbolName)
                        }
                    }
                } label: {
                    Label(serviceFilter.title, systemImage: serviceFilter.symbolName)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button(selectedVisibleCount == visibleCount && visibleCount > 0 ? "Visible selected" : "Select visible") {
                    onSelectVisible()
                }
                .buttonStyle(.bordered)
                .disabled(visibleCount == 0 || (selectedVisibleCount == visibleCount && visibleCount > 0))

                Button("Clear all") {
                    onClearSelection()
                }
                .buttonStyle(.bordered)
                .disabled(selectedTotalCount == 0)
            }

            Text(summaryLine)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if selectedTotalCount > 0 {
                Text(
                    selectedVisibleCount == selectedTotalCount
                        ? "\(selectedTotalCount) queue item\(selectedTotalCount == 1 ? "" : "s") selected."
                        : "\(selectedVisibleCount) visible selected • \(selectedTotalCount) selected overall."
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandPalette.teal)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.card)
        )
    }
}

private struct ConciergeAttentionSectionHeader: View {
    let serviceKind: PostSaleConciergeServiceKind
    let itemCount: Int
    let urgentCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Label(serviceKind.title, systemImage: serviceKind.symbolName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BrandPalette.navy)

            Text(itemCount == 1 ? "1 provider thread" : "\(itemCount) provider threads")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if urgentCount > 0 {
                Text(urgentCount == 1 ? "1 urgent" : "\(urgentCount) urgent")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandPalette.coral)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(BrandPalette.coral.opacity(0.14))
                    )
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ConciergeAttentionQueueCard: View {
    let title: String
    let listingTitle: String
    let listingSubtitle: String
    let counterpartLabel: String
    let counterpartName: String
    let recommendation: ConciergeAttentionRecommendation?
    let statusText: String
    let detail: String
    let activityLines: [String]
    let symbolName: String
    let severity: ConciergeAttentionSeverity
    let isSelected: Bool
    let canLogFollowUp: Bool
    let canSnooze: Bool
    let canConfirm: Bool
    let canLogIssue: Bool
    let currentProvider: PostSaleConciergeProvider?
    let providerCallURL: URL?
    let providerWebsiteURL: URL?
    let providerMapsURL: URL?
    let suggestedReplacement: ConciergeReplacementSuggestion?
    let isLoadingSuggestedReplacement: Bool
    let isPreparingSuggestedReplacement: Bool
    let onToggleSelection: () -> Void
    let onPrimaryAction: () -> Void
    let onUseSuggestedReplacement: (() -> Void)?
    let onOpenBooking: () -> Void
    let onLogFollowUp: () -> Void
    let onSnooze: () -> Void
    let onConfirm: () -> Void
    let onLogIssue: () -> Void
    let onOpenThread: () -> Void
    let onOpenListing: () -> Void

    private var bookingButtonTitle: String {
        recommendation?.primaryActionTitle ?? "Open booking"
    }

    private var showsOpenBookingShortcut: Bool {
        recommendation?.primaryActionKind.showsOpenBookingShortcut ?? false
    }

    private var showsSuggestedReplacementAction: Bool {
        recommendation?.primaryActionKind == .switchProvider && onUseSuggestedReplacement != nil
    }

    private var suggestedReplacementButtonTitle: String {
        if isPreparingSuggestedReplacement {
            return "Finding backup..."
        }

        if let suggestedReplacement {
            return "Use \(suggestedReplacement.provider.name)"
        }

        if isLoadingSuggestedReplacement {
            return "Finding backup..."
        }

        return "Use best backup"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(severity.background)
                        .frame(width: 42, height: 42)

                    Image(systemName: symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(severity.tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Label(severity.title, systemImage: severity.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(severity.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(severity.background)
                            )

                        Text(severity.supportingLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(title)
                        .font(.headline)
                    Text(listingTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(listingSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(counterpartLabel): \(counterpartName)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrandPalette.teal)
                }

                Spacer(minLength: 12)

                Button {
                    onToggleSelection()
                } label: {
                    Label(isSelected ? "Selected" : "Select", systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? BrandPalette.teal : BrandPalette.navy)
            }

            Text(detail)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            AdaptiveTagGrid(minimum: 130) {
                InfoPill(label: severity.title)
                InfoPill(label: statusText)
                InfoPill(label: counterpartName)
                InfoPill(label: listingTitle)
            }

            if let recommendation {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(recommendation.background)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: recommendation.symbolName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(recommendation.tint)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(recommendation.tint)
                        Text(recommendation.supporting)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(recommendation.background.opacity(0.9))
                )
            }

            if !activityLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent activity")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(activityLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(severity.tint.opacity(0.5))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)

                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if providerCallURL != nil || providerWebsiteURL != nil || providerMapsURL != nil {
                HStack(spacing: 10) {
                    if let providerCallURL {
                        Link("Call provider", destination: providerCallURL)
                            .buttonStyle(.bordered)
                    }

                    if let providerWebsiteURL {
                        Link("Website", destination: providerWebsiteURL)
                            .buttonStyle(.bordered)
                    }

                    if let providerMapsURL {
                        Link("Maps", destination: providerMapsURL)
                            .buttonStyle(.bordered)
                    }
                }
            }

            if showsSuggestedReplacementAction, let onUseSuggestedReplacement {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested backup")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    if let suggestedReplacement {
                        VStack(alignment: .leading, spacing: 8) {
                            if let currentProvider {
                                HStack(alignment: .top, spacing: 12) {
                                    ConciergeQueueProviderSnapshot(
                                        title: "Current",
                                        provider: currentProvider,
                                        accent: BrandPalette.navy
                                    )

                                    ConciergeQueueProviderSnapshot(
                                        title: "Backup",
                                        provider: suggestedReplacement.provider,
                                        accent: BrandPalette.teal
                                    )
                                }

                                let comparisonLines = conciergeReplacementComparisonLines(
                                    currentProvider: currentProvider,
                                    suggestedProvider: suggestedReplacement.provider
                                )
                                if !comparisonLines.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(comparisonLines.enumerated()), id: \.offset) { _, line in
                                            HStack(alignment: .top, spacing: 8) {
                                                Circle()
                                                    .fill(BrandPalette.teal.opacity(0.7))
                                                    .frame(width: 6, height: 6)
                                                    .padding(.top, 5)

                                                Text(line)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }

                            ConciergeReplacementSafetyPanel(
                                summary: suggestedReplacement.safetySummary,
                                compact: true
                            )

                            ConciergeReplacementImpactPanel(
                                summary: suggestedReplacement.impactSummary,
                                compact: true
                            )

                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(BrandPalette.teal.opacity(0.14))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: "sparkles")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(BrandPalette.teal)
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestedReplacement.provider.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(suggestedReplacement.statusLine)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(BrandPalette.teal)
                                    if let responseLine = conciergeProviderResponseLine(suggestedReplacement.provider) {
                                        Text(responseLine)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer(minLength: 0)
                            }

                            AdaptiveTagGrid(minimum: 120) {
                                ForEach(Array(suggestedReplacement.labels.prefix(4)), id: \.self) { label in
                                    InfoPill(label: label)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(BrandPalette.teal.opacity(0.08))
                        )
                    } else {
                        Text(
                            isLoadingSuggestedReplacement
                                ? "Ranking the strongest local replacement now so the switch can start from the queue."
                                : "Searches local alternatives and opens replacement mode with the top backup preselected."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button(suggestedReplacementButtonTitle) {
                            onUseSuggestedReplacement()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPreparingSuggestedReplacement || isLoadingSuggestedReplacement)

                        if suggestedReplacement != nil {
                            Text("Opens replacement mode with this provider already selected.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button(bookingButtonTitle) {
                    onPrimaryAction()
                }
                .buttonStyle(.borderedProminent)

                if showsOpenBookingShortcut {
                    Button("Open booking") {
                        onOpenBooking()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Log follow-up") {
                    onLogFollowUp()
                }
                .buttonStyle(.bordered)
                .disabled(!canLogFollowUp)

                Button("Snooze 24h") {
                    onSnooze()
                }
                .buttonStyle(.bordered)
                .disabled(!canSnooze)

                Button("Confirm") {
                    onConfirm()
                }
                .buttonStyle(.bordered)
                .disabled(!canConfirm)

                Button("Log issue") {
                    onLogIssue()
                }
                .buttonStyle(.bordered)
                .disabled(!canLogIssue)
            }

            HStack(spacing: 10) {
                Button("Open thread") {
                    onOpenThread()
                }
                .buttonStyle(.bordered)

                Button("Open listing") {
                    onOpenListing()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? BrandPalette.teal : severity.tint.opacity(0.18),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }
}

private struct ConciergeQueueProviderSnapshot: View {
    let title: String
    let provider: PostSaleConciergeProvider
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)

            Text(provider.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let responseLine = conciergeProviderResponseLine(provider) {
                Text(responseLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let ratingLine = conciergeProviderRatingLine(provider) {
                Text(ratingLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let priceGuide = conciergeProviderPriceGuide(provider) {
                Text(priceGuide)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }
}

private struct ConciergeReplacementSafetyPanel: View {
    let summary: ConciergeReplacementSafetySummary
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(summary.tint.opacity(0.14))
                    .frame(width: compact ? 28 : 32, height: compact ? 28 : 32)
                    .overlay {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(summary.tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(compact ? .caption.weight(.bold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(summary.summary)
                        .font(compact ? .footnote : .subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(summary.scoreText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(summary.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(summary.tint.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(summary.reasons.prefix(compact ? 2 : 3).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(summary.tint.opacity(0.7))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)

                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(compact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .fill(summary.tint.opacity(compact ? 0.08 : 0.06))
        )
    }
}

private struct ConciergeReplacementImpactPanel: View {
    let summary: ConciergeReplacementImpactSummary
    var compact: Bool = false

    private var maxItemsPerSection: Int {
        compact ? 1 : 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(summary.tint.opacity(0.14))
                    .frame(width: compact ? 28 : 32, height: compact ? 28 : 32)
                    .overlay {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(summary.tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(compact ? .caption.weight(.bold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(summary.supporting)
                        .font(compact ? .footnote : .subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            impactSection("Carries forward", lines: summary.keeps, tint: BrandPalette.teal)
            impactSection("Restarts", lines: summary.resets, tint: BrandPalette.coral)
            impactSection("Stays on file", lines: summary.archived, tint: BrandPalette.navy)
            impactSection("Risk reduced", lines: summary.riskReduced, tint: summary.tint)
        }
        .padding(compact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .fill(summary.tint.opacity(compact ? 0.08 : 0.06))
        )
    }

    @ViewBuilder
    private func impactSection(_ title: String, lines: [String], tint: Color) -> some View {
        let visibleLines = Array(lines.prefix(maxItemsPerSection))
        if visibleLines.isEmpty == false {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tint.opacity(0.7))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)

                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ConciergeBatchReplacementReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    let context: ConciergeBatchReplacementReviewContext
    let onConfirm: ([ConciergeBatchReplacementReviewEntry], ConciergeBatchReviewReturnContext) -> Void
    let onOpenEntry: (ConciergeBatchReplacementReviewEntry, ConciergeBatchReviewReturnContext) -> Void
    let onCloseEntries: ([String], Int) -> Void

    @State private var reviewEntries: [ConciergeBatchReplacementReviewEntry]
    @State private var isResolvingMissingSuggestions = false
    @State private var isApplying = false
    @State private var sectionActionAlert: ConciergeBatchReviewStatusAlert?
    @State private var rankingUpdateSummary: ConciergeBatchReviewRankingUpdateSummary?
    @State private var focusedRecoveryEntryID: String?
    @State private var stagedReadyEntryIDs: [String] = []
    @State private var approvedStagedEntryFingerprints: [String: String] = [:]
    @State private var invalidatedStagedEntryIDs: [String] = []
    @State private var refreshHighlightedStagedEntryIDs: [String] = []
    @State private var reviewedRefreshHighlightEntryIDs: [String] = []
    @State private var appliedRefreshHighlightEntryIDs: [String] = []
    @State private var refreshOutcomeJumpLaneProgress: ConciergeBatchReviewRefreshLaneProgress?
    @State private var visitedRefreshBookingEntryIDs: [String] = []
    @State private var reactivatedRefreshBookingEntryIDs: [String] = []
    @State private var reactivationCompletionReviewLastItemID: String?
    @State private var reviewedReactivationCompletionItemIDs: [String] = []
    @State private var hasHiddenCompletedBookingLane = false
    @State private var hasActiveBookingLaneReactivation = false
    @State private var hasDismissedBookingLaneReactivationCompletion = false
    @State private var approvalRefreshCloseoutSummary: ConciergeBatchReviewApprovalRefreshCloseoutSummary?
    @State private var hasClosedApprovalRefreshSummary = false
    @State private var hasDismissedApprovalRefreshCloseoutSummary = false

    private let stagedReviewAnchorID = "concierge-batch-staged-review-anchor"

    init(
        context: ConciergeBatchReplacementReviewContext,
        onConfirm: @escaping ([ConciergeBatchReplacementReviewEntry], ConciergeBatchReviewReturnContext) -> Void,
        onOpenEntry: @escaping (ConciergeBatchReplacementReviewEntry, ConciergeBatchReviewReturnContext) -> Void,
        onCloseEntries: @escaping ([String], Int) -> Void
    ) {
        self.context = context
        self.onConfirm = onConfirm
        self.onOpenEntry = onOpenEntry
        self.onCloseEntries = onCloseEntries
        _reviewEntries = State(initialValue: context.entries)
        _stagedReadyEntryIDs = State(initialValue: context.initialStagedEntryIDs)
        _approvedStagedEntryFingerprints = State(initialValue: context.initialApprovedStagedEntryFingerprints)
        _refreshHighlightedStagedEntryIDs = State(initialValue: context.initialRefreshHighlightedStagedEntryIDs)
        _visitedRefreshBookingEntryIDs = State(initialValue: context.initialVisitedRefreshBookingEntryIDs)
        _reactivatedRefreshBookingEntryIDs = State(initialValue: context.initialReactivatedRefreshBookingEntryIDs)
        _reactivationCompletionReviewLastItemID = State(initialValue: context.initialReactivationCompletionReviewLastItemID)
        _reviewedReactivationCompletionItemIDs = State(initialValue: context.initialReviewedReactivationCompletionItemIDs)
        _hasHiddenCompletedBookingLane = State(initialValue: context.initialHasHiddenCompletedBookingLane)
        _hasActiveBookingLaneReactivation = State(initialValue: context.initialHasActiveBookingLaneReactivation)
        _hasDismissedBookingLaneReactivationCompletion = State(initialValue: context.initialHasDismissedBookingLaneReactivationCompletion)
        _refreshOutcomeJumpLaneProgress = State(initialValue: nil)
        _invalidatedStagedEntryIDs = State(
            initialValue: conciergeBatchReviewInvalidatedStagedEntryIDs(
                entries: context.entries,
                stagedEntryIDs: context.initialStagedEntryIDs,
                approvalFingerprints: context.initialApprovedStagedEntryFingerprints
            )
        )
    }

    private var readyEntries: [ConciergeBatchReplacementReviewEntry] {
        reviewEntries.filter(\.canApplySuggestedReplacement)
    }

    private var loadingEntries: [ConciergeBatchReplacementReviewEntry] {
        reviewEntries.filter(\.isLoadingSuggestion)
    }

    private var manualReviewEntries: [ConciergeBatchReplacementReviewEntry] {
        reviewEntries.filter { $0.isLoadingSuggestion == false && $0.canApplySuggestedReplacement == false }
    }

    private var stagedReadyEntries: [ConciergeBatchReplacementReviewEntry] {
        entries(matching: stagedReadyEntryIDs).filter(\.canApplySuggestedReplacement)
    }

    private var approvedStagedEntries: [ConciergeBatchReplacementReviewEntry] {
        stagedReadyEntries.filter { entry in
            approvedStagedEntryFingerprints[entry.id] == conciergeBatchReviewStagedApprovalFingerprint(for: entry)
        }
    }

    private var pendingStagedEntries: [ConciergeBatchReplacementReviewEntry] {
        let approvedIDs = Set(approvedStagedEntries.map(\.id))
        return stagedReadyEntries.filter { approvedIDs.contains($0.id) == false }
    }

    private var invalidatedStagedEntries: [ConciergeBatchReplacementReviewEntry] {
        let invalidatedIDs = Set(invalidatedStagedEntryIDs)
        return pendingStagedEntries.filter { invalidatedIDs.contains($0.id) }
    }

    private var unstagedReadyEntries: [ConciergeBatchReplacementReviewEntry] {
        let stagedIDs = Set(stagedReadyEntries.map(\.id))
        return readyEntries.filter { stagedIDs.contains($0.id) == false }
    }

    private var stagedReviewNotes: [ConciergeBatchReviewStagedNote] {
        let approvedIDs = Set(approvedStagedEntries.map(\.id))
        let invalidatedIDs = Set(invalidatedStagedEntries.map(\.id))
        let refreshHighlightedIDs = Set(refreshHighlightedStagedEntries.map(\.id))
        return stagedReadyEntries.compactMap { entry in
            conciergeBatchReviewStagedNote(
                for: entry,
                isApproved: approvedIDs.contains(entry.id),
                isInvalidated: invalidatedIDs.contains(entry.id),
                isRefreshHighlighted: refreshHighlightedIDs.contains(entry.id)
            )
        }
    }

    private var refreshHighlightedStagedEntries: [ConciergeBatchReplacementReviewEntry] {
        entries(matching: refreshHighlightedStagedEntryIDs).filter(\.canApplySuggestedReplacement)
    }

    private var stagedApprovalFeedback: ConciergeBatchReviewStagedApprovalFeedback? {
        let invalidatedCount = invalidatedStagedEntries.count
        guard invalidatedCount > 0 else {
            return nil
        }

        let preservedCount = approvedStagedEntries.count
        let title = invalidatedCount == 1
            ? "1 staged approval needs a quick recheck"
            : "\(invalidatedCount) staged approvals need a quick recheck"

        var message = "\(invalidatedCount) row\(invalidatedCount == 1 ? "" : "s") moved back to pending because the booking or top-ranked backup changed while the review was open."
        if preservedCount > 0 {
            message += " \(preservedCount) approval\(preservedCount == 1 ? "" : "s") still carry forward because the saved switch context is unchanged."
        }

        return ConciergeBatchReviewStagedApprovalFeedback(
            title: title,
            message: message,
            supporting: "Rows marked recheck required stay staged below until you approve them again or defer them back into the broader ready queue."
        )
    }

    private var currentReturnContext: ConciergeBatchReviewReturnContext {
        ConciergeBatchReviewReturnContext(
            hubTitle: context.hubTitle,
            itemIDs: reviewEntries.map(\.id),
            itemTitlesByID: Dictionary(
                uniqueKeysWithValues: reviewEntries.map { ($0.id, conciergeBatchReviewRowTitle(for: $0)) }
            ),
            itemReferencesByID: Dictionary(
                uniqueKeysWithValues: reviewEntries.map { ($0.id, conciergeBatchReviewEntryReference(for: $0)) }
            ),
            previousSnapshots: reviewEntries.map(conciergeBatchReviewRowSnapshot(for:)),
            stagedEntryIDs: stagedReadyEntryIDs,
            stagedApprovalFingerprints: approvedStagedEntryFingerprints,
            refreshHighlightedStagedEntryIDs: refreshHighlightedStagedEntryIDs,
            reviewedRefreshHighlightEntryIDs: reviewedRefreshHighlightEntryIDs,
            appliedRefreshHighlightEntryIDs: appliedRefreshHighlightEntryIDs,
            visitedRefreshBookingEntryIDs: visitedRefreshBookingEntryIDs,
            hasHiddenCompletedBookingLane: hasHiddenCompletedBookingLane,
            hasActiveBookingLaneReactivation: hasActiveBookingLaneReactivation,
            hasDismissedBookingLaneReactivationCompletion: hasDismissedBookingLaneReactivationCompletion,
            reactivatedRefreshBookingEntryIDs: reactivatedRefreshBookingEntryIDs,
            reactivationCompletionReviewLastItemID: reactivationCompletionReviewLastItemID,
            reviewedReactivationCompletionItemIDs: reviewedReactivationCompletionItemIDs
        )
    }

    private var actionableApprovalRefreshItems: [ConciergeBatchReviewApprovalRefreshItem] {
        guard let summary = activeApprovalRefreshSummary else {
            return []
        }

        let pendingIDs = Set(pendingStagedEntries.map(\.id))
        return summary.immediateReapprovalItems.filter { pendingIDs.contains($0.id) }
    }

    private var activeApprovalRefreshSummary: ConciergeBatchReviewApprovalRefreshSummary? {
        guard hasClosedApprovalRefreshSummary == false else {
            return nil
        }

        return context.approvalRefreshSummary
    }

    private var activeApprovalRefreshCloseoutSummary: ConciergeBatchReviewApprovalRefreshCloseoutSummary? {
        guard hasDismissedApprovalRefreshCloseoutSummary == false else {
            return nil
        }

        return approvalRefreshCloseoutSummary
    }

    private var bookingLaneProgress: ConciergeBatchReviewRefreshLaneProgress? {
        guard let refreshSummary = context.refreshSummary else {
            return nil
        }

        return conciergeBatchReviewBookingLaneProgress(
            visitedIDs: visitedRefreshBookingEntryIDs,
            items: refreshSummary.bookingItems
        )
    }

    private var isBookingLaneHidden: Bool {
        hasHiddenCompletedBookingLane && (bookingLaneProgress?.remainingCount == 0)
    }

    private var showsReactivatedBookingLane: Bool {
        hasHiddenCompletedBookingLane && (bookingLaneProgress?.remainingCount ?? 0) > 0
    }

    private var showsBookingLaneReactivationCompletion: Bool {
        hasActiveBookingLaneReactivation &&
        bookingLaneProgress?.remainingCount == 0 &&
        bookingLaneProgress != nil &&
        isBookingLaneHidden == false &&
        hasDismissedBookingLaneReactivationCompletion == false
    }

    private var bookingLaneReactivationCompletionMessage: String? {
        guard showsBookingLaneReactivationCompletion,
              let bookingLaneProgress,
              let lastVisitedItem = context.refreshSummary?.bookingItems.first(where: { $0.id == bookingLaneProgress.lastItemID }) else {
            return nil
        }

        return "\(lastVisitedItem.title) was the last reopened booking row to be revisited, so the reactivated booking lane is fully caught up again."
    }

    private var bookingLaneReactivationCompletionSupporting: String? {
        guard showsBookingLaneReactivationCompletion else {
            return nil
        }

        let titles = context.refreshSummary?.bookingItems
            .filter { reactivatedRefreshBookingEntryIDs.contains($0.id) }
            .map(\.title) ?? []
        guard titles.isEmpty == false else {
            return nil
        }

        let visibleTitles = Array(titles.prefix(3))
        var summary = "Reactivated rows cleared: " + visibleTitles.joined(separator: " • ")
        if titles.count > visibleTitles.count {
            summary += " • +\(titles.count - visibleTitles.count) more"
        }
        return summary
    }

    private var reactivationCompletionReviewItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        let reactivatedIDs = Set(reactivatedRefreshBookingEntryIDs)
        return context.refreshSummary?.bookingItems.filter { reactivatedIDs.contains($0.id) } ?? []
    }

    private var pendingReactivationCompletionReviewItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        let reviewedIDs = Set(reviewedReactivationCompletionItemIDs)
        return reactivationCompletionReviewItems.filter { reviewedIDs.contains($0.id) == false }
    }

    private var reviewedReactivationCompletionReviewItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        let reviewedIDs = Set(reviewedReactivationCompletionItemIDs)
        return reactivationCompletionReviewItems.filter { reviewedIDs.contains($0.id) }
    }

    private var isReactivationCompletionReviewComplete: Bool {
        showsBookingLaneReactivationCompletion &&
        reactivationCompletionReviewItems.isEmpty == false &&
        pendingReactivationCompletionReviewItems.isEmpty
    }

    private var reactivationCompletionReviewActionTitle: String? {
        guard showsBookingLaneReactivationCompletion,
              pendingReactivationCompletionReviewItems.isEmpty == false else {
            return nil
        }

        if pendingReactivationCompletionReviewItems.count == 1 {
            return reviewedReactivationCompletionReviewItems.isEmpty ? "Review cleared row" : "Open final cleared row"
        }

        return reviewedReactivationCompletionReviewItems.isEmpty ? "Review cleared rows" : "Open next cleared row"
    }

    private var reactivationCompletionReviewProgress: ConciergeBatchReviewRefreshLaneProgress? {
        guard showsBookingLaneReactivationCompletion,
              reactivationCompletionReviewItems.isEmpty == false else {
            return nil
        }

        let reviewedCount = reviewedReactivationCompletionReviewItems.count
        let totalCount = reactivationCompletionReviewItems.count
        let remainingCount = pendingReactivationCompletionReviewItems.count
        let nextItem = pendingReactivationCompletionReviewItems.first
        let lastReviewedItem = reviewedReactivationCompletionReviewItems.last
        let selectedItem = lastReviewedItem ?? nextItem
        guard let selectedItem else {
            return nil
        }

        let title: String
        let message: String
        let highlightTitle: String
        if remainingCount == 0 {
            title = totalCount == 1
                ? "Cleared row review complete"
                : "All \(totalCount) cleared rows reviewed"
            message = "\(selectedItem.title) completed the final cleared-cycle check. Every reopened booking row from this cycle has now been reviewed once."
            highlightTitle = "Last reviewed"
        } else {
            title = "\(reviewedCount) of \(totalCount) cleared rows reviewed"
            message = "\(selectedItem.title) was the most recent cleared row reviewed. \(remainingCount) row\(remainingCount == 1 ? "" : "s") still need a final check from this cycle."
            highlightTitle = "Last reviewed"
        }

        return ConciergeBatchReviewRefreshLaneProgress(
            lastItemID: selectedItem.id,
            title: title,
            message: message,
            highlightTitle: highlightTitle,
            nextItemID: nextItem?.id,
            remainingCount: remainingCount,
            totalCount: totalCount
        )
    }

    private var approvalRefreshCloseoutJumpTitle: String? {
        if approvedStagedEntries.isEmpty == false {
            return approvedStagedEntries.count == 1
                ? "Jump to approved staged row"
                : "Jump to approved staged rows"
        }

        if stagedReadyEntries.isEmpty == false {
            return "Jump to staged review"
        }

        return nil
    }

    private var completionGuidance: ConciergeBatchReviewCompletionGuidance? {
        guard context.refreshSummary != nil else {
            return nil
        }

        return conciergeBatchReviewCompletionGuidance(for: reviewEntries)
    }

    private var safeToCloseEntryIDs: [String] {
        completionGuidance?.safeToCloseItems.map(\.id) ?? []
    }

    private var groupedReviewSections: [ConciergeBatchReviewNextActionSection] {
        ConciergeBatchReviewNextActionGroup.allCases.compactMap { group in
            let entries = groupedEntries(for: group)
            guard entries.isEmpty == false else {
                return nil
            }

            return ConciergeBatchReviewNextActionSection(group: group, entries: entries)
        }
    }

    private var confirmTitle: String {
        let readyCount = readyEntries.count
        if readyCount == 1 {
            return loadingEntries.isEmpty ? "Apply 1 ranked backup" : "Apply 1 ready backup now"
        }
        return loadingEntries.isEmpty
            ? "Apply \(readyCount) ranked backups"
            : "Apply \(readyCount) ready backups now"
    }

    private var recoveryReadyMessage: String? {
        guard readyEntries.isEmpty == false,
              loadingEntries.isEmpty == false || manualReviewEntries.isEmpty == false else {
            return nil
        }

        var details: [String] = []
        if loadingEntries.isEmpty == false {
            details.append("\(loadingEntries.count) still ranking")
        }
        if manualReviewEntries.isEmpty == false {
            details.append("\(manualReviewEntries.count) still need manual review")
        }

        let suffix = details.isEmpty ? "" : " while " + details.joined(separator: " and ")
        return "\(readyEntries.count) ranked backup\(readyEntries.count == 1 ? " is" : "s are") ready to switch now\(suffix)."
    }

    private var reviewHeaderSupporting: String {
        let strategyTitle = context.strategy.title
        let strategyDetail = context.strategy.detail
        return "Using \(strategyTitle) mode: \(strategyDetail)"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HighlightInformationCard(
                            title: "\(context.hubTitle) batch review",
                            message: "Review the ranked concierge provider switches before Real O Who applies them from the attention queue.",
                            supporting: reviewHeaderSupporting
                        )

                        if let refreshSummary = context.refreshSummary {
                            HighlightInformationCard(
                                title: refreshSummary.title,
                                message: refreshSummary.message,
                                supporting: refreshSummary.supporting
                            )

                            if refreshSummary.appliedRefreshItems.isEmpty == false || refreshSummary.reviewedRefreshItems.isEmpty == false {
                                ConciergeBatchReviewRefreshOutcomePanel(
                                    summary: refreshSummary,
                                    jumpLaneProgress: refreshOutcomeJumpLaneProgress,
                                    bookingLaneProgress: bookingLaneProgress,
                                    visitedBookingItemIDs: visitedRefreshBookingEntryIDs,
                                    reactivatedBookingItemIDs: reactivatedRefreshBookingEntryIDs,
                                    isBookingLaneHidden: isBookingLaneHidden,
                                    showsReactivatedBookingLane: showsReactivatedBookingLane,
                                    bookingLaneReactivationCompletionMessage: bookingLaneReactivationCompletionMessage,
                                    bookingLaneReactivationCompletionSupporting: bookingLaneReactivationCompletionSupporting,
                                    completionReviewActionTitle: reactivationCompletionReviewActionTitle,
                                    completionReviewProgress: reactivationCompletionReviewProgress,
                                    completionReviewLastItemID: reactivationCompletionReviewLastItemID,
                                    isCompletionReviewComplete: isReactivationCompletionReviewComplete,
                                    onJumpLane: {
                                        handleRefreshOutcomeJumpLane(
                                            refreshSummary.jumpItems,
                                            using: proxy
                                        )
                                    },
                                    onBookingLane: {
                                        handleRefreshOutcomeBookingLane(
                                            refreshSummary.bookingItems,
                                            using: proxy
                                        )
                                    },
                                    onHideCompletedBookingLane: {
                                        hideCompletedRefreshBookingLane()
                                    },
                                    onRestoreBookingLane: {
                                        restoreRefreshBookingLane()
                                    },
                                    onHideCompletedBookingLaneAfterReactivation: {
                                        hideCompletedRefreshBookingLaneAfterReactivation()
                                    },
                                    onDismissBookingLaneReactivationCompletion: {
                                        dismissBookingLaneReactivationCompletion()
                                    },
                                    onReviewClearedCycle: {
                                        reviewNextClearedReactivationBooking(using: proxy)
                                    },
                                    onAction: { item in
                                        handleRefreshOutcomeItem(item, using: proxy)
                                    }
                                )
                            }
                        }

                        if let approvalRefreshSummary = activeApprovalRefreshSummary {
                            ConciergeBatchReviewApprovalRefreshPanel(
                                summary: approvalRefreshSummary,
                                actionableItems: actionableApprovalRefreshItems,
                                onApproveAll: actionableApprovalRefreshItems.isEmpty ? nil : {
                                    approveApprovalRefreshItems(actionableApprovalRefreshItems.map(\.id))
                                },
                                onApproveItem: { item in
                                    approveApprovalRefreshItems([item.id])
                                }
                            )
                        }

                        if let approvalRefreshCloseoutSummary = activeApprovalRefreshCloseoutSummary {
                            ConciergeBatchReviewApprovalRefreshCloseoutPanel(
                                summary: approvalRefreshCloseoutSummary,
                                jumpTitle: approvalRefreshCloseoutJumpTitle,
                                onJumpToReview: approvalRefreshCloseoutJumpTitle == nil ? nil : {
                                    jumpToApprovalRefreshHandoff(using: proxy, dismissCloseoutAfterJump: true)
                                },
                                onDismiss: {
                                    hasDismissedApprovalRefreshCloseoutSummary = true
                                }
                            )
                        }

                    if let rankingUpdateSummary {
                        HighlightInformationCard(
                            title: rankingUpdateSummary.title,
                            message: rankingUpdateSummary.message,
                            supporting: rankingUpdateSummary.supporting
                        )
                    }

                        if let stagedApprovalFeedback {
                            HighlightInformationCard(
                                title: stagedApprovalFeedback.title,
                                message: stagedApprovalFeedback.message,
                                supporting: stagedApprovalFeedback.supporting
                            )
                        }

                        if stagedReadyEntries.isEmpty == false {
                            ConciergeBatchReviewStagingPanel(
                                stagedCount: stagedReadyEntries.count,
                                approvedCount: approvedStagedEntries.count,
                                pendingCount: pendingStagedEntries.count,
                                additionalReadyCount: unstagedReadyEntries.count,
                                refreshHighlightedCount: refreshHighlightedStagedEntries.count,
                                notes: stagedReviewNotes,
                                isApplying: isApplying,
                                onApply: {
                                    applyStagedReadyBackups()
                                },
                                onApproveAllPending: pendingStagedEntries.isEmpty ? nil : {
                                    approveAllPendingStagedEntries()
                                },
                                onDefer: {
                                    deferStagedReadyBackups()
                                },
                                onClearAllRefreshHighlights: refreshHighlightedStagedEntries.isEmpty ? nil : {
                                    clearAllRefreshHighlights()
                                },
                                onApproveNote: { note in
                                    approveStagedEntry(id: note.id)
                                },
                                onClearRefreshHighlightNote: { note in
                                    clearRefreshHighlight(id: note.id)
                                },
                                onRemoveApproval: { note in
                                    removeStagedApproval(id: note.id)
                                },
                                onDeferNote: { note in
                                    deferStagedEntry(id: note.id)
                                }
                            )
                            .id(stagedReviewAnchorID)
                        }

                        if stagedReadyEntries.isEmpty == false {
                            ConciergeBatchReviewRankingFocusPanel(
                                readyCount: stagedReadyEntries.count,
                                onJump: {
                                    focusStagedReadyRows(using: proxy)
                                }
                            )
                        }

                        if let completionGuidance {
                            ConciergeBatchReviewCompletionGuidancePanel(
                                guidance: completionGuidance,
                                closeSafeRowsTitle: safeToCloseEntryIDs.isEmpty
                                    ? nil
                                    : (safeToCloseEntryIDs.count == 1 ? "Close 1 safe row" : "Close \(safeToCloseEntryIDs.count) safe rows"),
                                onCloseSafeRows: safeToCloseEntryIDs.isEmpty ? nil : {
                                    closeReviewEntries(ids: safeToCloseEntryIDs)
                                }
                            )
                        }

                        if let recoveryReadyMessage {
                            HighlightInformationCard(
                                title: "Recovery ready now",
                                message: recoveryReadyMessage,
                                supporting: "You can switch the ready provider rows immediately and let the remaining review rows keep updating afterward."
                            )
                        }

                        AdaptiveTagGrid(minimum: 150) {
                            MiniStatPanel(
                                title: "Selected",
                                value: "\(reviewEntries.count)",
                                subtitle: "Provider rows included in this review"
                            )
                            MiniStatPanel(
                                title: "Ready",
                                value: "\(readyEntries.count)",
                                subtitle: readyEntries.isEmpty
                                    ? "No ranked switches ready yet"
                                    : "Bookings ready to switch now"
                            )
                            MiniStatPanel(
                                title: "Manual",
                                value: "\(manualReviewEntries.count)",
                                subtitle: manualReviewEntries.isEmpty
                                    ? "No manual review blockers"
                                    : "Rows that still need manual review"
                            )
                            if loadingEntries.isEmpty == false {
                                MiniStatPanel(
                                    title: "Ranking",
                                    value: "\(loadingEntries.count)",
                                    subtitle: "Checking local backup options now"
                                )
                            }
                        }

                        if loadingEntries.isEmpty == false {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Ranking the strongest local backup for the remaining selected bookings now.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(BrandPalette.card)
                            )
                        }

                        ForEach(groupedReviewSections) { section in
                            let sectionActions = sectionActions(for: section)
                            VStack(alignment: .leading, spacing: 12) {
                                ConciergeBatchReviewNextActionSectionHeader(
                                    group: section.group,
                                    count: section.entries.count,
                                    actions: sectionActions,
                                    onAction: { action in
                                        handleSectionAction(action, for: section)
                                    }
                                )

                                ForEach(section.entries) { entry in
                                    ConciergeBatchReplacementReviewCard(
                                        entry: entry,
                                        isAutoFocused: focusedRecoveryEntryID == entry.id,
                                        isStaged: stagedReadyEntryIDs.contains(entry.id),
                                        suggestedAction: suggestedAction(for: entry),
                                        onSuggestedAction: {
                                            handleSuggestedAction(for: entry)
                                        }
                                    )
                                    .id(entry.id)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .onChange(of: rankingUpdateSummary?.id) { _, _ in
                    handleRankingUpdate(using: proxy)
                }
                .onChange(of: approvalRefreshCloseoutSummary?.id) { _, newValue in
                    guard newValue != nil else {
                        return
                    }

                    jumpToApprovalRefreshHandoff(using: proxy)
                }
            }
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if stagedReadyEntries.isEmpty == false {
                        Button(isApplying ? "Applying..." : stagedConfirmTitle) {
                            applyStagedReadyBackups()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandPalette.teal)
                        .disabled(approvedStagedEntries.isEmpty || isApplying)

                        if unstagedReadyEntries.isEmpty == false {
                            Button(unstagedConfirmTitle) {
                                applyUnstagedReadyBackups()
                            }
                            .buttonStyle(.bordered)
                            .tint(BrandPalette.teal)
                            .disabled(unstagedReadyEntries.isEmpty || isApplying)
                        }
                    } else {
                        Button(isApplying ? "Applying..." : confirmTitle) {
                            applyReadyBackupsNow()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandPalette.teal)
                        .disabled(readyEntries.isEmpty || isApplying)
                    }

                    if stagedReadyEntries.isEmpty == false {
                        Text("Approve the staged rows you trust, defer anything that should go back to the main queue, and only the approved mini-batch will apply.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if loadingEntries.isEmpty == false {
                        Text("Ready rows can switch now while the remaining review rows keep ranking in the background.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if groupedReviewSections.contains(where: { sectionActions(for: $0).isEmpty == false }) {
                        Text("Use each section action to clear similar work faster, then return here to finish anything still unresolved.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
                .task {
                    syncStagedReadyEntryIDs()
                    syncBookingLaneReactivationState()
                    await resolveMissingSuggestions()
                }
                .onChange(of: showsReactivatedBookingLane) { _, _ in
                    syncBookingLaneReactivationState()
                }
                .onChange(of: isBookingLaneHidden) { _, _ in
                    syncBookingLaneReactivationState()
                }
                .alert(item: $sectionActionAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func nextActionPlan(
        for entry: ConciergeBatchReplacementReviewEntry
    ) -> ConciergeBatchReviewNextActionPlan? {
        guard let booking = entry.currentBooking else {
            return ConciergeBatchReviewNextActionPlan(
                group: .closeNow,
                title: "No further action needed",
                supporting: "This provider row has already cleared from the active settled-archive booking, so you can dismiss it from the review now.",
                buttonTitle: "Close this row",
                tint: BrandPalette.teal,
                kind: .closeEntry
            )
        }

        if booking.isProviderConfirmed {
            return ConciergeBatchReviewNextActionPlan(
                group: .closeNow,
                title: "Safe to close for now",
                supporting: "The provider is already confirmed on this booking, so this row can leave the review unless a new issue appears.",
                buttonTitle: "Close this row",
                tint: BrandPalette.teal,
                kind: .closeEntry
            )
        }

        if let snoozedUntil = booking.reminderSnoozedUntil,
           snoozedUntil > .now,
           booking.needsResponseFollowUp == false,
           booking.hasOpenIssue == false {
            return ConciergeBatchReviewNextActionPlan(
                group: .closeNow,
                title: "Safe to close until the reminder returns",
                supporting: "This follow-up is snoozed until \(shortDateString(snoozedUntil)) at \(timeString(snoozedUntil)), so you do not need another action on this row right now.",
                buttonTitle: "Close this row",
                tint: BrandPalette.gold,
                kind: .closeEntry
            )
        }

        if entry.canApplySuggestedReplacement {
            return ConciergeBatchReviewNextActionPlan(
                group: .applyRankedBackup,
                title: "Apply this ranked backup now",
                supporting: "This row is ready to switch immediately, so you can apply the saved replacement without waiting for the full batch.",
                buttonTitle: "Apply this backup",
                tint: BrandPalette.teal,
                kind: .applySuggestedReplacement
            )
        }

        if entry.isLoadingSuggestion {
            return ConciergeBatchReviewNextActionPlan(
                group: .waitForRanking,
                title: "Let ranking finish",
                supporting: "Real O Who is still checking local backup options for this provider thread. Leave this row in the review until the ranked backup arrives.",
                buttonTitle: nil,
                tint: BrandPalette.sky,
                kind: nil
            )
        }

        switch conciergeAttentionPrimaryAction(for: booking) {
        case .switchProvider:
            return ConciergeBatchReviewNextActionPlan(
                group: .switchProvider,
                title: "Open replacement flow",
                supporting: "This row still needs a manual provider comparison before Real O Who can apply a safe switch.",
                buttonTitle: "Open replacement flow",
                tint: booking.hasOpenIssue ? BrandPalette.coral : BrandPalette.navy,
                kind: .openEntry
            )
        case .callProvider:
            if let snoozedUntil = booking.reminderSnoozedUntil,
               snoozedUntil > .now {
                return ConciergeBatchReviewNextActionPlan(
                    group: .followUp,
                    title: "Follow up after the snooze window",
                    supporting: "The reminder is already snoozed until \(shortDateString(snoozedUntil)) at \(timeString(snoozedUntil)). Open the booking if you need to act sooner.",
                    buttonTitle: "Open booking",
                    tint: BrandPalette.gold,
                    kind: .openEntry
                )
            }

            return ConciergeBatchReviewNextActionPlan(
                group: .followUp,
                title: "Open the booking to follow up",
                supporting: "This provider thread is overdue, so the next best move is to review the booking and log direct outreach from there.",
                buttonTitle: "Open booking",
                tint: BrandPalette.coral,
                kind: .openEntry
            )
        case .reviewBooking:
            return ConciergeBatchReviewNextActionPlan(
                group: .reviewBooking,
                title: "Review this booking",
                supporting: "Check the saved provider, timing, and reminder state before this row goes back through the queue.",
                buttonTitle: "Open booking",
                tint: BrandPalette.navy,
                kind: .openEntry
            )
        case .viewBooking:
            return ConciergeBatchReviewNextActionPlan(
                group: .reviewBooking,
                title: "View the current booking",
                supporting: "This provider is already confirmed, so a quick review is enough unless a new issue appears.",
                buttonTitle: "View booking",
                tint: BrandPalette.teal,
                kind: .openEntry
            )
        }
    }

    private func suggestedAction(
        for entry: ConciergeBatchReplacementReviewEntry
    ) -> ConciergeBatchReviewSuggestedAction? {
        guard let nextActionPlan = nextActionPlan(for: entry) else {
            return nil
        }

        return ConciergeBatchReviewSuggestedAction(
            title: nextActionPlan.title,
            supporting: nextActionPlan.supporting,
            buttonTitle: nextActionPlan.buttonTitle,
            tint: nextActionPlan.tint,
            kind: nextActionPlan.kind
        )
    }

    private func groupedEntries(
        for group: ConciergeBatchReviewNextActionGroup
    ) -> [ConciergeBatchReplacementReviewEntry] {
        reviewEntries
            .enumerated()
            .filter { nextActionPlan(for: $0.element)?.group == group }
            .sorted { lhs, rhs in
                let lhsPriority = reviewPriority(for: lhs.element, in: group)
                let rhsPriority = reviewPriority(for: rhs.element, in: group)
                if lhsPriority != rhsPriority {
                    return lhsPriority > rhsPriority
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func entries(
        matching ids: [String]
    ) -> [ConciergeBatchReplacementReviewEntry] {
        ids.compactMap { id in
            reviewEntries.first { $0.id == id }
        }
    }

    private var stagedConfirmTitle: String {
        let stagedCount = approvedStagedEntries.count
        if stagedCount == 0 {
            return "Approve staged backups to apply"
        }
        if stagedCount == 1 {
            return "Apply 1 approved staged backup"
        }
        return "Apply \(stagedCount) approved staged backups"
    }

    private var unstagedConfirmTitle: String {
        let readyCount = unstagedReadyEntries.count
        if readyCount == 1 {
            return "Apply 1 other ready backup"
        }
        return "Apply \(readyCount) other ready backups"
    }

    private func handleRankingUpdate(using proxy: ScrollViewProxy) {
        syncStagedReadyEntryIDs()

        guard let rankingUpdateSummary else {
            return
        }

        let newReadyIDs = rankingUpdateSummary.newlyReadyEntryIDs.filter { id in
            reviewEntries.contains(where: { $0.id == id && $0.canApplySuggestedReplacement })
        }
        guard newReadyIDs.isEmpty == false else {
            return
        }

        for id in newReadyIDs where stagedReadyEntryIDs.contains(id) == false {
            stagedReadyEntryIDs.append(id)
        }

        focusStagedReadyRows(using: proxy, preferredID: newReadyIDs.first)
    }

    private func focusStagedReadyRows(
        using proxy: ScrollViewProxy,
        preferredID: String? = nil
    ) {
        let currentStagedIDs = stagedReadyEntries.map(\.id)
        guard let firstReadyID = preferredID ?? currentStagedIDs.first,
              reviewEntries.contains(where: { $0.id == firstReadyID }) else {
            return
        }

        focusedRecoveryEntryID = firstReadyID
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(firstReadyID, anchor: .top)
        }
    }

    private func focusReviewEntry(
        id: String,
        using proxy: ScrollViewProxy
    ) {
        guard reviewEntries.contains(where: { $0.id == id }) else {
            return
        }

        focusedRecoveryEntryID = id
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(id, anchor: .top)
        }
    }

    private func syncStagedReadyEntryIDs() {
        let readyIDs = Set(readyEntries.map(\.id))
        stagedReadyEntryIDs = stagedReadyEntryIDs.filter { readyIDs.contains($0) }
        let stagedIDs = Set(stagedReadyEntryIDs)
        approvedStagedEntryFingerprints = approvedStagedEntryFingerprints.filter { stagedIDs.contains($0.key) }
        invalidatedStagedEntryIDs = conciergeBatchReviewInvalidatedStagedEntryIDs(
            entries: reviewEntries,
            stagedEntryIDs: stagedReadyEntryIDs,
            approvalFingerprints: approvedStagedEntryFingerprints
        )
        let invalidatedIDs = Set(invalidatedStagedEntryIDs)
        refreshHighlightedStagedEntryIDs = refreshHighlightedStagedEntryIDs.filter { id in
            guard stagedIDs.contains(id),
                  invalidatedIDs.contains(id) == false,
                  let entry = reviewEntries.first(where: { $0.id == id }),
                  let approvalFingerprint = approvedStagedEntryFingerprints[id] else {
                return false
            }

            return conciergeBatchReviewStagedApprovalFingerprint(for: entry) == approvalFingerprint
        }

        if let focusedRecoveryEntryID,
           reviewEntries.contains(where: { $0.id == focusedRecoveryEntryID }) == false {
            self.focusedRecoveryEntryID = nil
        }
    }

    private func reviewPriority(
        for entry: ConciergeBatchReplacementReviewEntry,
        in group: ConciergeBatchReviewNextActionGroup
    ) -> Int {
        var priority = 0

        if entry.rowChangeSummary?.marksRecoveryReady == true {
            priority += 4
        }

        if group == .applyRankedBackup && entry.canApplySuggestedReplacement {
            priority += 2
        }

        if entry.rowChangeSummary != nil {
            priority += 1
        }

        return priority
    }

    private func sectionActions(
        for section: ConciergeBatchReviewNextActionSection
    ) -> [ConciergeBatchReviewSectionAction] {
        switch section.group {
        case .applyRankedBackup:
            guard section.entries.contains(where: \.canApplySuggestedReplacement) else {
                return []
            }
            return [ConciergeBatchReviewSectionAction(
                title: section.entries.count == 1 ? "Apply row" : "Apply all",
                tint: BrandPalette.teal,
                kind: .applyAll
            )]
        case .closeNow:
            guard section.entries.isEmpty == false else {
                return []
            }
            return [ConciergeBatchReviewSectionAction(
                title: section.entries.count == 1 ? "Close row" : "Close all",
                tint: BrandPalette.teal,
                kind: .closeAll
            )]
        case .switchProvider:
            var actions: [ConciergeBatchReviewSectionAction] = []
            let escalationCount = section.entries.filter(canEscalateGroupedIssue).count
            if escalationCount > 0 {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: escalationCount == 1 ? "Log issue" : "Log all issues",
                        tint: BrandPalette.coral,
                        kind: .logIssueAll
                    )
                )
            }
            if section.entries.contains(where: { nextActionPlan(for: $0)?.kind == .openEntry }) {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: "Start first replacement",
                        tint: BrandPalette.coral,
                        kind: .openFirst
                    )
                )
            }
            return actions
        case .followUp:
            var actions: [ConciergeBatchReviewSectionAction] = []
            let followUpCount = section.entries.filter(canLogGroupedFollowUp).count
            if followUpCount > 0 {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: followUpCount == 1 ? "Log follow-up" : "Log all follow-ups",
                        tint: BrandPalette.gold,
                        kind: .logFollowUpAll
                    )
                )
            }
            let snoozeCount = section.entries.filter(canSnoozeGroupedReminder).count
            if snoozeCount > 0 {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: snoozeCount == 1 ? "Snooze 24h" : "Snooze all 24h",
                        tint: BrandPalette.gold,
                        kind: .snoozeAll
                    )
                )
            }
            let escalationCount = section.entries.filter(canEscalateGroupedIssue).count
            if escalationCount > 0 {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: escalationCount == 1 ? "Escalate issue" : "Escalate all issues",
                        tint: BrandPalette.coral,
                        kind: .logIssueAll
                    )
                )
            }
            return actions
        case .reviewBooking:
            var actions: [ConciergeBatchReviewSectionAction] = []
            let confirmCount = section.entries.filter(canConfirmGroupedProvider).count
            if confirmCount > 0 {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: confirmCount == 1 ? "Confirm ready" : "Confirm all ready",
                        tint: BrandPalette.teal,
                        kind: .confirmAll
                    )
                )
            }
            let snoozeCount = section.entries.filter(canSnoozeGroupedReminder).count
            if snoozeCount > 0 {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: snoozeCount == 1 ? "Snooze 24h" : "Snooze all 24h",
                        tint: BrandPalette.gold,
                        kind: .snoozeAll
                    )
                )
            }
            if actions.isEmpty,
               section.entries.contains(where: { nextActionPlan(for: $0)?.kind == .openEntry }) {
                actions.append(
                    ConciergeBatchReviewSectionAction(
                        title: "Open first booking",
                        tint: BrandPalette.navy,
                        kind: .openFirst
                    )
                )
            }
            return actions
        case .waitForRanking:
            return []
        }
    }

    private func canSnoozeGroupedReminder(_ entry: ConciergeBatchReplacementReviewEntry) -> Bool {
        guard let booking = entry.currentBooking else {
            return false
        }

        return booking.isCancelled == false &&
            booking.isCompleted == false &&
            booking.isProviderConfirmed == false &&
            booking.isReminderSnoozed == false &&
            (booking.needsResponseFollowUp || booking.isResponseDueSoon)
    }

    private func canConfirmGroupedProvider(_ entry: ConciergeBatchReplacementReviewEntry) -> Bool {
        guard let booking = entry.currentBooking else {
            return false
        }

        return booking.isCancelled == false &&
            booking.isCompleted == false &&
            booking.isProviderConfirmed == false
    }

    private func canEscalateGroupedIssue(_ entry: ConciergeBatchReplacementReviewEntry) -> Bool {
        guard let booking = entry.currentBooking else {
            return false
        }

        return booking.isCancelled == false &&
            booking.isCompleted == false &&
            booking.hasOpenIssue == false &&
            (booking.needsResponseFollowUp || booking.followUpCountValue >= 2)
    }

    private func handleSectionAction(
        _ action: ConciergeBatchReviewSectionAction,
        for section: ConciergeBatchReviewNextActionSection
    ) {
        switch action.kind {
        case .applyAll:
            let actionableEntries = section.entries.filter(\.canApplySuggestedReplacement)
            guard actionableEntries.isEmpty == false else {
                return
            }
            applyReadyBackups(actionableEntries)
        case .closeAll:
            closeReviewEntries(ids: section.entries.map(\.id))
        case .openFirst:
            guard let entry = section.entries.first(where: { nextActionPlan(for: $0)?.kind == .openEntry }) else {
                return
            }
            dismiss()
            onOpenEntry(entry, currentReturnContext)
        case .logFollowUpAll:
            performGroupedFollowUp(for: section.entries)
        case .snoozeAll:
            performGroupedSnooze(for: section.entries)
        case .confirmAll:
            performGroupedConfirm(for: section.entries)
        case .logIssueAll:
            performGroupedIssueEscalation(for: section.entries)
        }
    }

    private func applyReadyBackupsNow() {
        applyReadyBackups(readyEntries)
    }

    private func applyUnstagedReadyBackups() {
        applyReadyBackups(unstagedReadyEntries)
    }

    private func applyStagedReadyBackups() {
        guard approvedStagedEntries.isEmpty == false else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Approve a staged row first",
                message: "Approve at least one staged backup before applying the mini-batch, or defer the ones you do not want to switch right now."
            )
            return
        }

        applyReadyBackups(approvedStagedEntries)
    }

    private func applyReadyBackups(
        _ entries: [ConciergeBatchReplacementReviewEntry]
    ) {
        guard entries.isEmpty == false else {
            return
        }

        let appliedIDs = Set(entries.map(\.id))
        let appliedRefreshHighlightIDs = refreshHighlightedStagedEntryIDs.filter { appliedIDs.contains($0) }
        if appliedRefreshHighlightIDs.isEmpty == false {
            reviewedRefreshHighlightEntryIDs.removeAll { appliedIDs.contains($0) }
            for id in appliedRefreshHighlightIDs where appliedRefreshHighlightEntryIDs.contains(id) == false {
                appliedRefreshHighlightEntryIDs.append(id)
            }
        } else {
            let previouslyReviewedAppliedIDs = reviewedRefreshHighlightEntryIDs.filter { appliedIDs.contains($0) }
            if previouslyReviewedAppliedIDs.isEmpty == false {
                reviewedRefreshHighlightEntryIDs.removeAll { appliedIDs.contains($0) }
                for id in previouslyReviewedAppliedIDs where appliedRefreshHighlightEntryIDs.contains(id) == false {
                    appliedRefreshHighlightEntryIDs.append(id)
                }
            }
        }
        refreshHighlightedStagedEntryIDs.removeAll { appliedIDs.contains($0) }
        isApplying = true
        onConfirm(entries, currentReturnContext)
        dismiss()
    }

    private func deferStagedReadyBackups() {
        guard stagedReadyEntries.isEmpty == false else {
            return
        }

        let stagedIDs = Set(stagedReadyEntries.map(\.id))
        stagedReadyEntryIDs.removeAll { stagedIDs.contains($0) }
        for id in stagedIDs {
            approvedStagedEntryFingerprints.removeValue(forKey: id)
        }
        invalidatedStagedEntryIDs.removeAll { stagedIDs.contains($0) }
        refreshHighlightedStagedEntryIDs.removeAll { stagedIDs.contains($0) }
        if let focusedRecoveryEntryID, stagedIDs.contains(focusedRecoveryEntryID) {
            self.focusedRecoveryEntryID = nil
        }
    }

    private func approveAllPendingStagedEntries() {
        let pendingIDs = pendingStagedEntries.map(\.id)
        guard pendingIDs.isEmpty == false else {
            return
        }

        for id in pendingIDs {
            guard let entry = stagedReadyEntries.first(where: { $0.id == id }),
                  let approvalFingerprint = conciergeBatchReviewStagedApprovalFingerprint(for: entry) else {
                continue
            }

            approvedStagedEntryFingerprints[id] = approvalFingerprint
        }
        invalidatedStagedEntryIDs.removeAll { pendingIDs.contains($0) }
    }

    private func approveStagedEntry(id: String) {
        guard stagedReadyEntryIDs.contains(id),
              let entry = stagedReadyEntries.first(where: { $0.id == id }),
              let approvalFingerprint = conciergeBatchReviewStagedApprovalFingerprint(for: entry) else {
            return
        }

        approvedStagedEntryFingerprints[id] = approvalFingerprint
        invalidatedStagedEntryIDs.removeAll { $0 == id }
    }

    private func approveApprovalRefreshItems(_ ids: [String]) {
        let actionableIDs = Set(actionableApprovalRefreshItems.map(\.id))
        let uniqueIDs = Array(Set(ids)).filter { actionableIDs.contains($0) }
        guard uniqueIDs.isEmpty == false else {
            return
        }

        for id in uniqueIDs {
            approveStagedEntry(id: id)
        }
        for id in uniqueIDs where refreshHighlightedStagedEntryIDs.contains(id) == false {
            refreshHighlightedStagedEntryIDs.append(id)
        }

        let remainingActionableCount = actionableApprovalRefreshItems.count
        guard remainingActionableCount == 0 else {
            return
        }

        let pendingCount = pendingStagedEntries.count
        let approvedCount = approvedStagedEntries.count
        approvalRefreshCloseoutSummary = ConciergeBatchReviewApprovalRefreshCloseoutSummary(
            title: uniqueIDs.count == 1 ? "1 safe re-approval applied" : "\(uniqueIDs.count) safe re-approvals applied",
            message: {
                if pendingCount > 0 {
                    return "\(uniqueIDs.count) safe row\(uniqueIDs.count == 1 ? "" : "s") moved back into the approved staged set. \(pendingCount) staged row\(pendingCount == 1 ? " still needs" : "s still need") review below."
                }

                return "\(uniqueIDs.count) safe row\(uniqueIDs.count == 1 ? "" : "s") moved back into the approved staged set and the refresh summary has handed off to the live staged review."
            }(),
            supporting: approvedCount == 0
                ? "No approved staged rows are left right now."
                : "\(approvedCount) staged row\(approvedCount == 1 ? "" : "s") are now approved in the current mini-batch."
        )
        hasClosedApprovalRefreshSummary = true
        hasDismissedApprovalRefreshCloseoutSummary = false
    }

    private func jumpToApprovalRefreshHandoff(
        using proxy: ScrollViewProxy,
        dismissCloseoutAfterJump: Bool = false
    ) {
        guard stagedReadyEntries.isEmpty == false else {
            if dismissCloseoutAfterJump {
                hasDismissedApprovalRefreshCloseoutSummary = true
            }
            return
        }

        focusedRecoveryEntryID = approvedStagedEntries.first?.id ?? stagedReadyEntries.first?.id
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(stagedReviewAnchorID, anchor: .top)
        }

        if dismissCloseoutAfterJump {
            hasDismissedApprovalRefreshCloseoutSummary = true
        }
    }

    private func handleRefreshOutcomeItem(
        _ item: ConciergeBatchReviewRefreshOutcomeItem,
        using proxy: ScrollViewProxy
    ) {
        if item.action?.kind == .jumpToReviewRow {
            updateRefreshOutcomeJumpLaneProgress(
                selectedID: item.id,
                items: context.refreshSummary?.jumpItems ?? [item]
            )
        }
        if item.action?.kind == .openBooking {
            markRefreshOutcomeBookingVisited(item.id)
        }

        performRefreshOutcomeAction(item, using: proxy)
    }

    private func performRefreshOutcomeAction(
        _ item: ConciergeBatchReviewRefreshOutcomeItem,
        using proxy: ScrollViewProxy
    ) {
        guard let action = item.action else {
            return
        }

        switch action.kind {
        case .jumpToReviewRow:
            if reviewEntries.contains(where: { $0.id == item.id }) {
                focusReviewEntry(id: item.id, using: proxy)
            } else if let entryReference = item.entryReference {
                openRefreshOutcomeReference(entryReference)
            }
        case .openBooking:
            guard let entryReference = item.entryReference else {
                return
            }
            openRefreshOutcomeReference(entryReference)
        }
    }

    private func handleRefreshOutcomeJumpLane(
        _ items: [ConciergeBatchReviewRefreshOutcomeItem],
        using proxy: ScrollViewProxy
    ) {
        guard let targetItem = nextRefreshOutcomeJumpLaneItem(from: items) else {
            return
        }

        updateRefreshOutcomeJumpLaneProgress(
            selectedID: targetItem.id,
            items: items
        )
        performRefreshOutcomeAction(targetItem, using: proxy)
    }

    private func handleRefreshOutcomeBookingLane(
        _ items: [ConciergeBatchReviewRefreshOutcomeItem],
        using proxy: ScrollViewProxy
    ) {
        guard let targetItem = nextRefreshOutcomeBookingLaneItem(from: items) else {
            return
        }

        handleRefreshOutcomeItem(targetItem, using: proxy)
    }

    private func nextRefreshOutcomeJumpLaneItem(
        from items: [ConciergeBatchReviewRefreshOutcomeItem]
    ) -> ConciergeBatchReviewRefreshOutcomeItem? {
        let actionableItems = items.filter { item in
            reviewEntries.contains(where: { $0.id == item.id }) || item.entryReference != nil
        }
        guard actionableItems.isEmpty == false else {
            return nil
        }

        guard let currentID = refreshOutcomeJumpLaneProgress?.lastItemID,
              let currentIndex = actionableItems.firstIndex(where: { $0.id == currentID }),
              actionableItems.count > 1 else {
            return actionableItems.first
        }

        return actionableItems[(currentIndex + 1) % actionableItems.count]
    }

    private func updateRefreshOutcomeJumpLaneProgress(
        selectedID: String,
        items: [ConciergeBatchReviewRefreshOutcomeItem]
    ) {
        refreshOutcomeJumpLaneProgress = conciergeBatchReviewRefreshLaneProgress(
            selectedID: selectedID,
            items: items
        )
    }

    private func nextRefreshOutcomeBookingLaneItem(
        from items: [ConciergeBatchReviewRefreshOutcomeItem]
    ) -> ConciergeBatchReviewRefreshOutcomeItem? {
        let actionableItems = items.filter { $0.entryReference != nil }
        guard actionableItems.isEmpty == false else {
            return nil
        }

        let visitedIDs = Set(visitedRefreshBookingEntryIDs)
        if let firstUnvisitedItem = actionableItems.first(where: { visitedIDs.contains($0.id) == false }) {
            return firstUnvisitedItem
        }

        guard let currentID = bookingLaneProgress?.lastItemID,
              let currentIndex = actionableItems.firstIndex(where: { $0.id == currentID }),
              actionableItems.count > 1 else {
            return actionableItems.first
        }

        return actionableItems[(currentIndex + 1) % actionableItems.count]
    }

    private func markRefreshOutcomeBookingVisited(_ id: String) {
        visitedRefreshBookingEntryIDs.removeAll { $0 == id }
        visitedRefreshBookingEntryIDs.append(id)
    }

    private func hideCompletedRefreshBookingLane() {
        guard bookingLaneProgress?.remainingCount == 0 else {
            return
        }

        hasHiddenCompletedBookingLane = true
        hasActiveBookingLaneReactivation = false
        hasDismissedBookingLaneReactivationCompletion = false
        reactivatedRefreshBookingEntryIDs.removeAll()
        reactivationCompletionReviewLastItemID = nil
        reviewedReactivationCompletionItemIDs.removeAll()
    }

    private func restoreRefreshBookingLane() {
        hasHiddenCompletedBookingLane = false
    }

    private func hideCompletedRefreshBookingLaneAfterReactivation() {
        hideCompletedRefreshBookingLane()
    }

    private func dismissBookingLaneReactivationCompletion() {
        hasDismissedBookingLaneReactivationCompletion = true
    }

    private func reviewNextClearedReactivationBooking(using proxy: ScrollViewProxy) {
        guard let nextItem = nextReactivationCompletionReviewItem() else {
            return
        }

        if reviewedReactivationCompletionItemIDs.contains(nextItem.id) == false {
            reviewedReactivationCompletionItemIDs.append(nextItem.id)
        }
        reactivationCompletionReviewLastItemID = nextItem.id
        handleRefreshOutcomeItem(nextItem, using: proxy)
    }

    private func syncBookingLaneReactivationState() {
        let currentOutstandingIDs = context.refreshSummary?.bookingItems
            .filter { visitedRefreshBookingEntryIDs.contains($0.id) == false }
            .map(\.id) ?? []

        if showsReactivatedBookingLane {
            for id in currentOutstandingIDs where reactivatedRefreshBookingEntryIDs.contains(id) == false {
                reactivatedRefreshBookingEntryIDs.append(id)
            }
            hasActiveBookingLaneReactivation = true
            hasDismissedBookingLaneReactivationCompletion = false
            reactivationCompletionReviewLastItemID = nil
            reviewedReactivationCompletionItemIDs.removeAll()
        } else if isBookingLaneHidden {
            hasActiveBookingLaneReactivation = false
            hasDismissedBookingLaneReactivationCompletion = false
            reactivatedRefreshBookingEntryIDs.removeAll()
            reactivationCompletionReviewLastItemID = nil
            reviewedReactivationCompletionItemIDs.removeAll()
        }
    }

    private func nextReactivationCompletionReviewItem() -> ConciergeBatchReviewRefreshOutcomeItem? {
        pendingReactivationCompletionReviewItems.first
    }

    private func openRefreshOutcomeReference(
        _ reference: ConciergeBatchReviewEntryReference
    ) {
        if let activeEntry = reviewEntries.first(where: { $0.id == reference.id }) {
            dismiss()
            onOpenEntry(activeEntry, currentReturnContext)
            return
        }

        let currentBooking = store.offer(id: reference.offerID)?.conciergeBooking(for: reference.serviceKind)
        let reviewFingerprint = currentBooking.map {
            conciergeReplacementPreviewFingerprint(
                for: $0,
                strategy: context.strategy
            )
        }
        let entry = ConciergeBatchReplacementReviewEntry(
            id: reference.id,
            offerID: reference.offerID,
            listing: reference.listing,
            serviceKind: reference.serviceKind,
            counterpartLabel: reference.counterpartLabel,
            counterpartName: reference.counterpartName,
            currentBooking: currentBooking,
            reviewFingerprint: reviewFingerprint,
            suggestedReplacement: nil,
            isLoadingSuggestion: false,
            manualReviewReason: currentBooking == nil
                ? "This concierge booking is no longer available in the settled archive."
                : nil
        )

        dismiss()
        onOpenEntry(entry, currentReturnContext)
    }

    private func clearAllRefreshHighlights() {
        guard refreshHighlightedStagedEntryIDs.isEmpty == false else {
            return
        }

        for id in refreshHighlightedStagedEntryIDs where reviewedRefreshHighlightEntryIDs.contains(id) == false {
            reviewedRefreshHighlightEntryIDs.append(id)
        }
        refreshHighlightedStagedEntryIDs.removeAll()
    }

    private func clearRefreshHighlight(id: String) {
        guard refreshHighlightedStagedEntryIDs.contains(id) else {
            return
        }

        if reviewedRefreshHighlightEntryIDs.contains(id) == false {
            reviewedRefreshHighlightEntryIDs.append(id)
        }
        refreshHighlightedStagedEntryIDs.removeAll { $0 == id }
    }

    private func removeStagedApproval(id: String) {
        approvedStagedEntryFingerprints.removeValue(forKey: id)
        invalidatedStagedEntryIDs.removeAll { $0 == id }
        refreshHighlightedStagedEntryIDs.removeAll { $0 == id }
    }

    private func deferStagedEntry(id: String) {
        stagedReadyEntryIDs.removeAll { $0 == id }
        approvedStagedEntryFingerprints.removeValue(forKey: id)
        invalidatedStagedEntryIDs.removeAll { $0 == id }
        refreshHighlightedStagedEntryIDs.removeAll { $0 == id }
        if focusedRecoveryEntryID == id {
            focusedRecoveryEntryID = stagedReadyEntries.first(where: { $0.id != id })?.id
        }
    }

    private func handleSuggestedAction(
        for entry: ConciergeBatchReplacementReviewEntry
    ) {
        guard let suggestedAction = suggestedAction(for: entry),
              let kind = suggestedAction.kind else {
            return
        }

        switch kind {
        case .applySuggestedReplacement:
            applyReadyBackups([entry])
        case .closeEntry:
            closeReviewEntries(ids: [entry.id])
        case .openEntry:
            dismiss()
            onOpenEntry(entry, currentReturnContext)
        }
    }

    private func canLogGroupedFollowUp(_ entry: ConciergeBatchReplacementReviewEntry) -> Bool {
        guard let booking = entry.currentBooking else {
            return false
        }

        return conciergeAttentionPrimaryAction(for: booking) == .callProvider
    }

    private func performGroupedFollowUp(
        for entries: [ConciergeBatchReplacementReviewEntry]
    ) {
        let actionableEntries = entries.filter(canLogGroupedFollowUp)
        guard actionableEntries.isEmpty == false else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Nothing to log",
                message: "Those provider rows no longer need direct follow-up from this review."
            )
            return
        }

        var successCount = 0
        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: actionableEntries.map { ($0.id, conciergeBatchReviewRowSnapshot(for: $0)) }
        )

        for entry in actionableEntries {
            guard let outcome = store.logPostSaleConciergeFollowUp(
                offerID: entry.offerID,
                userID: store.currentUserID,
                serviceKind: entry.serviceKind,
                note: ""
            ) else {
                continue
            }

            if let counterpart = counterpart(for: entry) {
                messaging.sendMessage(
                    listing: entry.listing,
                    from: store.currentUser,
                    to: counterpart,
                    body: outcome.threadMessage,
                    isSystem: true
                )
            }

            successCount += 1
        }

        guard successCount > 0 else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Follow-up unavailable",
                message: "Those provider rows changed before the grouped action ran, so no follow-up was logged."
            )
            return
        }

        refreshReviewEntries(
            ids: actionableEntries.map(\.id),
            previousSnapshotsByID: previousSnapshotsByID
        )

        sectionActionAlert = ConciergeBatchReviewStatusAlert(
            title: successCount == 1 ? "Follow-up logged" : "Grouped follow-up complete",
            message: successCount == 1
                ? "Logged direct provider follow-up for 1 concierge row and refreshed the review."
                : "Logged direct provider follow-up for \(successCount) concierge rows and refreshed the review."
        )
    }

    private func performGroupedSnooze(
        for entries: [ConciergeBatchReplacementReviewEntry]
    ) {
        let actionableEntries = entries.filter(canSnoozeGroupedReminder)
        guard actionableEntries.isEmpty == false else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Nothing to snooze",
                message: "Those provider rows are no longer in a state that can be snoozed from this review."
            )
            return
        }

        let snoozeUntil = Date().addingTimeInterval(60 * 60 * 24)
        var successCount = 0
        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: actionableEntries.map { ($0.id, conciergeBatchReviewRowSnapshot(for: $0)) }
        )

        for entry in actionableEntries {
            guard let outcome = store.snoozePostSaleConciergeFollowUp(
                offerID: entry.offerID,
                userID: store.currentUserID,
                serviceKind: entry.serviceKind,
                until: snoozeUntil
            ) else {
                continue
            }

            if let counterpart = counterpart(for: entry) {
                messaging.sendMessage(
                    listing: entry.listing,
                    from: store.currentUser,
                    to: counterpart,
                    body: outcome.threadMessage,
                    isSystem: true
                )
            }

            successCount += 1
        }

        guard successCount > 0 else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Snooze unavailable",
                message: "Those provider rows changed before the grouped snooze ran, so nothing was updated."
            )
            return
        }

        refreshReviewEntries(
            ids: actionableEntries.map(\.id),
            previousSnapshotsByID: previousSnapshotsByID
        )

        sectionActionAlert = ConciergeBatchReviewStatusAlert(
            title: successCount == 1 ? "Reminder snoozed" : "Grouped snooze complete",
            message: successCount == 1
                ? "Snoozed 1 concierge reminder for 24 hours and refreshed the review."
                : "Snoozed \(successCount) concierge reminders for 24 hours and refreshed the review."
        )
    }

    private func performGroupedConfirm(
        for entries: [ConciergeBatchReplacementReviewEntry]
    ) {
        let actionableEntries = entries.filter(canConfirmGroupedProvider)
        guard actionableEntries.isEmpty == false else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Nothing to confirm",
                message: "Those provider rows are no longer ready to be marked confirmed from this review."
            )
            return
        }

        var successCount = 0
        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: actionableEntries.map { ($0.id, conciergeBatchReviewRowSnapshot(for: $0)) }
        )

        for entry in actionableEntries {
            guard let outcome = store.confirmPostSaleConciergeProvider(
                offerID: entry.offerID,
                userID: store.currentUserID,
                serviceKind: entry.serviceKind,
                note: ""
            ) else {
                continue
            }

            if let counterpart = counterpart(for: entry) {
                messaging.sendMessage(
                    listing: entry.listing,
                    from: store.currentUser,
                    to: counterpart,
                    body: outcome.threadMessage,
                    isSystem: true
                )
            }

            successCount += 1
        }

        guard successCount > 0 else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Confirmation unavailable",
                message: "Those provider rows changed before the grouped confirm ran, so nothing was updated."
            )
            return
        }

        refreshReviewEntries(
            ids: actionableEntries.map(\.id),
            previousSnapshotsByID: previousSnapshotsByID
        )

        sectionActionAlert = ConciergeBatchReviewStatusAlert(
            title: successCount == 1 ? "Provider confirmed" : "Grouped confirm complete",
            message: successCount == 1
                ? "Marked 1 provider confirmed and refreshed the review."
                : "Marked \(successCount) providers confirmed and refreshed the review."
        )
    }

    private func performGroupedIssueEscalation(
        for entries: [ConciergeBatchReplacementReviewEntry]
    ) {
        let actionableEntries = entries.filter(canEscalateGroupedIssue)
        guard actionableEntries.isEmpty == false else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Nothing to escalate",
                message: "Those provider rows no longer need an issue logged from this review."
            )
            return
        }

        var successCount = 0
        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: actionableEntries.map { ($0.id, conciergeBatchReviewRowSnapshot(for: $0)) }
        )

        for entry in actionableEntries {
            guard let booking = entry.currentBooking,
                  let outcome = store.logPostSaleConciergeIssue(
                    offerID: entry.offerID,
                    userID: store.currentUserID,
                    serviceKind: entry.serviceKind,
                    issueKind: groupedEscalationIssueKind(for: booking),
                    note: groupedEscalationIssueNote(for: entry, booking: booking)
                  ) else {
                continue
            }

            if let counterpart = counterpart(for: entry) {
                messaging.sendMessage(
                    listing: entry.listing,
                    from: store.currentUser,
                    to: counterpart,
                    body: outcome.threadMessage,
                    isSystem: true
                )
            }

            successCount += 1
        }

        guard successCount > 0 else {
            sectionActionAlert = ConciergeBatchReviewStatusAlert(
                title: "Escalation unavailable",
                message: "Those provider rows changed before the grouped issue log ran, so nothing was updated."
            )
            return
        }

        refreshReviewEntries(
            ids: actionableEntries.map(\.id),
            previousSnapshotsByID: previousSnapshotsByID
        )

        sectionActionAlert = ConciergeBatchReviewStatusAlert(
            title: successCount == 1 ? "Issue logged" : "Grouped escalation complete",
            message: successCount == 1
                ? "Logged 1 concierge issue and refreshed the review into the latest escalation state."
                : "Logged \(successCount) concierge issues and refreshed the review into the latest escalation state."
        )
    }

    private func groupedEscalationIssueKind(
        for booking: PostSaleConciergeBooking
    ) -> PostSaleConciergeIssueKind {
        if booking.scheduledFor <= .now {
            return .providerNoShow
        }

        return .schedulingProblem
    }

    private func groupedEscalationIssueNote(
        for entry: ConciergeBatchReplacementReviewEntry,
        booking: PostSaleConciergeBooking
    ) -> String {
        if booking.scheduledFor <= .now {
            return "Escalated from \(context.hubTitle) batch review after the scheduled service window passed without provider confirmation."
        }

        if booking.followUpCountValue >= 2 {
            return "Escalated from \(context.hubTitle) batch review after repeated unanswered provider follow-up."
        }

        return "Escalated from \(context.hubTitle) batch review after the provider reply window was missed."
    }

    private func counterpart(
        for entry: ConciergeBatchReplacementReviewEntry
    ) -> UserProfile? {
        guard let offer = store.offer(id: entry.offerID) else {
            return nil
        }

        let counterpartID = offer.buyerID == store.currentUserID ? offer.sellerID : offer.buyerID
        return store.user(id: counterpartID)
    }

    private func refreshReviewEntries(
        ids: [String],
        previousSnapshotsByID: [String: ConciergeBatchReviewRowSnapshot]
    ) {
        let idSet = Set(ids)
        guard idSet.isEmpty == false else {
            return
        }

        reviewEntries = reviewEntries.map { entry in
            guard idSet.contains(entry.id) else {
                return entry
            }

            var refreshedEntry = refreshedReviewEntry(from: entry)
            if let previousSnapshot = previousSnapshotsByID[entry.id] {
                refreshedEntry.rowChangeSummary = conciergeBatchReviewRowChangeSummary(
                    previousSnapshot: previousSnapshot,
                    refreshedEntry: refreshedEntry
                )
            }
            return refreshedEntry
        }

        syncStagedReadyEntryIDs()

        if reviewEntries.contains(where: \.isLoadingSuggestion) {
            Task {
                await resolveMissingSuggestions()
            }
        }
    }

    private func refreshedReviewEntry(
        from entry: ConciergeBatchReplacementReviewEntry
    ) -> ConciergeBatchReplacementReviewEntry {
        guard let offer = store.offer(id: entry.offerID) else {
            return ConciergeBatchReplacementReviewEntry(
                id: entry.id,
                offerID: entry.offerID,
                listing: entry.listing,
                serviceKind: entry.serviceKind,
                counterpartLabel: entry.counterpartLabel,
                counterpartName: entry.counterpartName,
                currentBooking: nil,
                reviewFingerprint: nil,
                suggestedReplacement: nil,
                isLoadingSuggestion: false,
                manualReviewReason: "This concierge booking is no longer available in the settled archive."
            )
        }

        let booking = offer.conciergeBooking(for: entry.serviceKind)
        let fingerprint = booking.map {
            conciergeReplacementPreviewFingerprint(
                for: $0,
                strategy: context.strategy
            )
        }

        let suggestion: ConciergeReplacementSuggestion?
        let manualReviewReason: String?
        let isLoadingSuggestion: Bool

        if let booking {
            if conciergeAttentionPrimaryAction(for: booking) != .switchProvider {
                suggestion = nil
                manualReviewReason = "This provider thread is not currently in switch-provider mode, so it still needs manual review from the booking."
                isLoadingSuggestion = false
            } else if entry.reviewFingerprint == fingerprint, entry.suggestedReplacement != nil {
                suggestion = entry.suggestedReplacement
                manualReviewReason = nil
                isLoadingSuggestion = false
            } else {
                suggestion = nil
                manualReviewReason = nil
                isLoadingSuggestion = true
            }
        } else {
            suggestion = nil
            manualReviewReason = "This concierge booking is no longer available in the settled archive."
            isLoadingSuggestion = false
        }

        return ConciergeBatchReplacementReviewEntry(
            id: entry.id,
            offerID: entry.offerID,
            listing: entry.listing,
            serviceKind: entry.serviceKind,
            counterpartLabel: entry.counterpartLabel,
            counterpartName: entry.counterpartName,
            currentBooking: booking,
            reviewFingerprint: fingerprint,
            suggestedReplacement: suggestion,
            isLoadingSuggestion: isLoadingSuggestion,
            manualReviewReason: manualReviewReason
        )
    }

    private func closeReviewEntries(ids: [String]) {
        let idSet = Set(ids)
        guard idSet.isEmpty == false else {
            return
        }

        let remainingEntries = reviewEntries.filter { idSet.contains($0.id) == false }
        let closedIDs = reviewEntries
            .map(\.id)
            .filter { idSet.contains($0) }

        guard closedIDs.isEmpty == false else {
            return
        }

        reviewEntries = remainingEntries
        syncStagedReadyEntryIDs()
        if let focusedRecoveryEntryID, idSet.contains(focusedRecoveryEntryID) {
            self.focusedRecoveryEntryID = nil
        }
        onCloseEntries(closedIDs, remainingEntries.count)

        if remainingEntries.isEmpty {
            dismiss()
        }
    }

    @MainActor
    private func resolveMissingSuggestions() async {
        let pendingIndices = reviewEntries.indices.filter {
            reviewEntries[$0].isLoadingSuggestion && reviewEntries[$0].currentBooking != nil
        }
        guard pendingIndices.isEmpty == false, isResolvingMissingSuggestions == false else {
            return
        }

        isResolvingMissingSuggestions = true
        defer { isResolvingMissingSuggestions = false }

        let previousSnapshotsByID = Dictionary(
            uniqueKeysWithValues: pendingIndices.map { index in
                (reviewEntries[index].id, conciergeBatchReviewRowSnapshot(for: reviewEntries[index]))
            }
        )
        var resolvedIDs: [String] = []

        for index in pendingIndices {
            guard let booking = reviewEntries[index].currentBooking else {
                reviewEntries[index].isLoadingSuggestion = false
                reviewEntries[index].manualReviewReason = "This concierge booking is no longer available in the settled archive."
                if let previousSnapshot = previousSnapshotsByID[reviewEntries[index].id] {
                    reviewEntries[index].rowChangeSummary = conciergeBatchReviewRowChangeSummary(
                        previousSnapshot: previousSnapshot,
                        refreshedEntry: reviewEntries[index]
                    )
                }
                resolvedIDs.append(reviewEntries[index].id)
                continue
            }

            do {
                let providers = try await store.searchPostSaleConciergeProviders(
                    for: reviewEntries[index].listing,
                    serviceKind: reviewEntries[index].serviceKind
                )
                let rankedProviders = rankedConciergeReplacementProviders(
                    for: booking,
                    listing: reviewEntries[index].listing,
                    candidates: providers,
                    strategy: context.strategy
                )

                if let bestProvider = rankedProviders.first {
                    reviewEntries[index].suggestedReplacement = conciergeReplacementSuggestion(
                        for: bestProvider,
                        currentBooking: booking,
                        listing: reviewEntries[index].listing,
                        rankedCandidates: rankedProviders,
                        strategy: context.strategy
                    )
                    reviewEntries[index].manualReviewReason = nil
                } else {
                    reviewEntries[index].manualReviewReason = "No ranked backup is available yet for this booking, so it still needs manual review."
                }
            } catch {
                reviewEntries[index].manualReviewReason = "Could not rank local backups right now. Review this booking manually before switching providers."
            }

            reviewEntries[index].isLoadingSuggestion = false
            if let previousSnapshot = previousSnapshotsByID[reviewEntries[index].id] {
                reviewEntries[index].rowChangeSummary = conciergeBatchReviewRowChangeSummary(
                    previousSnapshot: previousSnapshot,
                    refreshedEntry: reviewEntries[index]
                )
            }
            resolvedIDs.append(reviewEntries[index].id)
        }

        let resolvedEntries = reviewEntries.filter { resolvedIDs.contains($0.id) }
        rankingUpdateSummary = conciergeBatchReviewRankingUpdateSummary(
            hubTitle: context.hubTitle,
            resolvedEntries: resolvedEntries,
            previousSnapshotsByID: previousSnapshotsByID,
            remainingLoadingCount: reviewEntries.filter(\.isLoadingSuggestion).count
        )

        if reviewEntries.contains(where: \.isLoadingSuggestion) {
            Task {
                await resolveMissingSuggestions()
            }
        }
    }
}

private struct ConciergeBatchReplacementReviewCard: View {
    let entry: ConciergeBatchReplacementReviewEntry
    var isAutoFocused = false
    var isStaged = false
    var suggestedAction: ConciergeBatchReviewSuggestedAction? = nil
    var onSuggestedAction: (() -> Void)? = nil

    private var notesSummary: String {
        guard let booking = entry.currentBooking else {
            return "No active notes on file"
        }

        return booking.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No active notes on file"
            : "Notes will carry forward"
    }

    private var scheduledSummary: String? {
        guard let booking = entry.currentBooking else {
            return nil
        }

        return "\(shortDateString(booking.scheduledFor)) at \(timeString(booking.scheduledFor))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(BrandPalette.teal.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: entry.serviceKind.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BrandPalette.teal)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.serviceKind.title)
                        .font(.subheadline.weight(.bold))
                    Text(entry.listing.title)
                        .font(.headline)
                    Text(entry.listing.address.fullLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(entry.counterpartLabel): \(entry.counterpartName)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrandPalette.teal)
                }

                Spacer(minLength: 0)
            }

            AdaptiveTagGrid(minimum: 130) {
                if let scheduledSummary {
                    InfoPill(label: scheduledSummary)
                }
                InfoPill(label: notesSummary)
                if isStaged {
                    InfoPill(label: "Staged now")
                }
                if entry.rowChangeSummary?.marksRecoveryReady == true {
                    InfoPill(label: "Just became ready")
                }
                if let booking = entry.currentBooking,
                   let estimatedCost = booking.estimatedCost {
                    InfoPill(label: "Quote \(currencyString(estimatedCost))")
                }
            }

            if let rowChangeSummary = entry.rowChangeSummary {
                ConciergeBatchReviewRowChangePanel(summary: rowChangeSummary)
            }

            if let suggestedAction {
                ConciergeBatchReviewSuggestedActionPanel(
                    action: suggestedAction,
                    onAction: onSuggestedAction
                )
            }

            if let currentProvider = entry.currentProvider {
                if let suggestedReplacement = entry.suggestedReplacement {
                    HStack(alignment: .top, spacing: 12) {
                        ConciergeQueueProviderSnapshot(
                            title: "Current",
                            provider: currentProvider,
                            accent: BrandPalette.navy
                        )

                        ConciergeQueueProviderSnapshot(
                            title: "Backup",
                            provider: suggestedReplacement.provider,
                            accent: BrandPalette.teal
                        )
                    }

                    ConciergeReplacementSafetyPanel(
                        summary: suggestedReplacement.safetySummary,
                        compact: true
                    )

                    ConciergeReplacementImpactPanel(
                        summary: suggestedReplacement.impactSummary,
                        compact: true
                    )
                } else {
                    ConciergeQueueProviderSnapshot(
                        title: "Current",
                        provider: currentProvider,
                        accent: BrandPalette.navy
                    )
                }
            }

            if entry.isLoadingSuggestion {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Ranking the best backup for this booking now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let reason = entry.manualReviewReason {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(BrandPalette.coral.opacity(0.14))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BrandPalette.coral)
                        }

                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandPalette.coral.opacity(0.08))
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrandPalette.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isAutoFocused
                        ? BrandPalette.teal.opacity(0.9)
                        : (isStaged ? BrandPalette.teal.opacity(0.45) : .clear),
                    lineWidth: isAutoFocused ? 2.5 : (isStaged ? 1.5 : 0)
                )
        }
        .shadow(
            color: isAutoFocused ? BrandPalette.teal.opacity(0.18) : .clear,
            radius: isAutoFocused ? 18 : 0,
            x: 0,
            y: isAutoFocused ? 8 : 0
        )
    }
}

private struct ConciergeBatchReviewStagingPanel: View {
    let stagedCount: Int
    let approvedCount: Int
    let pendingCount: Int
    let additionalReadyCount: Int
    let refreshHighlightedCount: Int
    let notes: [ConciergeBatchReviewStagedNote]
    let isApplying: Bool
    let onApply: () -> Void
    var onApproveAllPending: (() -> Void)? = nil
    let onDefer: () -> Void
    var onClearAllRefreshHighlights: (() -> Void)? = nil
    var onApproveNote: ((ConciergeBatchReviewStagedNote) -> Void)? = nil
    var onClearRefreshHighlightNote: ((ConciergeBatchReviewStagedNote) -> Void)? = nil
    var onRemoveApproval: ((ConciergeBatchReviewStagedNote) -> Void)? = nil
    var onDeferNote: ((ConciergeBatchReviewStagedNote) -> Void)? = nil

    private var approvedNotes: [ConciergeBatchReviewStagedNote] {
        notes.filter(\.isApproved)
    }

    private var pendingNotes: [ConciergeBatchReviewStagedNote] {
        notes.filter { $0.isApproved == false }
    }

    private var refreshHighlightedNotes: [ConciergeBatchReviewStagedNote] {
        notes.filter(\.isRefreshHighlighted)
    }

    private var approvedPreviewLines: [String] {
        approvedNotes.prefix(3).map { note in
            "\(note.title): \(note.afterLine)"
        }
    }

    private var pendingPreviewLines: [String] {
        pendingNotes.prefix(3).map { note in
            if note.isInvalidated {
                return "\(note.title): Approval cleared because the booking or ranked backup changed, so this row needs a quick recheck."
            }

            return "\(note.title): This row stays out of the staged mini-batch until you approve it or defer it back into the main queue."
        }
    }

    private var refreshHighlightPreviewLines: [String] {
        refreshHighlightedNotes.prefix(3).map { note in
            "\(note.title): Re-approved from the refresh summary and handed back into the staged mini-batch."
        }
    }

    private var title: String {
        stagedCount == 1 ? "1 freshly ranked backup is staged" : "\(stagedCount) freshly ranked backups are staged"
    }

    private var message: String {
        if approvedCount == 0 {
            return "Approve the staged rows you trust before Real O Who applies this mini-batch, or defer any row that should fall back into the main ready queue."
        }

        if pendingCount > 0, additionalReadyCount > 0 {
            return "\(approvedCount) staged row\(approvedCount == 1 ? "" : "s") are approved to switch now, \(pendingCount) still need a decision, and \(additionalReadyCount) other ready booking\(additionalReadyCount == 1 ? "" : "s") remain outside this staged mini-batch."
        }

        if pendingCount > 0 {
            return "\(approvedCount) staged row\(approvedCount == 1 ? "" : "s") are approved to switch now, and \(pendingCount) still need to be approved or deferred."
        }

        if additionalReadyCount > 0 {
            return "Apply the approved staged rows now, or defer them into the broader ready queue with the other \(additionalReadyCount) ready booking\(additionalReadyCount == 1 ? "" : "s")."
        }

        return "These newly ready rows are approved and ready to apply as their own mini-batch."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(message)
                .foregroundStyle(.secondary)

            AdaptiveTagGrid(minimum: 130) {
                MiniStatPanel(
                    title: "Approved",
                    value: "\(approvedCount)",
                    subtitle: approvedCount == 0 ? "No staged rows approved yet" : "Ready for staged apply"
                )
                MiniStatPanel(
                    title: "Pending",
                    value: "\(pendingCount)",
                    subtitle: pendingCount == 0 ? "No staged decisions left" : "Still need approval or deferral"
                )
                if refreshHighlightedCount > 0 {
                    MiniStatPanel(
                        title: "Refreshed",
                        value: "\(refreshHighlightedCount)",
                        subtitle: refreshHighlightedCount == 1
                            ? "Just re-approved from refresh"
                            : "Just re-approved from refresh"
                    )
                }
            }

            if refreshHighlightedNotes.isEmpty == false {
                ConciergeBatchReviewStagedDecisionLane(
                    title: refreshHighlightedCount == 1
                        ? "1 row just came back from refresh"
                        : "\(refreshHighlightedCount) rows just came back from refresh",
                    message: "These staged rows were re-approved from the reopen summary and handed back into the live mini-batch. The extra cue steps down automatically once you apply them or mark them reviewed here.",
                    lines: refreshHighlightPreviewLines,
                    tint: BrandPalette.teal
                )

                if let onClearAllRefreshHighlights {
                    HStack {
                        Spacer(minLength: 0)

                        Button(refreshHighlightedCount == 1 ? "Mark refreshed row reviewed" : "Mark refreshed rows reviewed") {
                            onClearAllRefreshHighlights()
                        }
                        .buttonStyle(.bordered)
                        .tint(BrandPalette.teal)
                    }
                }
            }

            if approvedNotes.isEmpty == false {
                ConciergeBatchReviewStagedDecisionLane(
                    title: approvedCount == 1 ? "1 row will apply now" : "\(approvedCount) rows will apply now",
                    message: approvedCount == 1
                        ? "This approved backup is already included in the staged mini-batch."
                        : "These approved backups are already included in the staged mini-batch.",
                    lines: approvedPreviewLines,
                    tint: BrandPalette.teal
                )
            }

            if pendingNotes.isEmpty == false {
                ConciergeBatchReviewStagedDecisionLane(
                    title: pendingCount == 1 ? "1 row is still waiting on your decision" : "\(pendingCount) rows are still waiting on your decision",
                    message: "Pending rows stay out of the staged apply until you approve them or defer them into the broader ready queue.",
                    lines: pendingPreviewLines,
                    tint: BrandPalette.navy
                )
            }

            if approvedNotes.isEmpty == false {
                notesSection(
                    title: approvedCount == 1 ? "Approved staged apply" : "Approved staged apply",
                    subtitle: approvedCount == 1
                        ? "This row is cleared for the next staged switch."
                        : "These rows are cleared for the next staged switch.",
                    tint: BrandPalette.teal,
                    notes: approvedNotes
                )
            }

            if pendingNotes.isEmpty == false {
                notesSection(
                    title: pendingCount == 1 ? "Pending decision" : "Pending decisions",
                    subtitle: pendingCount == 1
                        ? "This row still needs your approval or deferral."
                        : "These rows still need your approval or deferral.",
                    tint: BrandPalette.navy,
                    notes: pendingNotes
                )
            }

            HStack(spacing: 10) {
                Button(isApplying ? "Applying..." : (approvedCount == 1 ? "Apply approved staged backup" : "Apply approved staged backups")) {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.teal)
                .disabled(approvedCount == 0 || isApplying)

                if let onApproveAllPending, pendingCount > 0 {
                    Button(pendingCount == 1 ? "Approve pending row" : "Approve all pending") {
                        onApproveAllPending()
                    }
                    .buttonStyle(.bordered)
                    .tint(BrandPalette.teal)
                    .disabled(isApplying)
                }

                Button(stagedCount == 1 ? "Defer staged row" : "Defer all staged") {
                    onDefer()
                }
                .buttonStyle(.bordered)
                .tint(BrandPalette.navy)
                .disabled(stagedCount == 0 || isApplying)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }

    @ViewBuilder
    private func notesSection(
        title: String,
        subtitle: String,
        tint: Color,
        notes: [ConciergeBatchReviewStagedNote]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(notes) { note in
                ConciergeBatchReviewStagedNoteCard(
                    note: note,
                    onApprove: onApproveNote == nil ? nil : {
                        onApproveNote?(note)
                    },
                    onClearRefreshHighlight: onClearRefreshHighlightNote == nil ? nil : {
                        onClearRefreshHighlightNote?(note)
                    },
                    onRemoveApproval: onRemoveApproval == nil ? nil : {
                        onRemoveApproval?(note)
                    },
                    onDefer: onDeferNote == nil ? nil : {
                        onDeferNote?(note)
                    }
                )
            }
        }
    }
}

private struct ConciergeBatchReviewStagedNoteCard: View {
    let note: ConciergeBatchReviewStagedNote
    var onApprove: (() -> Void)? = nil
    var onClearRefreshHighlight: (() -> Void)? = nil
    var onRemoveApproval: (() -> Void)? = nil
    var onDefer: (() -> Void)? = nil

    private var statusTint: Color {
        if note.isInvalidated {
            return BrandPalette.gold
        }
        return note.tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(note.tint.opacity(0.14))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: note.serviceSymbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(note.tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.subheadline.weight(.semibold))
                    Text(statusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                }

                Spacer(minLength: 0)

                Text(statusBadgeTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(statusTint.opacity(note.isApproved ? 0.18 : 0.1))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(note.isApproved ? "What happens now" : "If you approve this row")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(note.tint)
                Text(note.afterLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(
                    actionSummary
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if note.isRefreshHighlighted {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(BrandPalette.teal.opacity(0.16))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BrandPalette.teal)
                        }

                    Text("This staged row was re-approved from the refresh summary, so it is back in the mini-batch and ready to follow through right away.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BrandPalette.teal.opacity(0.08))
                )
            }

            if note.isInvalidated {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(BrandPalette.gold.opacity(0.16))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BrandPalette.gold)
                        }

                    Text("The saved approval was cleared because the booking or top-ranked backup changed. Re-approve this row only if the updated switch still looks right.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BrandPalette.gold.opacity(0.08))
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Before")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(note.tint)
                Text(note.beforeLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(note.isApproved ? "Why it is safe now" : "Why it is a strong backup")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(note.tint)

                ForEach(Array(note.whySafe.prefix(2).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(note.tint.opacity(0.82))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)

                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    approvalButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    approvalButtons
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(note.tint.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    note.isRefreshHighlighted ? BrandPalette.teal.opacity(0.4) : .clear,
                    lineWidth: note.isRefreshHighlighted ? 1.5 : 0
                )
        }
    }

    private var statusTitle: String {
        if note.isInvalidated {
            return "Approval cleared and waiting on your recheck"
        }
        if note.isRefreshHighlighted {
            return "Re-approved from refresh and ready now"
        }

        return note.isApproved ? "Included in the staged apply" : "Waiting on your decision"
    }

    private var statusBadgeTitle: String {
        if note.isInvalidated {
            return "Recheck required"
        }
        if note.isRefreshHighlighted {
            return "Refreshed"
        }

        return note.isApproved ? "Approved" : "Pending"
    }

    private var actionSummary: String {
        if note.isInvalidated {
            return "This row stays out of the staged mini-batch until you review the updated switch and approve it again or defer it."
        }

        return note.isApproved
            ? "This row will be included the next time you apply the staged mini-batch."
            : "This row stays out of the staged mini-batch until you approve it or defer it."
    }

    @ViewBuilder
    private var approvalButtons: some View {
        if note.isApproved {
            if note.isRefreshHighlighted, let onClearRefreshHighlight {
                Button("Mark reviewed") {
                    onClearRefreshHighlight()
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.teal)
            }

            if let onRemoveApproval {
                Button("Keep pending") {
                    onRemoveApproval()
                }
                .buttonStyle(.bordered)
                .tint(note.tint)
            }
        } else if let onApprove {
            Button("Approve for staged apply") {
                onApprove()
            }
            .buttonStyle(.borderedProminent)
            .tint(note.tint)
        }

        if let onDefer {
            Button("Defer this row") {
                onDefer()
            }
            .buttonStyle(.bordered)
            .tint(BrandPalette.navy)
        }
    }
}

private struct ConciergeBatchReviewStagedDecisionLane: View {
    let title: String
    let message: String
    let lines: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(tint.opacity(0.82))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)

                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct ConciergeBatchReviewApprovalRefreshPanel: View {
    let summary: ConciergeBatchReviewApprovalRefreshSummary
    let actionableItems: [ConciergeBatchReviewApprovalRefreshItem]
    var onApproveAll: (() -> Void)? = nil
    var onApproveItem: ((ConciergeBatchReviewApprovalRefreshItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(BrandPalette.teal.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BrandPalette.teal)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.headline)
                    Text(summary.message)
                        .foregroundStyle(.secondary)
                    Text(summary.supporting)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if summary.immediateReapprovalItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Safe to re-approve now")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.teal)

                    ForEach(summary.immediateReapprovalItems) { item in
                        approvalRefreshRow(item)
                    }

                    if let onApproveAll, actionableItems.isEmpty == false {
                        Button(actionableItems.count == 1 ? "Re-approve safe row" : "Re-approve all safe rows") {
                            onApproveAll()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandPalette.teal)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }

    @ViewBuilder
    private func approvalRefreshRow(_ item: ConciergeBatchReviewApprovalRefreshItem) -> some View {
        let isActionable = actionableItems.contains { $0.id == item.id }

        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(BrandPalette.teal.opacity(0.82))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.footnote.weight(.semibold))
                Text(item.supporting)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let onApproveItem, isActionable {
                Button("Re-approve") {
                    onApproveItem(item)
                }
                .buttonStyle(.bordered)
                .tint(BrandPalette.teal)
            } else if isActionable == false {
                Text("Already updated")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ConciergeBatchReviewApprovalRefreshCloseoutPanel: View {
    let summary: ConciergeBatchReviewApprovalRefreshCloseoutSummary
    var jumpTitle: String? = nil
    var onJumpToReview: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(BrandPalette.teal.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BrandPalette.teal)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                    Text(summary.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(summary.supporting)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if jumpTitle != nil || onDismiss != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        actionButtons
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrandPalette.teal.opacity(0.08))
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let jumpTitle, let onJumpToReview {
            Button(jumpTitle) {
                onJumpToReview()
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandPalette.teal)
        }

        if let onDismiss {
            Button("Hide update") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .tint(BrandPalette.navy)
        }
    }
}

private struct ConciergeBatchReviewRefreshOutcomePanel: View {
    let summary: ConciergeBatchReviewRefreshSummary
    var jumpLaneProgress: ConciergeBatchReviewRefreshLaneProgress? = nil
    var bookingLaneProgress: ConciergeBatchReviewRefreshLaneProgress? = nil
    var visitedBookingItemIDs: [String] = []
    var reactivatedBookingItemIDs: [String] = []
    var isBookingLaneHidden = false
    var showsReactivatedBookingLane = false
    var bookingLaneReactivationCompletionMessage: String? = nil
    var bookingLaneReactivationCompletionSupporting: String? = nil
    var completionReviewActionTitle: String? = nil
    var completionReviewProgress: ConciergeBatchReviewRefreshLaneProgress? = nil
    var completionReviewLastItemID: String? = nil
    var isCompletionReviewComplete = false
    var onJumpLane: (() -> Void)? = nil
    var onBookingLane: (() -> Void)? = nil
    var onHideCompletedBookingLane: (() -> Void)? = nil
    var onRestoreBookingLane: (() -> Void)? = nil
    var onHideCompletedBookingLaneAfterReactivation: (() -> Void)? = nil
    var onDismissBookingLaneReactivationCompletion: (() -> Void)? = nil
    var onReviewClearedCycle: (() -> Void)? = nil
    var onAction: ((ConciergeBatchReviewRefreshOutcomeItem) -> Void)? = nil

    private var bookingLaneActionTitle: String {
        if summary.bookingItems.count == 1 {
            return bookingLaneProgress == nil ? "Open booking follow-through" : "Reopen booking follow-through"
        }

        guard let bookingLaneProgress else {
            return "Open booking follow-through"
        }

        return bookingLaneProgress.remainingCount == 0
            ? "Revisit booking follow-through"
            : "Open next unvisited booking"
    }

    private var bookingLaneIsComplete: Bool {
        bookingLaneProgress?.remainingCount == 0 && bookingLaneProgress != nil
    }

    private var reactivatedBookingItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        let reactivatedIDs = Set(reactivatedBookingItemIDs)
        let visitedIDs = Set(visitedBookingItemIDs)
        return summary.bookingItems.filter {
            reactivatedIDs.contains($0.id) && visitedIDs.contains($0.id) == false
        }
    }

    private var completedReactivatedBookingItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        guard bookingLaneReactivationCompletionMessage != nil else {
            return []
        }

        let reactivatedIDs = Set(reactivatedBookingItemIDs)
        return summary.bookingItems.filter { reactivatedIDs.contains($0.id) }
    }

    private var bookingLaneReactivationSupporting: String {
        let titles = reactivatedBookingItems.map(\.title)
        guard titles.isEmpty == false else {
            return "The booking lane stayed hidden only while every row there had already been revisited."
        }

        let visibleTitles = Array(titles.prefix(3))
        var summaryLine = "Needs revisit now: " + visibleTitles.joined(separator: " • ")
        if titles.count > visibleTitles.count {
            summaryLine += " • +\(titles.count - visibleTitles.count) more"
        }
        return summaryLine
    }

    private var bookingLaneReactivationMessage: String? {
        guard showsReactivatedBookingLane,
              let bookingLaneProgress,
              bookingLaneProgress.remainingCount > 0 else {
            return nil
        }

        let revisitedCount = max(0, bookingLaneProgress.totalCount - bookingLaneProgress.remainingCount)
        let nextTitle = bookingLaneProgress.nextItemID.flatMap { nextID in
            summary.bookingItems.first(where: { $0.id == nextID })?.title
        }

        var message = "\(bookingLaneProgress.remainingCount) booking row\(bookingLaneProgress.remainingCount == 1 ? "" : "s") still need follow-through, so Real O Who reopened this lane after it had previously been tucked away."
        if revisitedCount > 0 {
            message += " \(revisitedCount) row\(revisitedCount == 1 ? " is" : "s are") already revisited."
        }
        if let nextTitle {
            message += " Next up: \(nextTitle)."
        }
        return message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Refresh follow-through")
                .font(.headline)

            Text("Real O Who tracked which refreshed staged rows were already handled before this review reopened.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if summary.jumpItems.isEmpty == false {
                laneSection(
                    title: summary.jumpItems.count == 1
                        ? "Still live in this review"
                        : "Still live in this review",
                    subtitle: "These refreshed rows are still active below, so you can jump straight to the matching staged or review card without leaving the reopened batch review.",
                    items: summary.jumpItems,
                    tint: BrandPalette.teal,
                    actionTitle: summary.jumpItems.count == 1
                        ? "Jump to live row"
                        : (jumpLaneProgress == nil ? "Jump through live rows" : "Jump to next live row"),
                    laneProgress: jumpLaneProgress,
                    onLaneAction: onJumpLane
                )
            }

            if summary.bookingItems.isEmpty == false {
                if isBookingLaneHidden {
                    collapsedBookingLaneSection
                } else {
                    if let bookingLaneReactivationMessage {
                        HighlightInformationCard(
                            title: "Booking follow-through is back",
                            message: bookingLaneReactivationMessage,
                            supporting: bookingLaneReactivationSupporting
                        )
                    }

                    if let bookingLaneReactivationCompletionMessage {
                        ConciergeBatchReviewBookingLaneReactivationCompletionPanel(
                            message: bookingLaneReactivationCompletionMessage,
                            supporting: bookingLaneReactivationCompletionSupporting,
                            reviewActionTitle: completionReviewActionTitle,
                            reviewProgress: completionReviewProgress,
                            isReviewComplete: isCompletionReviewComplete,
                            onReview: onReviewClearedCycle,
                            onHide: onHideCompletedBookingLaneAfterReactivation,
                            onDismiss: onDismissBookingLaneReactivationCompletion
                        )
                    }

                    laneSection(
                        title: summary.bookingItems.count == 1
                            ? "Already moved into booking follow-through"
                            : "Already moved into booking follow-through",
                        subtitle: "These refreshed rows were already handled before the reopen, so the next useful place to inspect them is the booking flow itself.",
                        items: summary.bookingItems,
                        tint: BrandPalette.navy,
                        actionTitle: bookingLaneActionTitle,
                        laneProgress: bookingLaneProgress,
                        onLaneAction: onBookingLane
                    )

                    if bookingLaneIsComplete,
                       let onHideCompletedBookingLane {
                        HStack {
                            Spacer(minLength: 0)

                            Button("Hide completed booking lane") {
                                onHideCompletedBookingLane()
                            }
                            .buttonStyle(.bordered)
                            .tint(BrandPalette.navy)
                        }
                    }
                }
            }

            if summary.informationalItems.isEmpty == false {
                laneSection(
                    title: "Tracked outcome",
                    subtitle: "These rows were accounted for in the refresh loop, but there is no direct jump target left in the reopened review right now.",
                    items: summary.informationalItems,
                    tint: BrandPalette.gold
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }

    @ViewBuilder
    private var collapsedBookingLaneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Booking follow-through tucked away")
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandPalette.navy)

            Text("Every booking row in this refresh lane has already been revisited. Real O Who hid that completed lane so the review can stay focused on the live rows below.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let bookingLaneProgress {
                Text(bookingLaneProgress.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let onRestoreBookingLane {
                HStack {
                    Spacer(minLength: 0)

                    Button("Restore booking lane") {
                        onRestoreBookingLane()
                    }
                    .buttonStyle(.bordered)
                    .tint(BrandPalette.navy)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.navy.opacity(0.08))
        )
    }

    @ViewBuilder
    private func laneSection(
        title: String,
        subtitle: String,
        items: [ConciergeBatchReviewRefreshOutcomeItem],
        tint: Color,
        actionTitle: String? = nil,
        laneProgress: ConciergeBatchReviewRefreshLaneProgress? = nil,
        onLaneAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let actionTitle,
                   let onLaneAction {
                    HStack {
                        Spacer(minLength: 0)

                        Button(actionTitle) {
                            onLaneAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(tint)
                    }
                }

                if let laneProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(laneProgress.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)

                        Text(laneProgress.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.08))
                    )
                }
            }

            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(item.tint.opacity(0.16))
                            .frame(width: 26, height: 26)
                            .overlay {
                                Image(systemName: item.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(item.tint)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))

                                if jumpLaneProgress?.lastItemID == item.id {
                                    Text(jumpLaneProgress?.highlightTitle ?? "Last jumped")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.teal)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(BrandPalette.teal.opacity(0.12))
                                        )
                                }

                                if visitedBookingItemIDs.contains(item.id),
                                   bookingLaneProgress?.lastItemID != item.id {
                                    Text("Visited")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.navy)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(BrandPalette.navy.opacity(0.12))
                                        )
                                }

                                if bookingLaneProgress?.nextItemID == item.id,
                                   bookingLaneProgress?.remainingCount ?? 0 > 0 {
                                    Text("Next up")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.gold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(BrandPalette.gold.opacity(0.14))
                                        )
                                }

                                if reactivatedBookingItems.contains(where: { $0.id == item.id }) {
                                    Text("Needs revisit")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.coral)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(BrandPalette.coral.opacity(0.14))
                                        )
                                }

                                if completionReviewLastItemID == item.id,
                                   completedReactivatedBookingItems.contains(where: { $0.id == item.id }) {
                                    Text(completionReviewProgress?.highlightTitle ?? "Last reviewed")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.navy)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(BrandPalette.navy.opacity(0.12))
                                        )
                                }

                                if completedReactivatedBookingItems.contains(where: { $0.id == item.id }) {
                                    Text("Cleared cycle")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandPalette.teal)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(BrandPalette.teal.opacity(0.14))
                                        )
                                }

                                Text(item.kind.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(item.kind.tint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(item.kind.tint.opacity(0.12))
                                    )
                            }
                            Text(item.supporting)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let action = item.action,
                       let onAction {
                        HStack {
                            Spacer(minLength: 0)

                            Button(action.title) {
                                onAction(item)
                            }
                            .buttonStyle(.bordered)
                            .tint(item.tint)
                        }
                    }
                }
            }

            if items.count > 3 {
                Text("And \(items.count - 3) more row\(items.count - 3 == 1 ? "" : "s").")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
    }
}

private struct ConciergeBatchReviewBookingLaneReactivationCompletionPanel: View {
    let message: String
    var supporting: String? = nil
    var reviewActionTitle: String? = nil
    var reviewProgress: ConciergeBatchReviewRefreshLaneProgress? = nil
    var isReviewComplete = false
    var onReview: (() -> Void)? = nil
    var onHide: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reactivated booking follow-through is clear again")
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandPalette.teal)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let supporting {
                Text(supporting)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let reviewProgress {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reviewProgress.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.navy)

                    Text(reviewProgress.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BrandPalette.navy.opacity(0.08))
                )
            }

            Text(isReviewComplete
                ? "Every cleared row from this reactivated cycle has now been reviewed. You can tuck this lane away again, or keep it visible if you want one final look."
                : "You can tuck this lane away again now, or keep it visible while you finish the cleared-cycle review."
            )
                .font(.caption)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    actionButtons
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandPalette.teal.opacity(0.08))
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let reviewActionTitle, let onReview {
            Button(reviewActionTitle) {
                onReview()
            }
            .buttonStyle(.bordered)
            .tint(BrandPalette.navy)
        }

        if let onHide {
            Button("Hide booking lane again") {
                onHide()
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandPalette.teal)
        }

        if let onDismiss {
            Button("Keep it visible") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .tint(BrandPalette.navy)
        }
    }
}

private struct ConciergeBatchReviewRankingFocusPanel: View {
    let readyCount: Int
    let onJump: () -> Void

    private var buttonTitle: String {
        readyCount == 1 ? "Jump to ready row" : "Jump to ready rows"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(BrandPalette.teal.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "location.viewfinder")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BrandPalette.teal)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Fresh recovery rows are ready below")
                    .font(.subheadline.weight(.semibold))
                Text("Real O Who has moved the newest ready backup\(readyCount == 1 ? "" : "s") to the top of the apply section and can jump you there now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(buttonTitle) {
                onJump()
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandPalette.teal)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrandPalette.teal.opacity(0.08))
        )
    }
}

private struct ConciergeBatchReviewRowChangePanel: View {
    let summary: ConciergeBatchReviewRowChangeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(summary.tint.opacity(0.16))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(summary.tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(summary.supporting)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(summary.highlights.prefix(3).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(summary.tint.opacity(0.82))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)

                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(summary.tint.opacity(0.08))
        )
    }
}

private struct ConciergeBatchReviewSuggestedActionPanel: View {
    let action: ConciergeBatchReviewSuggestedAction
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested next step")
                .font(.caption.weight(.bold))
                .foregroundStyle(action.tint)

            Text(action.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(action.supporting)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let buttonTitle = action.buttonTitle,
               let onAction {
                HStack {
                    Spacer(minLength: 0)

                    Button(buttonTitle) {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(action.tint)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(action.tint.opacity(0.08))
        )
    }
}

private struct ConciergeBatchReviewCompletionGuidancePanel: View {
    let guidance: ConciergeBatchReviewCompletionGuidance
    var closeSafeRowsTitle: String? = nil
    var onCloseSafeRows: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(guidance.title)
                .font(.headline)

            Text(guidance.message)
                .foregroundStyle(.secondary)

            if guidance.safeToCloseItems.isEmpty == false {
                completionSection(
                    title: "Safe to close now",
                    items: guidance.safeToCloseItems,
                    tint: BrandPalette.teal
                )
            }

            if guidance.needsFinalStepItems.isEmpty == false {
                completionSection(
                    title: "Still needs one last step",
                    items: guidance.needsFinalStepItems,
                    tint: BrandPalette.coral
                )
            }

            if let closeSafeRowsTitle, let onCloseSafeRows {
                HStack {
                    Spacer(minLength: 0)

                    Button(closeSafeRowsTitle) {
                        onCloseSafeRows()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandPalette.teal)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.panel)
        )
    }

    @ViewBuilder
    private func completionSection(
        title: String,
        items: [ConciergeBatchReviewCompletionItem],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(item.tint.opacity(0.16))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: item.symbolName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.tint)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(item.supporting)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if items.count > 3 {
                Text("And \(items.count - 3) more row\(items.count - 3 == 1 ? "" : "s").")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
    }
}

private struct ConciergeBatchReviewNextActionSectionHeader: View {
    let group: ConciergeBatchReviewNextActionGroup
    let count: Int
    var actions: [ConciergeBatchReviewSectionAction] = []
    var onAction: ((ConciergeBatchReviewSectionAction) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Label(group.title, systemImage: group.symbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(group.tint)

                Text(count == 1 ? "1 row" : "\(count) rows")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text(group.supporting)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if actions.isEmpty == false, let onAction {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                onAction(action)
                            }
                            .buttonStyle(.bordered)
                            .tint(action.tint)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                onAction(action)
                            }
                            .buttonStyle(.bordered)
                            .tint(action.tint)
                        }
                    }
                }
            }
        }
    }
}

private enum SellerDealExecutionActionKind {
    case chooseSellerLegalRep
    case shareInvite(LegalInviteRole)
    case regenerateInvite(LegalInviteRole)
    case signContract
    case confirmSettlement
    case uploadVerification(VerificationCheckKind)
    case nudgeBuyer(checklistItemID: String, body: String)
}

private struct SellerDealExecutionActionDescriptor {
    let title: String
    let supporting: String
    let kind: SellerDealExecutionActionKind
}

private enum BuyerDealExecutionActionKind {
    case chooseBuyerLegalRep
    case shareInvite(LegalInviteRole)
    case regenerateInvite(LegalInviteRole)
    case signContract
    case confirmSettlement
    case uploadVerification(VerificationCheckKind)
    case nudgeSeller(checklistItemID: String, body: String)
}

private struct BuyerDealExecutionActionDescriptor {
    let title: String
    let supporting: String
    let kind: BuyerDealExecutionActionKind
}

private struct SellerOfferComparisonGroup: Identifiable {
    let listing: PropertyListing
    let entries: [SellerOfferBoardEntry]

    var id: UUID {
        listing.id
    }
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

private struct SaleArchiveShareContext: Identifiable {
    let id = UUID()
    let title: String
    let fileURLs: [URL]
}

private struct PostSaleFeedbackContext: Identifiable {
    let offerID: UUID
    let listingID: UUID
    let listingTitle: String
    let counterpartName: String
    let currentRole: UserRole
    let existingEntry: PostSaleFeedbackEntry?

    var id: String {
        "\(offerID.uuidString)-\(currentRole.rawValue)"
    }
}

private enum PostSaleConciergeBookingFocus: String {
    case standard
    case replacement
}

private enum ConciergeReplacementWeighting {
    case balanced
    case fastestRecovery
    case qualityFirst
    case bestValue
}

private struct ConciergeManualReviewContext: Equatable {
    let title: String
    let message: String
    let supporting: String

    var id: String {
        [title, message, supporting].joined(separator: "|")
    }
}

private enum ConciergeBatchReviewRowState: String, Equatable {
    case ready
    case manualReview
    case loading
    case unavailable

    var title: String {
        switch self {
        case .ready:
            return "Ready to switch"
        case .manualReview:
            return "Manual review"
        case .loading:
            return "Ranking backup"
        case .unavailable:
            return "Unavailable"
        }
    }
}

private struct ConciergeBatchReviewRowSnapshot: Equatable {
    let id: String
    let reviewState: ConciergeBatchReviewRowState
    let providerID: String?
    let providerName: String?
    let suggestedProviderID: String?
    let suggestedProviderName: String?
    let scheduledFor: Date?
    let isProviderConfirmed: Bool
    let followUpCount: Int
    let snoozedUntil: Date?
    let hasOpenIssue: Bool
    let hasResolvedIssue: Bool
    let issueTitle: String?
    let isQuoteApproved: Bool
    let invoiceUploadedAt: Date?
    let paymentConfirmedAt: Date?
    let manualReviewReason: String?
}

private struct ConciergeBatchReviewReturnContext: Equatable {
    let hubTitle: String
    let itemIDs: [String]
    let itemTitlesByID: [String: String]
    let itemReferencesByID: [String: ConciergeBatchReviewEntryReference]
    let previousSnapshots: [ConciergeBatchReviewRowSnapshot]
    let stagedEntryIDs: [String]
    let stagedApprovalFingerprints: [String: String]
    let refreshHighlightedStagedEntryIDs: [String]
    let reviewedRefreshHighlightEntryIDs: [String]
    let appliedRefreshHighlightEntryIDs: [String]
    let visitedRefreshBookingEntryIDs: [String]
    let hasHiddenCompletedBookingLane: Bool
    let hasActiveBookingLaneReactivation: Bool
    let hasDismissedBookingLaneReactivationCompletion: Bool
    let reactivatedRefreshBookingEntryIDs: [String]
    let reactivationCompletionReviewLastItemID: String?
    let reviewedReactivationCompletionItemIDs: [String]
}

private struct ConciergeBatchReviewRefreshSummary {
    let title: String
    let message: String
    let supporting: String
    let appliedRefreshItems: [ConciergeBatchReviewRefreshOutcomeItem]
    let reviewedRefreshItems: [ConciergeBatchReviewRefreshOutcomeItem]

    var allItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        appliedRefreshItems + reviewedRefreshItems
    }

    var jumpItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        allItems.filter { $0.action?.kind == .jumpToReviewRow }
    }

    var bookingItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        allItems.filter { $0.action?.kind == .openBooking }
    }

    var informationalItems: [ConciergeBatchReviewRefreshOutcomeItem] {
        allItems.filter { $0.action == nil }
    }
}

private enum ConciergeBatchReviewRefreshOutcomeKind: Equatable {
    case applied
    case reviewed

    var title: String {
        switch self {
        case .applied:
            return "Applied"
        case .reviewed:
            return "Reviewed"
        }
    }

    var tint: Color {
        switch self {
        case .applied:
            return BrandPalette.teal
        case .reviewed:
            return BrandPalette.navy
        }
    }
}

private enum ConciergeBatchReviewRefreshOutcomeActionKind: Equatable {
    case jumpToReviewRow
    case openBooking
}

private struct ConciergeBatchReviewRefreshOutcomeAction: Equatable {
    let title: String
    let kind: ConciergeBatchReviewRefreshOutcomeActionKind
}

private struct ConciergeBatchReviewEntryReference: Equatable {
    let id: String
    let offerID: UUID
    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind
    let counterpartLabel: String
    let counterpartName: String
}

private struct ConciergeBatchReviewRefreshOutcomeItem: Identifiable {
    let id: String
    let kind: ConciergeBatchReviewRefreshOutcomeKind
    let title: String
    let supporting: String
    let tint: Color
    let symbolName: String
    let action: ConciergeBatchReviewRefreshOutcomeAction?
    let entryReference: ConciergeBatchReviewEntryReference?
}

private struct ConciergeBatchReviewRefreshLaneProgress {
    let lastItemID: String
    let title: String
    let message: String
    let highlightTitle: String
    let nextItemID: String?
    let remainingCount: Int
    let totalCount: Int
}

private struct ConciergeBatchReviewApprovalRefreshSummary {
    let title: String
    let message: String
    let supporting: String
    let immediateReapprovalItems: [ConciergeBatchReviewApprovalRefreshItem]
}

private struct ConciergeBatchReviewApprovalRefreshItem: Identifiable {
    let id: String
    let title: String
    let supporting: String
}

private struct ConciergeBatchReviewApprovalRefreshCloseoutSummary {
    let id = UUID()
    let title: String
    let message: String
    let supporting: String
}

private struct ConciergeBatchReviewStagedRefreshState {
    let stagedEntryIDs: [String]
    let approvalFingerprints: [String: String]
    let refreshHighlightedEntryIDs: [String]
    let invalidatedEntryIDs: [String]
    let summary: ConciergeBatchReviewApprovalRefreshSummary?
}

private struct ConciergeBatchReviewStagedApprovalFeedback {
    let title: String
    let message: String
    let supporting: String
}

private struct ConciergeBatchReviewRankingUpdateSummary {
    let id = UUID()
    let title: String
    let message: String
    let supporting: String
    let newlyReadyEntryIDs: [String]
}

private struct ConciergeBatchReviewStagedNote: Identifiable {
    let id: String
    let title: String
    let serviceSymbolName: String
    let beforeLine: String
    let afterLine: String
    let whySafe: [String]
    let tint: Color
    let isApproved: Bool
    let isInvalidated: Bool
    let isRefreshHighlighted: Bool
}

private struct ConciergeBatchReviewRowChangeSummary {
    let title: String
    let supporting: String
    let highlights: [String]
    let tint: Color
    let marksRecoveryReady: Bool
}

private enum ConciergeBatchReviewNextActionGroup: String, CaseIterable, Identifiable {
    case applyRankedBackup
    case switchProvider
    case followUp
    case reviewBooking
    case waitForRanking
    case closeNow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applyRankedBackup:
            return "Apply ranked backups"
        case .switchProvider:
            return "Open replacement work"
        case .followUp:
            return "Follow up with providers"
        case .reviewBooking:
            return "Review booking details"
        case .waitForRanking:
            return "Waiting for ranking"
        case .closeNow:
            return "Safe to close now"
        }
    }

    var supporting: String {
        switch self {
        case .applyRankedBackup:
            return "These rows already have a ranked backup ready to apply."
        case .switchProvider:
            return "These provider threads need a manual replacement decision next."
        case .followUp:
            return "These rows are blocked on direct provider follow-up."
        case .reviewBooking:
            return "These rows need a quick booking review before they can leave the queue."
        case .waitForRanking:
            return "These rows are still checking local backup options."
        case .closeNow:
            return "These rows are stable enough to dismiss from the review."
        }
    }

    var tint: Color {
        switch self {
        case .applyRankedBackup:
            return BrandPalette.teal
        case .switchProvider:
            return BrandPalette.coral
        case .followUp:
            return BrandPalette.gold
        case .reviewBooking:
            return BrandPalette.navy
        case .waitForRanking:
            return BrandPalette.sky
        case .closeNow:
            return BrandPalette.teal
        }
    }

    var symbolName: String {
        switch self {
        case .applyRankedBackup:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .switchProvider:
            return "arrow.triangle.branch"
        case .followUp:
            return "phone.fill"
        case .reviewBooking:
            return "doc.text.magnifyingglass"
        case .waitForRanking:
            return "hourglass.circle.fill"
        case .closeNow:
            return "checkmark.circle.fill"
        }
    }
}

private enum ConciergeBatchReviewSuggestedActionKind {
    case applySuggestedReplacement
    case closeEntry
    case openEntry
}

private enum ConciergeBatchReviewSectionActionKind {
    case applyAll
    case closeAll
    case openFirst
    case logFollowUpAll
    case snoozeAll
    case confirmAll
    case logIssueAll
}

private struct ConciergeBatchReviewNextActionPlan {
    let group: ConciergeBatchReviewNextActionGroup
    let title: String
    let supporting: String
    let buttonTitle: String?
    let tint: Color
    let kind: ConciergeBatchReviewSuggestedActionKind?
}

private struct ConciergeBatchReviewSuggestedAction {
    let title: String
    let supporting: String
    let buttonTitle: String?
    let tint: Color
    let kind: ConciergeBatchReviewSuggestedActionKind?
}

private struct ConciergeBatchReviewSectionAction: Identifiable {
    let title: String
    let tint: Color
    let kind: ConciergeBatchReviewSectionActionKind

    var id: String {
        "\(kind)-\(title)"
    }
}

private struct ConciergeBatchReviewStatusAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ConciergeBatchReviewNextActionSection: Identifiable {
    let group: ConciergeBatchReviewNextActionGroup
    let entries: [ConciergeBatchReplacementReviewEntry]

    var id: String { group.id }
}

private struct ConciergeBatchReviewCompletionGuidance {
    let title: String
    let message: String
    let safeToCloseItems: [ConciergeBatchReviewCompletionItem]
    let needsFinalStepItems: [ConciergeBatchReviewCompletionItem]
}

private struct ConciergeBatchReviewCompletionItem: Identifiable {
    enum Group {
        case safeToClose
        case needsFinalStep
    }

    let id: String
    let title: String
    let supporting: String
    let symbolName: String
    let tint: Color
    let group: Group
}

private struct PostSaleConciergeBookingContext: Identifiable {
    let offerID: UUID
    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind
    let counterpartName: String
    let focus: PostSaleConciergeBookingFocus
    let preferredProviderID: String?
    let preferredReplacementStrategy: ConciergeReplacementStrategy
    let currentBooking: PostSaleConciergeBooking?
    let manualReviewContext: ConciergeManualReviewContext?
    let batchReviewReturnContext: ConciergeBatchReviewReturnContext?

    init(
        offerID: UUID,
        listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind,
        counterpartName: String,
        focus: PostSaleConciergeBookingFocus,
        preferredProviderID: String?,
        preferredReplacementStrategy: ConciergeReplacementStrategy,
        currentBooking: PostSaleConciergeBooking?,
        manualReviewContext: ConciergeManualReviewContext? = nil,
        batchReviewReturnContext: ConciergeBatchReviewReturnContext? = nil
    ) {
        self.offerID = offerID
        self.listing = listing
        self.serviceKind = serviceKind
        self.counterpartName = counterpartName
        self.focus = focus
        self.preferredProviderID = preferredProviderID
        self.preferredReplacementStrategy = preferredReplacementStrategy
        self.currentBooking = currentBooking
        self.manualReviewContext = manualReviewContext
        self.batchReviewReturnContext = batchReviewReturnContext
    }

    var id: String {
        "\(offerID.uuidString)-\(serviceKind.rawValue)-\(focus.rawValue)-\(preferredProviderID ?? "none")-\(preferredReplacementStrategy.rawValue)-\(manualReviewContext?.id ?? "no-review")-\(batchReviewReturnContext?.itemIDs.joined(separator: ",") ?? "no-return")"
    }
}

private struct ConciergeBatchReplacementReviewContext: Identifiable {
    let id = UUID()
    let title: String
    let hubTitle: String
    let strategy: ConciergeReplacementStrategy
    let entries: [ConciergeBatchReplacementReviewEntry]
    let initialStagedEntryIDs: [String]
    let initialApprovedStagedEntryFingerprints: [String: String]
    let initialRefreshHighlightedStagedEntryIDs: [String]
    let initialVisitedRefreshBookingEntryIDs: [String]
    let initialHasHiddenCompletedBookingLane: Bool
    let initialHasActiveBookingLaneReactivation: Bool
    let initialHasDismissedBookingLaneReactivationCompletion: Bool
    let initialReactivatedRefreshBookingEntryIDs: [String]
    let initialReactivationCompletionReviewLastItemID: String?
    let initialReviewedReactivationCompletionItemIDs: [String]
    let refreshSummary: ConciergeBatchReviewRefreshSummary?
    let approvalRefreshSummary: ConciergeBatchReviewApprovalRefreshSummary?
}

private struct ConciergeBatchReplacementReviewEntry: Identifiable {
    let id: String
    let offerID: UUID
    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind
    let counterpartLabel: String
    let counterpartName: String
    let currentBooking: PostSaleConciergeBooking?
    let reviewFingerprint: String?
    var suggestedReplacement: ConciergeReplacementSuggestion?
    var isLoadingSuggestion: Bool
    var manualReviewReason: String?
    var rowChangeSummary: ConciergeBatchReviewRowChangeSummary? = nil

    var canApplySuggestedReplacement: Bool {
        currentBooking != nil && suggestedReplacement != nil
    }

    var currentProvider: PostSaleConciergeProvider? {
        currentBooking?.provider
    }
}

private func conciergeManualReviewContext(
    hubTitle: String,
    entry: ConciergeBatchReplacementReviewEntry,
    focus: PostSaleConciergeBookingFocus
) -> ConciergeManualReviewContext {
    let reason = entry.manualReviewReason ?? "This provider row still needs a manual review before Real O Who can apply a ranked backup."
    let supporting: String

    if focus == .replacement {
        supporting = "Replacement mode is open so you can compare local backups, switch providers manually, or keep the current booking if the handover is back on track."
    } else if let booking = entry.currentBooking, booking.needsResponseFollowUp {
        supporting = "Review the provider status, log a follow-up or issue if needed, and then return to the queue once the booking is moving again."
    } else {
        supporting = "Review the current provider, confirmation state, and saved booking details before this row goes back through the queue."
    }

    return ConciergeManualReviewContext(
        title: "Opened from \(hubTitle) batch review",
        message: reason,
        supporting: supporting
    )
}

private func conciergeBatchReviewRowSnapshot(
    for entry: ConciergeBatchReplacementReviewEntry
) -> ConciergeBatchReviewRowSnapshot {
    let booking = entry.currentBooking
    let reviewState: ConciergeBatchReviewRowState
    if booking == nil {
        reviewState = .unavailable
    } else if entry.isLoadingSuggestion {
        reviewState = .loading
    } else if entry.canApplySuggestedReplacement {
        reviewState = .ready
    } else {
        reviewState = .manualReview
    }

    return ConciergeBatchReviewRowSnapshot(
        id: entry.id,
        reviewState: reviewState,
        providerID: booking?.provider.id,
        providerName: booking?.provider.name,
        suggestedProviderID: entry.suggestedReplacement?.provider.id,
        suggestedProviderName: entry.suggestedReplacement?.provider.name,
        scheduledFor: booking?.scheduledFor,
        isProviderConfirmed: booking?.isProviderConfirmed ?? false,
        followUpCount: booking?.followUpCountValue ?? 0,
        snoozedUntil: booking?.reminderSnoozedUntil,
        hasOpenIssue: booking?.hasOpenIssue ?? false,
        hasResolvedIssue: booking?.hasResolvedIssue ?? false,
        issueTitle: booking?.issueKind?.title,
        isQuoteApproved: booking?.isQuoteApproved ?? false,
        invoiceUploadedAt: booking?.invoiceUploadedAt,
        paymentConfirmedAt: booking?.paymentConfirmedAt,
        manualReviewReason: entry.manualReviewReason
    )
}

private func conciergeBatchReviewRowChangeSummary(
    previousSnapshot: ConciergeBatchReviewRowSnapshot,
    refreshedEntry: ConciergeBatchReplacementReviewEntry
) -> ConciergeBatchReviewRowChangeSummary? {
    let currentSnapshot = conciergeBatchReviewRowSnapshot(for: refreshedEntry)
    guard previousSnapshot != currentSnapshot else {
        return nil
    }

    var title = "Booking updated"
    var supporting = "This provider row changed after your last review action."
    var tint = BrandPalette.sky
    var highlights: [String] = []
    var marksRecoveryReady = false

    if previousSnapshot.reviewState != currentSnapshot.reviewState {
        switch (previousSnapshot.reviewState, currentSnapshot.reviewState) {
        case (.manualReview, .ready):
            title = "Now ready to switch"
            supporting = "Manual review cleared and a ranked backup is ready on this row."
            tint = BrandPalette.teal
            marksRecoveryReady = true
            highlights.append("This booking moved from manual review into ready-to-switch mode.")
        case (.loading, .ready):
            title = "Backup ranking complete"
            supporting = "Local backup ranking finished for this booking."
            tint = BrandPalette.teal
            marksRecoveryReady = true
            highlights.append("Ranking finished and the queue can switch this provider now.")
        case (.ready, .manualReview), (.loading, .manualReview):
            title = "Needs manual review again"
            supporting = "This row moved out of auto-switch mode."
            tint = BrandPalette.coral
            highlights.append(
                currentSnapshot.manualReviewReason
                    ?? "A new blocker means this booking needs manual review again."
            )
        case (.manualReview, .loading):
            title = "Ranking backup options"
            supporting = "This row moved back into ranked backup search."
            tint = BrandPalette.sky
            highlights.append("Manual review progressed and the app is checking local replacement options again.")
        case (_, .unavailable):
            title = "Booking cleared"
            supporting = "This provider row is no longer active in the settled archive."
            tint = BrandPalette.coral
            highlights.append("The active concierge booking cleared out of this review selection.")
        default:
            title = "Review state changed"
            supporting = "This booking moved to a new review state."
            tint = currentSnapshot.reviewState == .ready ? BrandPalette.teal : BrandPalette.sky
            highlights.append(
                "Row moved from \(previousSnapshot.reviewState.title.lowercased()) to \(currentSnapshot.reviewState.title.lowercased())."
            )
        }
    }

    if previousSnapshot.providerID != currentSnapshot.providerID,
       let providerName = currentSnapshot.providerName {
        if title == "Booking updated" {
            title = "Provider updated"
            supporting = "The active concierge booking is now attached to a different provider."
            tint = BrandPalette.teal
        }
        highlights.append("Current provider is now \(providerName).")
    }

    if previousSnapshot.suggestedProviderID != currentSnapshot.suggestedProviderID,
       let suggestedProviderName = currentSnapshot.suggestedProviderName {
        if title == "Booking updated" {
            title = "Backup recommendation updated"
            supporting = "The top-ranked local backup changed on refresh."
            tint = BrandPalette.sky
        }
        highlights.append("Top ranked backup is now \(suggestedProviderName).")
    }

    if previousSnapshot.scheduledFor != currentSnapshot.scheduledFor,
       let scheduledFor = currentSnapshot.scheduledFor {
        if title == "Booking updated" {
            title = "Schedule updated"
            supporting = "The concierge service time changed after your last action."
            tint = BrandPalette.sky
        }
        highlights.append("Booked for \(shortDateString(scheduledFor)) at \(timeString(scheduledFor)).")
    }

    if previousSnapshot.isProviderConfirmed == false && currentSnapshot.isProviderConfirmed {
        if title == "Booking updated" {
            title = "Provider confirmed"
            supporting = "The provider has now confirmed the booking."
            tint = BrandPalette.teal
        }
        highlights.append("Provider confirmation is now on file for this booking.")
    }

    if currentSnapshot.followUpCount > previousSnapshot.followUpCount {
        if title == "Booking updated" {
            title = "Follow-up logged"
            supporting = "A fresh provider follow-up was recorded on this row."
            tint = BrandPalette.gold
        }
        let addedCount = currentSnapshot.followUpCount - previousSnapshot.followUpCount
        highlights.append("\(addedCount) new follow-up\(addedCount == 1 ? "" : "s") logged since the last review.")
    }

    if previousSnapshot.snoozedUntil != currentSnapshot.snoozedUntil {
        if let snoozedUntil = currentSnapshot.snoozedUntil {
            if title == "Booking updated" {
                title = "Reminder snoozed"
                supporting = "The provider reminder window was paused for this booking."
                tint = BrandPalette.gold
            }
            highlights.append("Reminder snoozed until \(shortDateString(snoozedUntil)) at \(timeString(snoozedUntil)).")
        } else if previousSnapshot.snoozedUntil != nil {
            if title == "Booking updated" {
                title = "Reminder resumed"
                supporting = "The snoozed reminder window is active again."
                tint = BrandPalette.sky
            }
            highlights.append("The reminder snooze was cleared on this booking.")
        }
    }

    if previousSnapshot.hasOpenIssue == false && currentSnapshot.hasOpenIssue {
        if title == "Booking updated" {
            title = "Issue logged"
            supporting = "This booking now has an open concierge issue on file."
            tint = BrandPalette.coral
        }
        let issueTitle = currentSnapshot.issueTitle ?? "New issue"
        highlights.append("Open issue logged: \(issueTitle).")
    }

    if previousSnapshot.hasOpenIssue && currentSnapshot.hasResolvedIssue {
        if title == "Booking updated" {
            title = "Issue resolved"
            supporting = "The provider issue was resolved after your last review action."
            tint = BrandPalette.teal
        }
        let issueTitle = currentSnapshot.issueTitle ?? "Provider issue"
        highlights.append("\(issueTitle) is now marked resolved.")
    }

    if previousSnapshot.isQuoteApproved == false && currentSnapshot.isQuoteApproved {
        if title == "Booking updated" {
            title = "Quote approved"
            supporting = "The provider quote is now approved for this booking."
            tint = BrandPalette.teal
        }
        highlights.append("Quote approval is now on file for the current provider.")
    }

    if previousSnapshot.invoiceUploadedAt == nil && currentSnapshot.invoiceUploadedAt != nil {
        if title == "Booking updated" {
            title = "Invoice added"
            supporting = "A provider invoice landed on this booking."
            tint = BrandPalette.sky
        }
        highlights.append("Invoice uploaded and attached to the active provider record.")
    }

    if previousSnapshot.paymentConfirmedAt == nil && currentSnapshot.paymentConfirmedAt != nil {
        if title == "Booking updated" {
            title = "Payment recorded"
            supporting = "Payment proof is now attached to this concierge booking."
            tint = BrandPalette.teal
        }
        highlights.append("Payment confirmation is now saved in the archive.")
    }

    if previousSnapshot.reviewState == .manualReview,
       currentSnapshot.reviewState == .manualReview,
       previousSnapshot.manualReviewReason != currentSnapshot.manualReviewReason,
       let manualReviewReason = currentSnapshot.manualReviewReason {
        if title == "Booking updated" {
            title = "Manual review focus changed"
            supporting = "The reason this row needs manual review shifted after refresh."
            tint = BrandPalette.gold
        }
        highlights.append(manualReviewReason)
    }

    guard highlights.isEmpty == false else {
        return nil
    }

    return ConciergeBatchReviewRowChangeSummary(
        title: title,
        supporting: supporting,
        highlights: Array(highlights.prefix(3)),
        tint: tint,
        marksRecoveryReady: marksRecoveryReady
    )
}

private func conciergeBatchReviewCompletionGuidance(
    for entries: [ConciergeBatchReplacementReviewEntry]
) -> ConciergeBatchReviewCompletionGuidance? {
    let items = entries.compactMap(conciergeBatchReviewCompletionItem(for:))
    let safeToCloseItems = items.filter { $0.group == .safeToClose }
    let needsFinalStepItems = items.filter { $0.group == .needsFinalStep }

    guard safeToCloseItems.isEmpty == false || needsFinalStepItems.isEmpty == false else {
        return nil
    }

    let title: String
    let message: String
    switch (safeToCloseItems.isEmpty, needsFinalStepItems.isEmpty) {
    case (false, false):
        title = "Close what is done, finish what is left"
        message = "\(safeToCloseItems.count) row\(safeToCloseItems.count == 1 ? "" : "s") are stable enough to close now. \(needsFinalStepItems.count) row\(needsFinalStepItems.count == 1 ? "" : "s") still need one last step before this review is fully wrapped."
    case (false, true):
        title = "This review is safe to close"
        message = "Every remaining row is stable for now, so you can leave the review and come back only if a new provider issue appears."
    case (true, false):
        title = "A few rows still need one last step"
        message = "Keep this review open for the remaining provider threads below so you can finish the final action cleanly."
    case (true, true):
        return nil
    }

    return ConciergeBatchReviewCompletionGuidance(
        title: title,
        message: message,
        safeToCloseItems: safeToCloseItems,
        needsFinalStepItems: needsFinalStepItems
    )
}

private func conciergeBatchReviewRowTitle(
    for entry: ConciergeBatchReplacementReviewEntry
) -> String {
    "\(entry.serviceKind.title) • \(entry.listing.address.suburb)"
}

private func conciergeBatchReviewEntryReference(
    for entry: ConciergeBatchReplacementReviewEntry
) -> ConciergeBatchReviewEntryReference {
    ConciergeBatchReviewEntryReference(
        id: entry.id,
        offerID: entry.offerID,
        listing: entry.listing,
        serviceKind: entry.serviceKind,
        counterpartLabel: entry.counterpartLabel,
        counterpartName: entry.counterpartName
    )
}

private func conciergeBatchReviewCompletionItem(
    for entry: ConciergeBatchReplacementReviewEntry
) -> ConciergeBatchReviewCompletionItem? {
    let rowTitle = "\(entry.serviceKind.title) • \(entry.listing.address.suburb)"

    guard let booking = entry.currentBooking else {
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "This provider row has already cleared from the active archive, so there is nothing left to review here.",
            symbolName: "checkmark.circle.fill",
            tint: BrandPalette.teal,
            group: .safeToClose
        )
    }

    if entry.canApplySuggestedReplacement,
       let suggestedProvider = entry.suggestedReplacement?.provider.name {
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "Apply the ranked backup to switch this booking over to \(suggestedProvider).",
            symbolName: "arrow.triangle.2.circlepath.circle.fill",
            tint: BrandPalette.teal,
            group: .needsFinalStep
        )
    }

    if entry.isLoadingSuggestion {
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "Real O Who is still ranking local backups for this provider thread, so keep the review open until the replacement finishes loading.",
            symbolName: "hourglass.circle.fill",
            tint: BrandPalette.sky,
            group: .needsFinalStep
        )
    }

    if booking.isProviderConfirmed {
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "The provider is confirmed on this booking, so this row can safely leave the review unless a new issue comes in later.",
            symbolName: "checkmark.seal.fill",
            tint: BrandPalette.teal,
            group: .safeToClose
        )
    }

    if let snoozedUntil = booking.reminderSnoozedUntil,
       snoozedUntil > .now,
       booking.needsResponseFollowUp == false,
       booking.hasOpenIssue == false {
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "The reminder is snoozed until \(shortDateString(snoozedUntil)) at \(timeString(snoozedUntil)), so you can close this row until the follow-up window returns.",
            symbolName: "bell.slash.fill",
            tint: BrandPalette.gold,
            group: .safeToClose
        )
    }

    switch conciergeAttentionPrimaryAction(for: booking) {
    case .switchProvider:
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "Open the replacement flow to compare providers and finish resolving this stalled booking.",
            symbolName: "arrow.triangle.branch",
            tint: booking.hasOpenIssue ? BrandPalette.coral : BrandPalette.navy,
            group: .needsFinalStep
        )
    case .callProvider:
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "Open the booking and log direct provider follow-up so this overdue reply window is handled before you close the review.",
            symbolName: "phone.fill",
            tint: BrandPalette.coral,
            group: .needsFinalStep
        )
    case .reviewBooking:
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "Give this booking one last review to check the saved provider, timing, and reminder state before you leave the queue.",
            symbolName: "doc.text.magnifyingglass",
            tint: BrandPalette.navy,
            group: .needsFinalStep
        )
    case .viewBooking:
        return ConciergeBatchReviewCompletionItem(
            id: entry.id,
            title: rowTitle,
            supporting: "This row is stable enough to close for now. You only need to reopen it if a new provider issue appears.",
            symbolName: "checkmark.circle.fill",
            tint: BrandPalette.teal,
            group: .safeToClose
        )
    }
}

private func conciergeBatchReviewRefreshSummary(
    hubTitle: String,
    actionTitle: String,
    actionMessage: String,
    previousSelectionCount: Int,
    refreshedEntries: [ConciergeBatchReplacementReviewEntry],
    itemTitlesByID: [String: String] = [:],
    itemReferencesByID: [String: ConciergeBatchReviewEntryReference] = [:],
    currentStagedEntryIDs: [String] = [],
    reviewedRefreshHighlightCount: Int = 0,
    appliedRefreshHighlightCount: Int = 0,
    reviewedRefreshHighlightIDs: [String] = [],
    appliedRefreshHighlightIDs: [String] = []
) -> ConciergeBatchReviewRefreshSummary {
    let remainingCount = refreshedEntries.count
    let clearedCount = max(0, previousSelectionCount - remainingCount)
    let readyCount = refreshedEntries.filter(\.canApplySuggestedReplacement).count
    let loadingCount = refreshedEntries.filter(\.isLoadingSuggestion).count
    let manualCount = refreshedEntries.filter {
        $0.isLoadingSuggestion == false && $0.canApplySuggestedReplacement == false
    }.count

    var messageParts = [actionMessage]
    if clearedCount > 0 {
        messageParts.append("\(clearedCount) review row\(clearedCount == 1 ? "" : "s") cleared.")
    }
    if remainingCount > 0 {
        messageParts.append("\(remainingCount) row\(remainingCount == 1 ? "" : "s") still selected.")
    }
    if appliedRefreshHighlightCount > 0 {
        messageParts.append(
            "\(appliedRefreshHighlightCount) refreshed row\(appliedRefreshHighlightCount == 1 ? " was" : "s were") consumed by the apply."
        )
    }
    if reviewedRefreshHighlightCount > 0 {
        messageParts.append(
            "\(reviewedRefreshHighlightCount) refreshed row\(reviewedRefreshHighlightCount == 1 ? " had" : "s had") already been marked reviewed."
        )
    }

    var supportingParts = ["\(hubTitle) selection refreshed."]
    if readyCount > 0 {
        supportingParts.append("\(readyCount) ready to switch")
    }
    if manualCount > 0 {
        supportingParts.append("\(manualCount) still need manual review")
    }
    if loadingCount > 0 {
        supportingParts.append("\(loadingCount) checking ranked backups")
    }
    if appliedRefreshHighlightCount > 0 {
        supportingParts.append("\(appliedRefreshHighlightCount) refreshed row\(appliedRefreshHighlightCount == 1 ? "" : "s") applied")
    }
    if reviewedRefreshHighlightCount > 0 {
        supportingParts.append("\(reviewedRefreshHighlightCount) refreshed row\(reviewedRefreshHighlightCount == 1 ? "" : "s") already reviewed")
    }

    let activeEntryIDs = Set(refreshedEntries.map(\.id))
    let stagedEntryIDSet = Set(currentStagedEntryIDs)

    let appliedRefreshItems: [ConciergeBatchReviewRefreshOutcomeItem] = appliedRefreshHighlightIDs.compactMap { entryID in
        guard let title = itemTitlesByID[entryID] else {
            return nil
        }

        let action: ConciergeBatchReviewRefreshOutcomeAction?
        if activeEntryIDs.contains(entryID) {
            action = ConciergeBatchReviewRefreshOutcomeAction(
                title: stagedEntryIDSet.contains(entryID) ? "Jump to staged row" : "Jump to review row",
                kind: .jumpToReviewRow
            )
        } else if itemReferencesByID[entryID] != nil {
            action = ConciergeBatchReviewRefreshOutcomeAction(
                title: "Open booking",
                kind: .openBooking
            )
        } else {
            action = nil
        }

        return ConciergeBatchReviewRefreshOutcomeItem(
            id: entryID,
            kind: .applied,
            title: title,
            supporting: "This refreshed staged row was included in the apply before the review reopened.",
            tint: BrandPalette.teal,
            symbolName: "checkmark.circle.fill",
            action: action,
            entryReference: itemReferencesByID[entryID]
        )
    }

    let reviewedRefreshItems: [ConciergeBatchReviewRefreshOutcomeItem] = reviewedRefreshHighlightIDs.compactMap { entryID in
        guard let title = itemTitlesByID[entryID] else {
            return nil
        }

        let action: ConciergeBatchReviewRefreshOutcomeAction?
        if activeEntryIDs.contains(entryID) {
            action = ConciergeBatchReviewRefreshOutcomeAction(
                title: stagedEntryIDSet.contains(entryID) ? "Jump to staged row" : "Jump to review row",
                kind: .jumpToReviewRow
            )
        } else if itemReferencesByID[entryID] != nil {
            action = ConciergeBatchReviewRefreshOutcomeAction(
                title: "Open booking",
                kind: .openBooking
            )
        } else {
            action = nil
        }

        return ConciergeBatchReviewRefreshOutcomeItem(
            id: entryID,
            kind: .reviewed,
            title: title,
            supporting: "This refreshed staged row had already been cleared as reviewed before the reopen.",
            tint: BrandPalette.navy,
            symbolName: "eye.circle.fill",
            action: action,
            entryReference: itemReferencesByID[entryID]
        )
    }

    return ConciergeBatchReviewRefreshSummary(
        title: "\(actionTitle) • Review refreshed",
        message: messageParts.joined(separator: " "),
        supporting: supportingParts.joined(separator: " • "),
        appliedRefreshItems: appliedRefreshItems,
        reviewedRefreshItems: reviewedRefreshItems
    )
}

private func conciergeBatchReviewRefreshLaneProgress(
    selectedID: String,
    items: [ConciergeBatchReviewRefreshOutcomeItem]
) -> ConciergeBatchReviewRefreshLaneProgress? {
    guard let selectedIndex = items.firstIndex(where: { $0.id == selectedID }) else {
        return nil
    }

    let selectedItem = items[selectedIndex]
    let remainingCount = max(0, items.count - 1)
    let title = items.count == 1
        ? "Live lane is focused"
        : "Showing \(selectedIndex + 1) of \(items.count) live rows"

    let message: String
    if remainingCount == 0 {
        message = "\(selectedItem.title) is the only live row left in this refresh lane."
    } else {
        message = "\(selectedItem.title) is the current live-row jump target. \(remainingCount) more live row\(remainingCount == 1 ? "" : "s") still need attention in this lane."
    }

    return ConciergeBatchReviewRefreshLaneProgress(
        lastItemID: selectedID,
        title: title,
        message: message,
        highlightTitle: "Last jumped",
        nextItemID: items.count > 1 ? items[(selectedIndex + 1) % items.count].id : nil,
        remainingCount: remainingCount,
        totalCount: items.count
    )
}

private func conciergeBatchReviewBookingLaneProgress(
    visitedIDs: [String],
    items: [ConciergeBatchReviewRefreshOutcomeItem]
) -> ConciergeBatchReviewRefreshLaneProgress? {
    let uniqueVisitedIDs = Array(Set(visitedIDs))
    guard items.isEmpty == false,
          let lastVisitedID = visitedIDs.last,
          let lastVisitedItem = items.first(where: { $0.id == lastVisitedID }) else {
        return nil
    }

    let visitedCount = items.filter { uniqueVisitedIDs.contains($0.id) }.count
    let remainingItems = items.filter { uniqueVisitedIDs.contains($0.id) == false }
    let remainingCount = remainingItems.count
    let nextItem = remainingItems.first
    let title: String
    if remainingCount == 0 {
        title = "Booking lane fully revisited"
    } else {
        title = visitedCount == 1
            ? "1 booking row already revisited"
            : "\(visitedCount) booking rows already revisited"
    }

    let message: String
    if remainingCount == 0 {
        message = "\(lastVisitedItem.title) was the most recent booking follow-through opened, and every booking row in this lane has now been revisited. The next tap will cycle back through those booking follow-through rows."
    } else {
        let nextItemLine = nextItem.map { " Next up: \($0.title)." } ?? ""
        message = "\(lastVisitedItem.title) was the most recent booking follow-through opened. \(remainingCount) booking row\(remainingCount == 1 ? "" : "s") still need follow-through from this lane.\(nextItemLine)"
    }

    return ConciergeBatchReviewRefreshLaneProgress(
        lastItemID: lastVisitedID,
        title: title,
        message: message,
        highlightTitle: "Last opened",
        nextItemID: nextItem?.id,
        remainingCount: remainingCount,
        totalCount: items.count
    )
}

private func conciergeBatchReviewRankingUpdateSummary(
    hubTitle: String,
    resolvedEntries: [ConciergeBatchReplacementReviewEntry],
    previousSnapshotsByID: [String: ConciergeBatchReviewRowSnapshot],
    remainingLoadingCount: Int
) -> ConciergeBatchReviewRankingUpdateSummary? {
    guard resolvedEntries.isEmpty == false else {
        return nil
    }

    let newlyReadyEntries = resolvedEntries.filter { entry in
        guard let previousSnapshot = previousSnapshotsByID[entry.id] else {
            return false
        }
        return previousSnapshot.reviewState != .ready && entry.canApplySuggestedReplacement
    }
    let manualReviewCount = resolvedEntries.filter {
        $0.currentBooking != nil &&
        $0.isLoadingSuggestion == false &&
        $0.canApplySuggestedReplacement == false
    }.count
    let unavailableCount = resolvedEntries.filter { $0.currentBooking == nil }.count

    guard newlyReadyEntries.isEmpty == false || manualReviewCount > 0 || unavailableCount > 0 else {
        return nil
    }

    let title: String
    if newlyReadyEntries.isEmpty == false {
        title = newlyReadyEntries.count == 1
            ? "1 backup just became ready"
            : "\(newlyReadyEntries.count) backups just became ready"
    } else if manualReviewCount > 0 {
        title = manualReviewCount == 1
            ? "1 row still needs manual review"
            : "\(manualReviewCount) rows still need manual review"
    } else {
        title = unavailableCount == 1
            ? "1 row cleared during ranking"
            : "\(unavailableCount) rows cleared during ranking"
    }

    var messageParts = ["Ranking finished for \(resolvedEntries.count) row\(resolvedEntries.count == 1 ? "" : "s")."]
    if newlyReadyEntries.isEmpty == false {
        messageParts.append(
            "\(newlyReadyEntries.count) \(newlyReadyEntries.count == 1 ? "is" : "are") ready to switch right now."
        )
    }
    if manualReviewCount > 0 {
        messageParts.append(
            "\(manualReviewCount) \(manualReviewCount == 1 ? "still needs" : "still need") manual review."
        )
    }
    if unavailableCount > 0 {
        messageParts.append(
            "\(unavailableCount) \(unavailableCount == 1 ? "cleared" : "cleared") out of the live archive selection."
        )
    }

    var supportingParts = ["\(hubTitle) review updated live."]
    if newlyReadyEntries.isEmpty == false {
        supportingParts.append("Newly ready rows move to the apply section automatically")
    }
    if remainingLoadingCount > 0 {
        supportingParts.append("\(remainingLoadingCount) more still ranking")
    } else {
        supportingParts.append("No remaining ranking checks are running")
    }

    return ConciergeBatchReviewRankingUpdateSummary(
        title: title,
        message: messageParts.joined(separator: " "),
        supporting: supportingParts.joined(separator: " • "),
        newlyReadyEntryIDs: newlyReadyEntries.map(\.id)
    )
}

private func conciergeBatchReviewStagedNote(
    for entry: ConciergeBatchReplacementReviewEntry,
    isApproved: Bool,
    isInvalidated: Bool,
    isRefreshHighlighted: Bool
) -> ConciergeBatchReviewStagedNote? {
    guard let suggestion = entry.suggestedReplacement,
          let currentProvider = entry.currentProvider else {
        return nil
    }

    let beforeLine: String
    if let rowChangeSummary = entry.rowChangeSummary {
        beforeLine = "\(rowChangeSummary.title): \(rowChangeSummary.supporting)"
    } else if let manualReviewReason = entry.manualReviewReason {
        beforeLine = manualReviewReason
    } else {
        beforeLine = "This booking was still waiting on a safe backup decision before the new ranking result arrived."
    }

    var whySafe = suggestion.safetySummary.reasons
    if let firstKeep = suggestion.impactSummary.keeps.first {
        whySafe.append(firstKeep)
    }

    return ConciergeBatchReviewStagedNote(
        id: entry.id,
        title: "\(entry.serviceKind.title) • \(entry.listing.address.suburb)",
        serviceSymbolName: entry.serviceKind.symbolName,
        beforeLine: beforeLine,
        afterLine: "Now ready to switch from \(currentProvider.name) to \(suggestion.provider.name). \(suggestion.statusLine)",
        whySafe: Array(whySafe.prefix(3)),
        tint: suggestion.safetySummary.tint,
        isApproved: isApproved,
        isInvalidated: isInvalidated,
        isRefreshHighlighted: isRefreshHighlighted
    )
}

private func conciergeBatchReviewStagedApprovalFingerprint(
    for entry: ConciergeBatchReplacementReviewEntry
) -> String? {
    guard let suggestion = entry.suggestedReplacement,
          let currentProvider = entry.currentProvider else {
        return nil
    }

    return [
        entry.reviewFingerprint ?? "no-review-fingerprint",
        currentProvider.id,
        suggestion.provider.id,
        String(suggestion.score),
        suggestion.statusLine
    ].joined(separator: "|")
}

private func conciergeBatchReviewInvalidatedStagedEntryIDs(
    entries: [ConciergeBatchReplacementReviewEntry],
    stagedEntryIDs: [String],
    approvalFingerprints: [String: String]
) -> [String] {
    let entryByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    return stagedEntryIDs.filter { entryID in
        guard let storedFingerprint = approvalFingerprints[entryID],
              let entry = entryByID[entryID],
              entry.canApplySuggestedReplacement else {
            return false
        }

        return conciergeBatchReviewStagedApprovalFingerprint(for: entry) != storedFingerprint
    }
}

private func conciergeBatchReviewStagedRefreshState(
    previousStagedEntryIDs: [String],
    previousApprovalFingerprints: [String: String],
    previousRefreshHighlightedEntryIDs: [String],
    refreshedEntries: [ConciergeBatchReplacementReviewEntry]
) -> ConciergeBatchReviewStagedRefreshState {
    let refreshedEntryByID = Dictionary(uniqueKeysWithValues: refreshedEntries.map { ($0.id, $0) })
    let survivingStagedEntryIDs = previousStagedEntryIDs.filter { refreshedEntryByID[$0] != nil }
    let carriedApprovalFingerprints = previousApprovalFingerprints.filter { survivingStagedEntryIDs.contains($0.key) }
    let invalidatedEntryIDs = survivingStagedEntryIDs.filter { entryID in
        guard let previousFingerprint = carriedApprovalFingerprints[entryID],
              let entry = refreshedEntryByID[entryID] else {
            return false
        }

        return conciergeBatchReviewStagedApprovalFingerprint(for: entry) != previousFingerprint
    }

    let carriedForwardApprovalCount = survivingStagedEntryIDs.filter { entryID in
        guard let previousFingerprint = carriedApprovalFingerprints[entryID],
              let entry = refreshedEntryByID[entryID] else {
            return false
        }

        return conciergeBatchReviewStagedApprovalFingerprint(for: entry) == previousFingerprint
    }.count
    let refreshHighlightedEntryIDs = previousRefreshHighlightedEntryIDs.filter { entryID in
        guard let previousFingerprint = carriedApprovalFingerprints[entryID],
              let entry = refreshedEntryByID[entryID],
              invalidatedEntryIDs.contains(entryID) == false else {
            return false
        }

        return conciergeBatchReviewStagedApprovalFingerprint(for: entry) == previousFingerprint
    }

    let pendingDecisionCount = max(
        0,
        survivingStagedEntryIDs.count - carriedForwardApprovalCount - invalidatedEntryIDs.count
    )
    let immediateReapprovalEntries = invalidatedEntryIDs.compactMap { refreshedEntryByID[$0] }
        .filter(\.canApplySuggestedReplacement)
    let blockedInvalidationCount = max(0, invalidatedEntryIDs.count - immediateReapprovalEntries.count)

    let summary: ConciergeBatchReviewApprovalRefreshSummary?
    if previousStagedEntryIDs.isEmpty {
        summary = nil
    } else {
        let carriedCount = carriedForwardApprovalCount
        let invalidatedCount = invalidatedEntryIDs.count
        let title: String
        if carriedCount > 0 && invalidatedCount > 0 {
            title = "\(carriedCount) approval\(carriedCount == 1 ? "" : "s") carried forward, \(invalidatedCount) need \(invalidatedCount == 1 ? "a recheck" : "rechecks")"
        } else if carriedCount > 0 {
            title = carriedCount == 1
                ? "1 staged approval carried forward"
                : "\(carriedCount) staged approvals carried forward"
        } else if invalidatedCount > 0 {
            title = invalidatedCount == 1
                ? "1 staged approval was invalidated"
                : "\(invalidatedCount) staged approvals were invalidated"
        } else if pendingDecisionCount > 0 {
            title = pendingDecisionCount == 1
                ? "1 staged row is still waiting on a decision"
                : "\(pendingDecisionCount) staged rows are still waiting on a decision"
        } else {
            title = survivingStagedEntryIDs.isEmpty
                ? "No staged rows are left in this review"
                : "Staged review state carried across cleanly"
        }

        var messageParts: [String] = []
        if carriedCount > 0 {
            messageParts.append("\(carriedCount) approval\(carriedCount == 1 ? "" : "s") still match the saved switch context.")
        }
        if invalidatedCount > 0 {
            messageParts.append("\(invalidatedCount) approval\(invalidatedCount == 1 ? "" : "s") were cleared because the booking or ranked backup changed.")
        }
        if pendingDecisionCount > 0 {
            messageParts.append("\(pendingDecisionCount) staged row\(pendingDecisionCount == 1 ? " is" : "s are") still pending your decision.")
        }
        if survivingStagedEntryIDs.isEmpty {
            messageParts.append("No staged rows survived in the reopened review.")
        }
        let message = messageParts.isEmpty
            ? "The reopened review kept the same staged provider state without needing any changes."
            : messageParts.joined(separator: " ")

        var supportingParts: [String] = []
        if immediateReapprovalEntries.isEmpty == false {
            supportingParts.append("\(immediateReapprovalEntries.count) can be re-approved right away")
        }
        if blockedInvalidationCount > 0 {
            supportingParts.append("\(blockedInvalidationCount) need a fresh manual check first")
        }
        if survivingStagedEntryIDs.isEmpty == false {
            supportingParts.append("\(survivingStagedEntryIDs.count) staged row\(survivingStagedEntryIDs.count == 1 ? "" : "s") reopened in this review")
        }

        let immediateReapprovalItems = immediateReapprovalEntries.map { entry in
            ConciergeBatchReviewApprovalRefreshItem(
                id: entry.id,
                title: "\(entry.serviceKind.title) • \(entry.listing.address.suburb)",
                supporting: {
                    if let suggestedProvider = entry.suggestedReplacement?.provider.name {
                        return "Still safe to re-approve now with \(suggestedProvider) as the ranked backup."
                    }

                    return "Still safe to re-approve now with the current ranked backup."
                }()
            )
        }

        summary = ConciergeBatchReviewApprovalRefreshSummary(
            title: title,
            message: message,
            supporting: supportingParts.joined(separator: " • "),
            immediateReapprovalItems: Array(immediateReapprovalItems)
        )
    }

    return ConciergeBatchReviewStagedRefreshState(
        stagedEntryIDs: survivingStagedEntryIDs,
        approvalFingerprints: carriedApprovalFingerprints,
        refreshHighlightedEntryIDs: refreshHighlightedEntryIDs,
        invalidatedEntryIDs: invalidatedEntryIDs,
        summary: summary
    )
}

private struct PostSaleConciergeInvoiceUploadContext: Identifiable {
    let offerID: UUID
    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind

    var id: String {
        "\(offerID.uuidString)-\(serviceKind.rawValue)"
    }
}

private struct PostSaleConciergePaymentUploadContext: Identifiable {
    let offerID: UUID
    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind

    var id: String {
        "\(offerID.uuidString)-\(serviceKind.rawValue)-payment"
    }
}

private enum PostSaleConciergeResolutionMode: Equatable {
    case cancel
    case refund
    case logIssue
    case resolveIssue

    var title: String {
        switch self {
        case .cancel:
            return "Cancel booking"
        case .refund:
            return "Record refund"
        case .logIssue:
            return "Log issue"
        case .resolveIssue:
            return "Resolve issue"
        }
    }
}

private struct PostSaleConciergeResolutionContext: Identifiable {
    let offerID: UUID
    let listing: PropertyListing
    let serviceKind: PostSaleConciergeServiceKind
    let counterpartName: String
    let booking: PostSaleConciergeBooking
    let mode: PostSaleConciergeResolutionMode
    let batchReviewReturnContext: ConciergeBatchReviewReturnContext?

    init(
        offerID: UUID,
        listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind,
        counterpartName: String,
        booking: PostSaleConciergeBooking,
        mode: PostSaleConciergeResolutionMode,
        batchReviewReturnContext: ConciergeBatchReviewReturnContext? = nil
    ) {
        self.offerID = offerID
        self.listing = listing
        self.serviceKind = serviceKind
        self.counterpartName = counterpartName
        self.booking = booking
        self.mode = mode
        self.batchReviewReturnContext = batchReviewReturnContext
    }

    var id: String {
        "\(offerID.uuidString)-\(serviceKind.rawValue)-\(mode.title)-\(batchReviewReturnContext?.itemIDs.joined(separator: ",") ?? "no-return")"
    }
}

private struct ConciergeReplacementSuggestion: Identifiable {
    let provider: PostSaleConciergeProvider
    let statusLine: String
    let labels: [String]
    let score: Int
    let safetySummary: ConciergeReplacementSafetySummary
    let impactSummary: ConciergeReplacementImpactSummary

    var id: String {
        provider.id
    }
}

private struct ConciergeReplacementSafetySummary {
    let score: Int
    let title: String
    let summary: String
    let reasons: [String]
    let tint: Color

    var scoreText: String {
        let normalized = min(max(score, 0), 100)
        return "\(normalized)/100 safer fit"
    }
}

private struct ConciergeReplacementImpactSummary {
    let title: String
    let supporting: String
    let keeps: [String]
    let resets: [String]
    let archived: [String]
    let riskReduced: [String]
    let tint: Color
}

private struct ArchiveServiceRow: Identifiable {
    let kind: PostSaleServiceTaskKind
    let title: String
    let detail: String
    let isCompleted: Bool

    var id: String {
        kind.rawValue
    }
}

private struct ArchiveConciergeSpendSummary {
    let bookedCount: Int
    let completedCount: Int
    let invoicedCount: Int
    let approvedCount: Int
    let paidCount: Int
    let refundedCount: Int
    let openIssueCount: Int
    let followUpDueCount: Int
    let dueSoonCount: Int
    let snoozedCount: Int
    let providerHistoryCount: Int
    let quotedTotal: Int?
    let invoicedTotal: Int?
    let paidTotal: Int?
    let refundedTotal: Int?

    var varianceMessage: String? {
        if let paidTotal, let refundedTotal {
            let netTotal = paidTotal - refundedTotal
            return "Net concierge spend after refunds is \(currencyString(max(0, netTotal)))."
        }

        if let invoicedTotal, let paidTotal {
            let delta = paidTotal - invoicedTotal
            if delta == 0 {
                return "Recorded payments match the saved concierge invoices."
            }

            let direction = delta > 0 ? "over" : "under"
            return "Recorded payments are \(currencyString(abs(delta))) \(direction) the saved concierge invoices."
        }

        guard let quotedTotal, let invoicedTotal else {
            return nil
        }

        let delta = invoicedTotal - quotedTotal
        if delta == 0 {
            return "Final invoices are on budget against the original concierge quotes."
        }

        let direction = delta > 0 ? "over" : "under"
        return "Final invoices are \(currencyString(abs(delta))) \(direction) the original concierge quotes."
    }
}

private struct ArchiveConciergeRow: Identifiable {
    let kind: PostSaleConciergeServiceKind
    let title: String
    let detail: String
    let statusText: String
    let actionTitle: String
    let isBooked: Bool
    let isCompleted: Bool
    let isCancelled: Bool
    let isQuoteApproved: Bool
    let isProviderConfirmed: Bool
    let isReminderSnoozed: Bool
    let isResponseDueSoon: Bool
    let needsFollowUp: Bool
    let isPaid: Bool
    let isRefunded: Bool
    let hasBeenRescheduled: Bool
    let hasOpenIssue: Bool
    let hasResolvedIssue: Bool
    let issueKindTitle: String?
    let providerHistoryCount: Int
    let latestProviderAuditSummary: String?
    let estimatedCost: Int?
    let invoiceAmount: Int?
    let paidAmount: Int?
    let refundAmount: Int?
    let canApproveQuote: Bool
    let canCancel: Bool
    let canRecordRefund: Bool
    let canLogIssue: Bool
    let canResolveIssue: Bool
    let canLogFollowUp: Bool
    let canSnoozeReminder: Bool
    let canConfirmProvider: Bool
    let canMarkDone: Bool
    let canUploadInvoice: Bool
    let canUploadPaymentProof: Bool
    let hasInvoiceDocument: Bool
    let hasPaymentProofDocument: Bool
    let hasQuoteDocument: Bool
    let hasConfirmationDocument: Bool

    var id: String {
        kind.rawValue
    }
}

private struct ArchiveFeedbackRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let isSubmitted: Bool
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

private func conciergeStatusText(for booking: PostSaleConciergeBooking?) -> String {
    guard let booking else {
        return "Not booked"
    }

    if booking.isRefunded {
        return "Refunded"
    }

    if booking.isCancelled {
        return "Cancelled"
    }

    if booking.hasOpenIssue {
        return "Issue logged"
    }

    if booking.isPaid {
        return "Paid"
    }

    if booking.isCompleted {
        return "Completed"
    }

    if booking.invoiceAmount != nil || booking.hasInvoiceAttachment {
        return "Invoiced"
    }

    if booking.needsResponseFollowUp {
        return "Follow-up due"
    }

    if booking.isReminderSnoozed {
        return "Snoozed"
    }

    if booking.isResponseDueSoon {
        return "Due soon"
    }

    if booking.isProviderConfirmed {
        return "Confirmed"
    }

    if booking.isQuoteApproved {
        return "Quote approved"
    }

    if booking.hasResolvedIssue {
        return "Issue resolved"
    }

    if booking.hasBeenRescheduled {
        return "Rescheduled"
    }

    return "Scheduled"
}

private func conciergeRescheduleSummary(for booking: PostSaleConciergeBooking) -> String? {
    guard booking.hasBeenRescheduled else {
        return nil
    }

    let count = booking.rescheduleCountValue
    let base: String
    if count > 0 {
        base = "Rescheduled \(count) time\(count == 1 ? "" : "s")"
    } else {
        base = "Schedule updated"
    }

    let movedFrom = booking.previousScheduledFor.map {
        " Previously \(shortDateString($0)) at \(timeString($0))."
    } ?? ""
    let movedBy = booking.lastRescheduledByName.map { " Last moved by \($0)." } ?? ""
    return base + "." + movedFrom + movedBy
}

private func conciergeIssueSummary(for booking: PostSaleConciergeBooking) -> String? {
    guard let issueKind = booking.issueKind else {
        return nil
    }

    let note = booking.issueNote.map { " Note: \($0)." } ?? ""
    if booking.hasOpenIssue {
        return "Issue logged: \(issueKind.title).\(note)"
    }

    if booking.hasResolvedIssue {
        let resolution = booking.issueResolutionNote.map { " Resolution: \($0)." } ?? ""
        return "Issue resolved: \(issueKind.title).\(resolution)"
    }

    return "Issue recorded: \(issueKind.title).\(note)"
}

private func conciergeProviderConfirmationSummary(for booking: PostSaleConciergeBooking) -> String? {
    guard let confirmedAt = booking.providerConfirmedAt else {
        return nil
    }

    let actorLine = booking.providerConfirmedByName.map { " by \($0)" } ?? ""
    let noteLine = booking.providerConfirmationNote.map { " Note: \($0)." } ?? ""
    return "Provider confirmed \(relativeDateString(confirmedAt))\(actorLine).\(noteLine)"
}

private func conciergeResponseSLASummary(for booking: PostSaleConciergeBooking) -> String? {
    guard let responseDueAt = booking.responseDueAt else {
        return nil
    }

    let dueLine = "Reply target: \(shortDateString(responseDueAt)) at \(timeString(responseDueAt)) from the saved \(booking.responseExpectationHoursValue)-hour response estimate."
    if booking.needsResponseFollowUp {
        return "Provider confirmation is overdue. \(dueLine)"
    }

    if let reminderSnoozedUntil = booking.reminderSnoozedUntil,
       reminderSnoozedUntil > .now {
        return "\(dueLine) Reminder snoozed until \(shortDateString(reminderSnoozedUntil)) at \(timeString(reminderSnoozedUntil))."
    }

    if booking.isResponseDueSoon {
        return "Provider confirmation is due soon. \(dueLine)"
    }

    return dueLine
}

private func conciergeFollowUpSummary(for booking: PostSaleConciergeBooking) -> String? {
    guard let lastFollowUpAt = booking.lastFollowUpAt else {
        return nil
    }

    let actorLine = booking.lastFollowUpByName.map { " by \($0)" } ?? ""
    let count = booking.followUpCountValue
    let countLine = count > 0 ? " \(count) follow-up\(count == 1 ? "" : "s") logged." : ""
    let noteLine = booking.lastFollowUpNote.map { " Note: \($0)." } ?? ""
    return "Latest follow-up \(relativeDateString(lastFollowUpAt))\(actorLine).\(countLine)\(noteLine)"
}

private func conciergeProviderAuditSummary(for booking: PostSaleConciergeBooking) -> String? {
    guard let latestEntry = booking.latestProviderAuditEntry else {
        return nil
    }

    let count = booking.providerHistoryCountValue
    let prefix: String
    if count == 1 {
        prefix = "Previous provider kept in archive"
    } else {
        prefix = "\(count) previous providers kept in archive"
    }

    let replacedLine = " Latest: \(latestEntry.provider.name), replaced \(relativeDateString(latestEntry.replacedAt))."
    let confirmationLine = latestEntry.providerConfirmedAt.map {
        " Confirmed \(relativeDateString($0))."
    } ?? ""
    let confirmationNoteLine = latestEntry.providerConfirmationNote.map { " Note: \($0)." } ?? ""
    let followUpLine = latestEntry.lastFollowUpAt.map {
        " Follow-up logged \(relativeDateString($0))."
    } ?? ""
    let followUpCountLine = latestEntry.followUpCount.map {
        $0 > 0 ? " \($0) follow-up\($0 == 1 ? "" : "s") saved." : ""
    } ?? ""
    let issueLine = latestEntry.issueKind.map {
        latestEntry.issueResolvedAt == nil
            ? " Issue logged: \($0.title)."
            : " Resolved issue: \($0.title)."
    } ?? ""
    let financeLine: String
    if let refundAmount = latestEntry.refundAmount {
        financeLine = " Refund: \(currencyString(refundAmount))."
    } else if let paidAmount = latestEntry.paidAmount {
        financeLine = " Paid: \(currencyString(paidAmount))."
    } else if let invoiceAmount = latestEntry.invoiceAmount {
        financeLine = " Invoice: \(currencyString(invoiceAmount))."
    } else if let estimatedCost = latestEntry.estimatedCost {
        financeLine = " Quote: \(currencyString(estimatedCost))."
    } else {
        financeLine = ""
    }
    return prefix + "." + replacedLine + confirmationLine + confirmationNoteLine + followUpLine + followUpCountLine + issueLine + financeLine
}

private func conciergeAttentionActivityLines(
    for offer: OfferRecord,
    serviceKind: PostSaleConciergeServiceKind
) -> [String] {
    guard let booking = offer.conciergeBooking(for: serviceKind) else {
        return []
    }

    var lines: [String] = []

    if booking.isReminderSnoozed, let snoozedUntil = booking.reminderSnoozedUntil {
        lines.append("Reminder snoozed until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened)).")
    } else if let responseDueAt = booking.responseDueAt {
        if booking.needsResponseFollowUp {
            lines.append("Provider reply overdue since \(responseDueAt.formatted(date: .abbreviated, time: .shortened)).")
        } else if booking.isResponseDueSoon {
            lines.append("Provider reply due by \(responseDueAt.formatted(date: .abbreviated, time: .shortened)).")
        }
    }

    if let lastFollowUpAt = booking.lastFollowUpAt {
        let followUpBy = booking.lastFollowUpByName ?? "a team member"
        let count = booking.followUpCountValue
        let countLine = count == 1 ? "1 follow-up logged" : "\(count) follow-ups logged"
        var line = "Last follow-up \(relativeDateString(lastFollowUpAt)) by \(followUpBy) • \(countLine)."
        if let note = booking.lastFollowUpNote?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            line += " \(note)"
        }
        lines.append(line)
    }

    if let providerConfirmedAt = booking.providerConfirmedAt {
        let confirmedBy = booking.providerConfirmedByName ?? "the team"
        var line = "Provider confirmed \(relativeDateString(providerConfirmedAt)) by \(confirmedBy)."
        if let note = booking.providerConfirmationNote?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            line += " \(note)"
        }
        lines.append(line)
    }

    if let issueKind = booking.issueKind {
        if booking.hasOpenIssue {
            let loggedAt = booking.issueLoggedAt.map(shortDateString) ?? "recently"
            var line = "Open issue: \(issueKind.title) logged \(loggedAt)."
            if let note = booking.issueNote?.trimmingCharacters(in: .whitespacesAndNewlines),
               !note.isEmpty {
                line += " \(note)"
            }
            lines.append(line)
        } else if booking.hasResolvedIssue {
            let resolvedAt = booking.issueResolvedAt.map(shortDateString) ?? "recently"
            var line = "Resolved issue: \(issueKind.title) closed \(resolvedAt)."
            if let note = booking.issueResolutionNote?.trimmingCharacters(in: .whitespacesAndNewlines),
               !note.isEmpty {
                line += " \(note)"
            }
            lines.append(line)
        }
    }

    if let latestAudit = booking.latestProviderAuditEntry {
        lines.append("Previous provider \(latestAudit.provider.name) was replaced \(relativeDateString(latestAudit.replacedAt)).")
    }

    return Array(lines.prefix(4))
}

private func conciergeAttentionRecommendation(
    for booking: PostSaleConciergeBooking
) -> ConciergeAttentionRecommendation {
    if booking.hasOpenIssue {
        return ConciergeAttentionRecommendation(
            title: "Resolve the provider issue",
            supporting: "There is already an open issue on this booking. Keep the provider thread moving and close the issue once the blocker is fixed.",
            primaryActionKind: .switchProvider,
            primaryActionTitle: "Switch provider",
            tint: BrandPalette.coral,
            background: BrandPalette.coral.opacity(0.12),
            symbolName: "exclamationmark.bubble.fill"
        )
    }

    if booking.needsResponseFollowUp && booking.followUpCountValue >= 2 {
        return ConciergeAttentionRecommendation(
            title: "Escalate this booking",
            supporting: "Multiple follow-ups are already saved. Log an issue or prepare to switch providers if they still do not respond.",
            primaryActionKind: .switchProvider,
            primaryActionTitle: "Switch provider",
            tint: BrandPalette.coral,
            background: BrandPalette.coral.opacity(0.12),
            symbolName: "arrow.triangle.branch"
        )
    }

    if booking.needsResponseFollowUp, conciergeProviderCallURL(booking.provider) != nil {
        return ConciergeAttentionRecommendation(
            title: "Call the provider now",
            supporting: "The reply window is already overdue, so direct outreach is the fastest way to unblock settlement handover.",
            primaryActionKind: .callProvider,
            primaryActionTitle: "Call status",
            tint: BrandPalette.coral,
            background: BrandPalette.coral.opacity(0.12),
            symbolName: "phone.fill"
        )
    }

    if booking.isResponseDueSoon, conciergeProviderCallURL(booking.provider) != nil {
        return ConciergeAttentionRecommendation(
            title: "Prepare outreach",
            supporting: "The provider reply window closes soon. Call if they do not confirm in time, or keep the reminder live from this queue.",
            primaryActionKind: .reviewBooking,
            primaryActionTitle: "Review booking",
            tint: BrandPalette.gold,
            background: BrandPalette.gold.opacity(0.18),
            symbolName: "phone.arrow.up.right.fill"
        )
    }

    if booking.isProviderConfirmed {
        return ConciergeAttentionRecommendation(
            title: "Provider already confirmed",
            supporting: "This booking has a saved confirmation. Use the queue to monitor the next handover step or any new issue.",
            primaryActionKind: .viewBooking,
            primaryActionTitle: "View booking",
            tint: BrandPalette.teal,
            background: BrandPalette.teal.opacity(0.14),
            symbolName: "checkmark.circle.fill"
        )
    }

    return ConciergeAttentionRecommendation(
        title: "Review the booking details",
        supporting: "Open the booking to check the saved schedule, provider details, and next action before the reminder escalates further.",
        primaryActionKind: .reviewBooking,
        primaryActionTitle: "Review booking",
        tint: BrandPalette.navy,
        background: BrandPalette.navy.opacity(0.10),
        symbolName: "doc.text.magnifyingglass"
    )
}

private func conciergeAttentionPrimaryAction(
    for booking: PostSaleConciergeBooking
) -> ConciergeAttentionPrimaryActionKind {
    conciergeAttentionRecommendation(for: booking).primaryActionKind
}

private func conciergeReplacementPreviewFingerprint(
    for booking: PostSaleConciergeBooking,
    strategy: ConciergeReplacementStrategy
) -> String {
    [
        strategy.rawValue,
        booking.provider.id,
        booking.status.rawValue,
        booking.issueKind?.rawValue ?? "none",
        booking.issueLoggedAt.map { String($0.timeIntervalSince1970) } ?? "no-issue-date",
        booking.issueResolvedAt.map { String($0.timeIntervalSince1970) } ?? "no-resolution-date",
        booking.lastFollowUpAt.map { String($0.timeIntervalSince1970) } ?? "no-follow-up",
        String(booking.followUpCountValue),
        booking.lastRescheduledAt.map { String($0.timeIntervalSince1970) } ?? "no-reschedule",
        booking.providerConfirmedAt.map { String($0.timeIntervalSince1970) } ?? "no-confirmation"
    ].joined(separator: "|")
}

private func conciergeResolvedReplacementWeighting(
    for currentBooking: PostSaleConciergeBooking,
    strategy: ConciergeReplacementStrategy
) -> ConciergeReplacementWeighting {
    switch strategy {
    case .smart:
        if currentBooking.hasOpenIssue {
            switch currentBooking.issueKind {
            case .providerNoShow, .schedulingProblem:
                return .fastestRecovery
            case .serviceQuality:
                return .qualityFirst
            case .billingProblem:
                return .bestValue
            case .accessProblem, .other, .none:
                return .balanced
            }
        }

        if currentBooking.followUpCountValue >= 2 || currentBooking.needsResponseFollowUp {
            return .fastestRecovery
        }

        return .balanced
    case .fastestRecovery:
        return .fastestRecovery
    case .qualityFirst:
        return .qualityFirst
    case .bestValue:
        return .bestValue
    }
}

private func conciergeReplacementStrategySupportingLine(
    strategy: ConciergeReplacementStrategy,
    currentBooking: PostSaleConciergeBooking
) -> String {
    let resolvedWeighting = conciergeResolvedReplacementWeighting(
        for: currentBooking,
        strategy: strategy
    )

    switch strategy {
    case .smart:
        switch resolvedWeighting {
        case .fastestRecovery:
            return "Smart mode is prioritising faster replies and direct outreach because this booking is stalled or overdue."
        case .qualityFirst:
            return "Smart mode is prioritising stronger reviews and steadier service quality because the current provider issue points to quality risk."
        case .bestValue:
            return "Smart mode is prioritising lower starting guides because the current provider issue points to billing risk."
        case .balanced:
            return "Smart mode is using a balanced score across response time, review strength, suburb fit, and value."
        }
    case .fastestRecovery:
        return "Speed priority moves faster responders and easier-to-reach backups to the top."
    case .qualityFirst:
        return "Quality priority moves stronger-rated providers with better review depth to the top."
    case .bestValue:
        return "Value priority moves lower starting guides up without ignoring response speed or local quality."
    }
}

private func conciergeReplacementRankingScore(
    for provider: PostSaleConciergeProvider,
    currentBooking: PostSaleConciergeBooking,
    listing: PropertyListing,
    strategy: ConciergeReplacementStrategy = .smart
) -> Int {
    let weighting = conciergeResolvedReplacementWeighting(
        for: currentBooking,
        strategy: strategy
    )
    let directContactCount = [provider.phoneNumber, provider.websiteURL?.absoluteString, provider.mapsURL?.absoluteString]
        .compactMap { $0 }
        .count
    let sameSuburb = provider.suburb.caseInsensitiveCompare(listing.address.suburb) == .orderedSame

    var score = 24

    let ratingComponent = provider.rating.map { Int(($0 * 8).rounded()) } ?? 12
    let reviewComponent = min((provider.reviewCount ?? 0) / 10, 8)
    let responseComponent = max(0, 18 - min(provider.estimatedResponseHours ?? 18, 18))
    let contactComponent = min(directContactCount * 2, 6)
    let suburbComponent = sameSuburb ? 4 : 0

    if let indicativeLow = provider.indicativePriceLow {
        let valueBase = max(0, 16 - min(indicativeLow / 100, 16))
        score += valueBase
    } else {
        score += 4
    }

    switch weighting {
    case .balanced:
        score += ratingComponent + reviewComponent + responseComponent + contactComponent + suburbComponent
    case .fastestRecovery:
        score += ratingComponent / 2 + reviewComponent / 2 + (responseComponent * 2) + contactComponent + suburbComponent
    case .qualityFirst:
        score += (ratingComponent * 2) + reviewComponent + responseComponent / 2 + contactComponent / 2 + suburbComponent
    case .bestValue:
        score += ratingComponent / 2 + reviewComponent / 2 + responseComponent + contactComponent / 2 + suburbComponent
    }

    if let currentResponse = currentBooking.provider.estimatedResponseHours,
       let candidateResponse = provider.estimatedResponseHours,
       candidateResponse < currentResponse {
        let delta = currentResponse - candidateResponse
        score += weighting == .fastestRecovery ? min(delta * 3, 18) : min(delta * 2, 12)
    }

    if let currentRating = currentBooking.provider.rating,
       let candidateRating = provider.rating,
       candidateRating > currentRating {
        let deltaScore = Int(((candidateRating - currentRating) * 10).rounded())
        score += weighting == .qualityFirst ? deltaScore * 2 : deltaScore
    }

    if let candidateLow = provider.indicativePriceLow,
       let currentLow = currentBooking.provider.indicativePriceLow,
       candidateLow < currentLow {
        let delta = min((currentLow - candidateLow) / 100, weighting == .bestValue ? 14 : 8)
        score += delta
    }

    if currentBooking.hasOpenIssue {
        switch currentBooking.issueKind {
        case .providerNoShow, .schedulingProblem:
            score += max(0, 18 - (provider.estimatedResponseHours ?? 12))
        case .serviceQuality:
            score += Int(((provider.rating ?? 4.0) * 4).rounded())
        case .billingProblem:
            if let price = provider.indicativePriceLow {
                score += max(0, 12 - min(price / 100, 12))
            }
        case .accessProblem, .other, .none:
            score += sameSuburb ? 6 : 3
        }
    } else if currentBooking.followUpCountValue >= 2 || currentBooking.needsResponseFollowUp {
        score += max(0, 18 - (provider.estimatedResponseHours ?? 12))
    }

    return score
}

private func rankedConciergeReplacementProviders(
    for currentBooking: PostSaleConciergeBooking,
    listing: PropertyListing,
    candidates: [PostSaleConciergeProvider],
    strategy: ConciergeReplacementStrategy = .smart
) -> [PostSaleConciergeProvider] {
    candidates
        .filter { $0.id != currentBooking.provider.id }
        .sorted { left, right in
            let leftScore = conciergeReplacementRankingScore(
                for: left,
                currentBooking: currentBooking,
                listing: listing,
                strategy: strategy
            )
            let rightScore = conciergeReplacementRankingScore(
                for: right,
                currentBooking: currentBooking,
                listing: listing,
                strategy: strategy
            )

            if leftScore == rightScore {
                if left.rating == right.rating {
                    return (left.estimatedResponseHours ?? .max) < (right.estimatedResponseHours ?? .max)
                }
                return (left.rating ?? 0) > (right.rating ?? 0)
            }

            return leftScore > rightScore
        }
}

private func bestConciergeReplacementProvider(
    for currentBooking: PostSaleConciergeBooking,
    listing: PropertyListing,
    candidates: [PostSaleConciergeProvider],
    strategy: ConciergeReplacementStrategy = .smart
) -> PostSaleConciergeProvider? {
    rankedConciergeReplacementProviders(
        for: currentBooking,
        listing: listing,
        candidates: candidates,
        strategy: strategy
    ).first
}

private func conciergeReplacementStatusLine(
    for provider: PostSaleConciergeProvider,
    currentBooking: PostSaleConciergeBooking,
    score: Int,
    strategy: ConciergeReplacementStrategy = .smart
) -> String {
    let weighting = conciergeResolvedReplacementWeighting(
        for: currentBooking,
        strategy: strategy
    )

    switch weighting {
    case .fastestRecovery:
        return currentBooking.hasOpenIssue ? "Fast recovery option" : "Speed-first backup"
    case .qualityFirst:
        return currentBooking.hasOpenIssue ? "Quality-first replacement" : "Quality-first backup"
    case .bestValue:
        return currentBooking.hasOpenIssue ? "Value-focused replacement" : "Value-first backup"
    case .balanced:
        break
    }

    if currentBooking.hasOpenIssue {
        if let issueKind = currentBooking.issueKind {
            switch issueKind {
            case .providerNoShow, .schedulingProblem:
                return "Fast recovery option"
            case .serviceQuality:
                return "Quality-first replacement"
            case .billingProblem:
                return "Value-focused replacement"
            case .accessProblem, .other:
                break
            }
        }
        return "Issue-ready backup"
    }

    if currentBooking.followUpCountValue >= 2 || currentBooking.needsResponseFollowUp {
        return score >= 85 ? "Best replacement match" : "Responsive backup"
    }

    return score >= 85 ? "Best replacement match" : "Strong local backup"
}

private func conciergeReplacementLabels(
    for provider: PostSaleConciergeProvider,
    currentBooking: PostSaleConciergeBooking,
    rankedCandidates: [PostSaleConciergeProvider],
    strategy: ConciergeReplacementStrategy = .smart
) -> [String] {
    var labels: [String] = []

    if let lowestPrice = rankedCandidates.compactMap(\.indicativePriceLow).min(),
       provider.indicativePriceLow == lowestPrice {
        labels.append("Best value")
    }

    if let topRating = rankedCandidates.compactMap(\.rating).max(),
       provider.rating == topRating {
        labels.append("Top rated")
    }

    if let fastestReply = rankedCandidates.compactMap(\.estimatedResponseHours).min(),
       provider.estimatedResponseHours == fastestReply {
        labels.append("Fastest reply")
    }

    if let currentResponse = currentBooking.provider.estimatedResponseHours,
       let candidateResponse = provider.estimatedResponseHours,
       candidateResponse < currentResponse {
        labels.append("Faster reply")
    }

    if let currentRating = currentBooking.provider.rating,
       let candidateRating = provider.rating,
       candidateRating > currentRating {
        labels.append("Higher rated")
    }

    if let candidateLow = provider.indicativePriceLow,
       let currentLow = currentBooking.provider.indicativePriceLow,
       candidateLow < currentLow {
        labels.append("Better value")
    }

    if currentBooking.hasOpenIssue {
        labels.append("Issue-ready")
    } else if currentBooking.followUpCountValue >= 2 || currentBooking.needsResponseFollowUp {
        labels.append("Recovery pick")
    }

    switch conciergeResolvedReplacementWeighting(for: currentBooking, strategy: strategy) {
    case .fastestRecovery:
        labels.append("Speed priority")
    case .qualityFirst:
        labels.append("Quality priority")
    case .bestValue:
        labels.append("Value priority")
    case .balanced:
        break
    }

    var seen = Set<String>()
    return labels.filter { seen.insert($0).inserted }
}

private func conciergeReplacementSuggestion(
    for provider: PostSaleConciergeProvider,
    currentBooking: PostSaleConciergeBooking,
    listing: PropertyListing,
    rankedCandidates: [PostSaleConciergeProvider],
    strategy: ConciergeReplacementStrategy = .smart
) -> ConciergeReplacementSuggestion {
    let score = conciergeReplacementRankingScore(
        for: provider,
        currentBooking: currentBooking,
        listing: listing,
        strategy: strategy
    )
    let safetySummary = conciergeReplacementSafetySummary(
        for: provider,
        currentBooking: currentBooking,
        listing: listing,
        score: score,
        strategy: strategy
    )

    return ConciergeReplacementSuggestion(
        provider: provider,
        statusLine: conciergeReplacementStatusLine(
            for: provider,
            currentBooking: currentBooking,
            score: score,
            strategy: strategy
        ),
        labels: conciergeReplacementLabels(
            for: provider,
            currentBooking: currentBooking,
            rankedCandidates: rankedCandidates,
            strategy: strategy
        ),
        score: score,
        safetySummary: safetySummary,
        impactSummary: conciergeReplacementImpactSummary(
            for: provider,
            currentBooking: currentBooking,
            listing: listing,
            scheduledFor: currentBooking.scheduledFor,
            notes: currentBooking.notes,
            estimatedCost: currentBooking.estimatedCost,
            safetySummary: safetySummary
        )
    )
}

private func conciergeReplacementSafetySummary(
    for provider: PostSaleConciergeProvider,
    currentBooking: PostSaleConciergeBooking,
    listing: PropertyListing,
    score: Int,
    strategy: ConciergeReplacementStrategy = .smart
) -> ConciergeReplacementSafetySummary {
    let normalizedScore = min(max(score, 0), 100)
    let weighting = conciergeResolvedReplacementWeighting(
        for: currentBooking,
        strategy: strategy
    )
    let title: String
    let tint: Color

    switch normalizedScore {
    case 92...:
        title = "High-confidence backup"
        tint = BrandPalette.teal
    case 82...:
        title = "Safer backup"
        tint = BrandPalette.navy
    default:
        title = "Recovery option"
        tint = BrandPalette.gold
    }

    let summary: String
    switch weighting {
    case .fastestRecovery:
        summary = currentBooking.hasOpenIssue || currentBooking.needsResponseFollowUp || currentBooking.followUpCountValue >= 2
            ? "Prioritised to recover the booking quickly after the current provider stalled."
            : "Prioritised for the fastest recovery path if the current booking slips."
    case .qualityFirst:
        summary = "Prioritised to lower the risk of another service quality problem during handover."
    case .bestValue:
        summary = "Prioritised to reduce pricing surprises while keeping the service moving."
    case .balanced:
        if currentBooking.hasOpenIssue {
            summary = "Prioritised as the safest recovery option for the open provider issue."
        } else if currentBooking.followUpCountValue >= 2 || currentBooking.needsResponseFollowUp {
            summary = "Prioritised to get the handover moving again after repeated follow-ups."
        } else {
            summary = "Prioritised as the safest local fallback if the current booking slips again."
        }
    }

    let fasterReason: String? = {
        guard let currentResponse = currentBooking.provider.estimatedResponseHours,
              let candidateResponse = provider.estimatedResponseHours,
              candidateResponse < currentResponse else {
            return nil
        }
        let delta = currentResponse - candidateResponse
        return "Estimated to reply \(delta) hour\(delta == 1 ? "" : "s") faster than the current provider."
    }()

    let qualityReason: String? = {
        guard let currentRating = currentBooking.provider.rating,
              let candidateRating = provider.rating,
              candidateRating > currentRating else {
            return nil
        }
        let delta = (candidateRating - currentRating).formatted(.number.precision(.fractionLength(1)))
        return "\(delta)-star stronger local rating helps reduce repeat service risk."
    }()

    let valueReason: String? = {
        guard let candidateLow = provider.indicativePriceLow,
              let currentLow = currentBooking.provider.indicativePriceLow,
              candidateLow < currentLow else {
            return nil
        }
        return "Starts \(currencyString(currentLow - candidateLow)) lower than the current provider guide."
    }()

    let suburbReason: String? = provider.suburb.caseInsensitiveCompare(listing.address.suburb) == .orderedSame
        ? "Already covers the listing suburb, which helps keep access and timing simple."
        : nil

    let directContactCount = [provider.phoneNumber, provider.websiteURL?.absoluteString, provider.mapsURL?.absoluteString]
        .compactMap { $0 }
        .count
    let contactReason: String? = directContactCount >= 2
        ? "Has direct contact and location links ready if you need to escalate quickly."
        : nil

    let orderedReasons: [String?]
    switch weighting {
    case .fastestRecovery:
        orderedReasons = [fasterReason, contactReason, suburbReason, qualityReason, valueReason]
    case .qualityFirst:
        orderedReasons = [qualityReason, suburbReason, fasterReason, contactReason, valueReason]
    case .bestValue:
        orderedReasons = [valueReason, fasterReason, qualityReason, suburbReason, contactReason]
    case .balanced:
        orderedReasons = [fasterReason, qualityReason, valueReason, suburbReason, contactReason]
    }

    var reasons = orderedReasons.compactMap { $0 }

    if reasons.isEmpty {
        reasons.append("Keeps a comparable local provider ready without losing the current booking audit trail.")
    }

    return ConciergeReplacementSafetySummary(
        score: normalizedScore,
        title: title,
        summary: summary,
        reasons: Array(reasons.prefix(3)),
        tint: tint
    )
}

private func conciergeReplacementImpactSummary(
    for provider: PostSaleConciergeProvider,
    currentBooking: PostSaleConciergeBooking,
    listing: PropertyListing,
    scheduledFor: Date,
    notes: String,
    estimatedCost: Int?,
    safetySummary: ConciergeReplacementSafetySummary?
) -> ConciergeReplacementImpactSummary {
    let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    let isSameProvider = provider.id == currentBooking.provider.id
    let scheduleChanged = currentBooking.scheduledFor != scheduledFor
    let estimateChanged = currentBooking.estimatedCost != estimatedCost
    let hasReminderState = currentBooking.followUpCountValue > 0 ||
        currentBooking.isReminderSnoozed ||
        currentBooking.needsResponseFollowUp ||
        currentBooking.isResponseDueSoon
    let hasFinancialState = currentBooking.estimatedCost != nil ||
        currentBooking.isQuoteApproved ||
        currentBooking.invoiceAmount != nil ||
        currentBooking.hasInvoiceAttachment ||
        currentBooking.paidAmount != nil ||
        currentBooking.hasPaymentProof ||
        currentBooking.isPaid ||
        currentBooking.refundAmount != nil ||
        currentBooking.isRefunded
    let hasIssueState = currentBooking.hasOpenIssue || currentBooking.hasResolvedIssue

    var keeps: [String] = []
    var resets: [String] = []
    var archived: [String] = []
    var riskReduced: [String] = []
    let title: String
    let supporting: String
    let tint: Color

    if isSameProvider {
        title = "Keep \(provider.name)"
        supporting = "Shows what stays attached if you keep the current provider and adjust the booking details."
        tint = BrandPalette.navy

        keeps.append("The booking stays attached to the same sale archive and counterpart handover.")

        if trimmedNotes.isEmpty == false {
            keeps.append("Booking notes stay on the active provider record.")
        }

        if currentBooking.isQuoteApproved && estimateChanged == false {
            keeps.append("Quote approval stays attached because the estimate still matches.")
        }

        if currentBooking.isProviderConfirmed && scheduleChanged == false {
            keeps.append("Provider confirmation stays attached because the time is unchanged.")
        }

        if hasReminderState && scheduleChanged == false {
            keeps.append("Follow-up history and reminder state stay on the active booking.")
        }

        if hasFinancialState {
            keeps.append("Saved invoices, payment proof, and receipts stay on the active provider record.")
        }

        if currentBooking.hasProviderHistory {
            archived.append("\(currentBooking.providerHistoryCountValue) previous provider record\(currentBooking.providerHistoryCountValue == 1 ? "" : "s") stay archived in the closeout pack.")
        }

        if estimateChanged && currentBooking.isQuoteApproved {
            resets.append("Changing the estimate clears quote approval until the provider re-confirms pricing.")
        }

        if scheduleChanged {
            resets.append("Changing the service time starts a fresh provider reply window.")

            if currentBooking.isProviderConfirmed || currentBooking.providerConfirmationNote != nil {
                resets.append("Provider confirmation and confirmation notes clear when the time changes.")
            }

            if hasReminderState {
                resets.append("Follow-up counts, reply timers, and reminder snoozes reset when the time changes.")
            }
        }
    } else {
        title = "Switch impact preview"
        supporting = "Shows what carries into the new booking, what stays archived on the outgoing provider, and what restarts."
        tint = safetySummary?.tint ?? BrandPalette.teal

        keeps.append("The \(provider.serviceKind.title.lowercased()) service stays attached to the same \(listing.address.suburb) sale archive.")
        keeps.append("The new booking opens for \(shortDateString(scheduledFor)) at \(timeString(scheduledFor)).")

        if trimmedNotes.isEmpty == false {
            keeps.append("Booking notes move across to the replacement unless you change them.")
        }

        if let estimatedCost {
            keeps.append("Quote estimate \(currencyString(estimatedCost)) becomes the new starting quote summary.")
        }

        archived.append("The outgoing provider record is preserved with the replacement timestamp in archive history.")

        if hasReminderState {
            archived.append("Saved follow-ups, reply reminders, and snooze history stay attached to the outgoing provider record.")
        }

        if hasIssueState {
            archived.append("The current provider issue trail stays on file instead of moving onto the replacement.")
        }

        if hasFinancialState {
            archived.append("Quotes, invoices, payment proof, refunds, and receipts stay attached to the outgoing provider record.")
        }

        if currentBooking.hasProviderHistory {
            archived.append("Earlier provider replacements remain visible in the audit trail.")
        }

        resets.append("The replacement starts as a fresh scheduled booking for the new provider.")

        if hasFinancialState {
            resets.append("The new provider starts without quote approval, invoice, payment, or refund status on file.")
        }

        if currentBooking.isProviderConfirmed || currentBooking.providerConfirmationNote != nil {
            resets.append("Provider confirmation and confirmation notes need to be collected again.")
        }

        if hasReminderState {
            resets.append("Reply timers, follow-up counts, and reminder snoozes restart for the new provider.")
        }

        if hasIssueState {
            resets.append("The replacement opens without the old provider issue attached as active state.")
        }

        if let safetySummary {
            riskReduced = safetySummary.reasons
        }
    }

    if keeps.isEmpty {
        keeps.append("The booking remains linked to the same sale archive and closeout export.")
    }

    return ConciergeReplacementImpactSummary(
        title: title,
        supporting: supporting,
        keeps: Array(keeps.prefix(4)),
        resets: Array(resets.prefix(4)),
        archived: Array(archived.prefix(4)),
        riskReduced: Array(riskReduced.prefix(3)),
        tint: tint
    )
}

private func conciergeProviderAuditLine(_ entry: PostSaleConciergeProviderAuditEntry) -> String {
    var line = "\(entry.provider.name) replaced \(relativeDateString(entry.replacedAt))."

    if let providerConfirmedAt = entry.providerConfirmedAt {
        line += " Confirmed \(relativeDateString(providerConfirmedAt))."
    }

    if let providerConfirmationNote = entry.providerConfirmationNote {
        line += " Note: \(providerConfirmationNote)."
    }

    if let lastFollowUpAt = entry.lastFollowUpAt {
        line += " Follow-up logged \(relativeDateString(lastFollowUpAt))."
    }

    if let followUpCount = entry.followUpCount, followUpCount > 0 {
        line += " \(followUpCount) follow-up\(followUpCount == 1 ? "" : "s")."
    }

    if let lastFollowUpNote = entry.lastFollowUpNote {
        line += " Note: \(lastFollowUpNote)."
    }

    if let issueKind = entry.issueKind {
        line += entry.issueResolvedAt == nil
            ? " Issue logged: \(issueKind.title)."
            : " Resolved issue: \(issueKind.title)."
    }

    if let refundAmount = entry.refundAmount {
        line += " Refund: \(currencyString(refundAmount))."
    } else if let paidAmount = entry.paidAmount {
        line += " Paid: \(currencyString(paidAmount))."
    } else if let invoiceAmount = entry.invoiceAmount {
        line += " Invoice: \(currencyString(invoiceAmount))."
    } else if let estimatedCost = entry.estimatedCost {
        line += " Quote: \(currencyString(estimatedCost))."
    }

    return line
}

private func conciergeProviderCallURL(_ provider: PostSaleConciergeProvider) -> URL? {
    guard let rawPhoneNumber = provider.phoneNumber else {
        return nil
    }

    let trimmed = rawPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else {
        return nil
    }

    let allowed = CharacterSet(charactersIn: "+0123456789")
    let cleanedScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
    let cleaned = String(String.UnicodeScalarView(cleanedScalars))
    guard cleaned.isEmpty == false else {
        return nil
    }

    return URL(string: "tel:\(cleaned)")
}

private func conciergeProviderPriceGuide(_ provider: PostSaleConciergeProvider) -> String? {
    switch (provider.indicativePriceLow, provider.indicativePriceHigh) {
    case let (low?, high?) where low == high:
        return "Guide \(currencyString(low))"
    case let (low?, high?):
        return "Guide \(currencyString(low)) - \(currencyString(high))"
    case let (low?, nil):
        return "From \(currencyString(low))"
    case let (nil, high?):
        return "Up to \(currencyString(high))"
    default:
        return nil
    }
}

private func conciergeProviderRatingLine(_ provider: PostSaleConciergeProvider) -> String? {
    if let rating = provider.rating {
        let reviewLine = provider.reviewCount.map { " • \($0) reviews" } ?? ""
        return "\(rating.formatted(.number.precision(.fractionLength(1)))) stars\(reviewLine)"
    }

    if let reviewCount = provider.reviewCount {
        return "\(reviewCount) local reviews"
    }

    return nil
}

private func conciergeProviderResponseLine(_ provider: PostSaleConciergeProvider) -> String? {
    guard let hours = provider.estimatedResponseHours else {
        return nil
    }

    if hours < 1 {
        return "Reply in under 1 hour"
    } else if hours == 1 {
        return "Reply in about 1 hour"
    } else if hours < 24 {
        return "Reply in about \(hours) hours"
    } else {
        let days = max(1, hours / 24)
        return "Reply in about \(days) day\(days == 1 ? "" : "s")"
    }
}

private func conciergeReplacementComparisonLines(
    currentProvider: PostSaleConciergeProvider,
    suggestedProvider: PostSaleConciergeProvider
) -> [String] {
    var lines: [String] = []

    if let currentResponse = currentProvider.estimatedResponseHours,
       let suggestedResponse = suggestedProvider.estimatedResponseHours,
       suggestedResponse != currentResponse {
        let delta = abs(currentResponse - suggestedResponse)
        if suggestedResponse < currentResponse {
            lines.append("\(delta)-hour faster reply estimate than the current provider.")
        } else {
            lines.append("\(delta)-hour slower reply estimate, but may still be the better recovery fit.")
        }
    }

    if let currentRating = currentProvider.rating,
       let suggestedRating = suggestedProvider.rating,
       suggestedRating != currentRating {
        let delta = abs(suggestedRating - currentRating)
        let formatted = delta.formatted(.number.precision(.fractionLength(1)))
        if suggestedRating > currentRating {
            lines.append("\(formatted)-star stronger local rating.")
        } else {
            lines.append("\(formatted)-star lower rating, but selected for recovery speed or value.")
        }
    }

    if let currentLow = currentProvider.indicativePriceLow,
       let suggestedLow = suggestedProvider.indicativePriceLow,
       suggestedLow != currentLow {
        let delta = abs(currentLow - suggestedLow)
        if suggestedLow < currentLow {
            lines.append("\(currencyString(delta)) lower starting guide.")
        } else {
            lines.append("\(currencyString(delta)) higher starting guide for the recommended backup.")
        }
    }

    if currentProvider.suburb.caseInsensitiveCompare(suggestedProvider.suburb) != .orderedSame {
        lines.append("Covers a different local area: \(suggestedProvider.suburb).")
    }

    if lines.isEmpty {
        lines.append("Keeps a comparable local option ready if the current provider stays blocked.")
    }

    return Array(lines.prefix(3))
}

private struct PrivateSaleEconomics {
    let priceBasis: Int

    static let commissionRate = 0.022
    static let fixedMarketingCost = 4_500

    var estimatedCommissionCost: Int {
        Int((Double(priceBasis) * Self.commissionRate).rounded())
    }

    var estimatedTraditionalCost: Int {
        estimatedCommissionCost + Self.fixedMarketingCost
    }

    var estimatedSellerNet: Int {
        max(0, priceBasis - estimatedTraditionalCost)
    }
}

private func privateSaleEconomics(for priceBasis: Int) -> PrivateSaleEconomics {
    PrivateSaleEconomics(priceBasis: priceBasis)
}

private struct BuyerAffordabilityScenario: Identifiable {
    let depositRatio: Double
    let depositAmount: Int
    let loanAmount: Int
    let monthlyRepayment: Int
    let weeklyRepayment: Int

    var id: Double { depositRatio }

    var title: String {
        "\(Int((depositRatio * 100).rounded()))% deposit"
    }
}

private struct BuyerAffordabilityGuide {
    let priceBasis: Int

    static let indicativeInterestRate = 0.061
    static let loanYears = 30

    var scenarios: [BuyerAffordabilityScenario] {
        [0.10, 0.20].map { ratio in
            let depositAmount = Int((Double(priceBasis) * ratio).rounded())
            let loanAmount = max(0, priceBasis - depositAmount)
            let monthlyRepayment = amortizedMonthlyRepayment(
                principal: loanAmount,
                annualInterestRate: Self.indicativeInterestRate,
                years: Self.loanYears
            )
            let weeklyRepayment = Int((Double(monthlyRepayment) * 12.0 / 52.0).rounded())

            return BuyerAffordabilityScenario(
                depositRatio: ratio,
                depositAmount: depositAmount,
                loanAmount: loanAmount,
                monthlyRepayment: monthlyRepayment,
                weeklyRepayment: weeklyRepayment
            )
        }
    }
}

private func amortizedMonthlyRepayment(
    principal: Int,
    annualInterestRate: Double,
    years: Int
) -> Int {
    guard principal > 0, years > 0 else { return 0 }

    let monthlyRate = annualInterestRate / 12.0
    let paymentCount = Double(years * 12)

    guard monthlyRate > 0 else {
        return Int((Double(principal) / paymentCount).rounded())
    }

    let compounded = pow(1.0 + monthlyRate, paymentCount)
    let repayment = Double(principal) * monthlyRate * compounded / (compounded - 1.0)
    return Int(repayment.rounded())
}

private func listingOpeningPrice(_ listing: PropertyListing) -> Int {
    listing.sortedPriceJourney.last?.amount ?? listing.askingPrice
}

private func listingPriceMovement(_ listing: PropertyListing) -> Int {
    listing.askingPrice - listingOpeningPrice(listing)
}

private func signedCurrencyString(_ value: Int) -> String {
    let absolute = currencyString(abs(value))
    if value > 0 {
        return "+\(absolute)"
    }
    if value < 0 {
        return "-\(absolute)"
    }
    return absolute
}

private func priceMovementTint(for listing: PropertyListing) -> Color {
    let delta = listingPriceMovement(listing)
    if delta < 0 {
        return BrandPalette.teal
    }
    if delta > 0 {
        return BrandPalette.coral
    }
    return .secondary
}

private func priceJourneyHeadline(for listing: PropertyListing) -> String {
    let delta = listingPriceMovement(listing)
    let startingPrice = listingOpeningPrice(listing)

    if delta < 0 {
        return "Reduced \(currencyString(abs(delta))) from \(currencyString(startingPrice)) launch price"
    }

    if delta > 0 {
        return "Updated \(currencyString(delta)) above the original \(currencyString(startingPrice)) guide"
    }

    return "No price changes since the private listing launched"
}

private func priceJourneyPillLabel(for listing: PropertyListing) -> String {
    let delta = listingPriceMovement(listing)
    if delta < 0 {
        return "Reduced \(currencyString(abs(delta)))"
    }
    if delta > 0 {
        return "Updated \(currencyString(delta))"
    }
    return "Original guide"
}

private func priceJourneySupportLine(for listing: PropertyListing) -> String {
    let journeyCount = listing.sortedPriceJourney.count
    let pointLabel = journeyCount == 1 ? "price point" : "price points"
    return "\(priceJourneyHeadline(for: listing)) • \(journeyCount) \(pointLabel) recorded"
}

private func pricePositionSummary(for listing: PropertyListing) -> String {
    if listing.askingPrice < listing.marketPulse.valueEstimateLow {
        return "Asking price sits below the modeled value range"
    }

    if listing.askingPrice > listing.marketPulse.valueEstimateHigh {
        return "Asking price sits above the modeled value range"
    }

    return "Asking price sits inside the modeled value range"
}

private func contractIssueMissingSteps(
    buyer: UserProfile?,
    seller: UserProfile?
) -> [String] {
    var steps: [String] = []

    if buyer?.hasVerifiedCheck(.finance) != true {
        steps.append("Buyer finance readiness still pending")
    }

    if seller?.hasVerifiedCheck(.ownership) != true {
        steps.append("Seller ownership review still pending")
    }

    return steps
}

private func trustHeadline(for user: UserProfile) -> String {
    if user.hasVerifiedCheck(.finance) {
        return "Finance ready"
    }

    if user.hasVerifiedCheck(.ownership) {
        return "Ownership checked"
    }

    if user.hasVerifiedCheck(.identity) && user.hasVerifiedCheck(.mobile) {
        return "ID checked"
    }

    if user.pendingCheckCount == 0 && !user.verificationChecks.isEmpty {
        return "Fully verified"
    }

    return user.verifiedCheckCount == 0 ? "Checks pending" : "Partially verified"
}

private func trustSummaryLine(for user: UserProfile) -> String {
    let verified = user.verifiedCheckCount
    let total = user.verificationChecks.count

    guard total > 0 else {
        return "Trust checks not started"
    }

    if user.pendingCheckCount == 0 {
        return "\(verified) of \(total) checks verified"
    }

    return "\(verified) of \(total) checks verified • \(user.pendingCheckCount) pending"
}

private func sellerOfferPriority(
    for offer: OfferRecord,
    listing: PropertyListing,
    buyer: UserProfile
) -> SellerOfferPriority {
    var score: Int
    let label: String
    let detail: String
    let tint: Color
    let background: Color

    if offer.contractPacket?.isFullySigned == true {
        score = 100
        label = "Completed sale"
        detail = "Both parties have signed the contract packet. Keep the secure thread open for final settlement notes."
        tint = BrandPalette.teal
        background = BrandPalette.teal.opacity(0.14)
    } else if offer.status == .accepted {
        score = 92
        label = offer.contractPacket == nil ? "Legal handoff" : "Finish signatures"
        detail = offer.contractPacket == nil
            ? "The offer is accepted. Finish legal coordination so the contract packet can move through the deal room."
            : "The offer is accepted and the contract packet is active. Focus on signatures and final milestones."
        tint = BrandPalette.navy
        background = BrandPalette.navy.opacity(0.12)
    } else if offer.status == .underOffer {
        score = 86
        label = buyer.hasVerifiedCheck(.finance) ? "Priority buyer" : "Seller action needed"
        detail = buyer.hasVerifiedCheck(.finance)
            ? "This buyer is finance ready and waiting on your response. Reviewing this deal quickly could accelerate contract issue."
            : "A live offer is waiting on you. Review the amount, conditions, and trust signals before replying."
        tint = buyer.hasVerifiedCheck(.finance) ? BrandPalette.teal : BrandPalette.coral
        background = buyer.hasVerifiedCheck(.finance)
            ? BrandPalette.teal.opacity(0.14)
            : BrandPalette.coral.opacity(0.14)
    } else if offer.status == .countered {
        score = 72
        label = "Counter sent"
        detail = "Your counteroffer is already with the buyer. Use the secure thread to keep momentum if the buyer needs clarity."
        tint = BrandPalette.navy
        background = BrandPalette.navy.opacity(0.12)
    } else {
        score = 68
        label = "Waiting on revision"
        detail = "You requested changes and the buyer needs to revise terms. This stays visible so you can follow up from the thread."
        tint = BrandPalette.gold
        background = BrandPalette.gold.opacity(0.22)
    }

    if buyer.hasVerifiedCheck(.finance) {
        score += 8
    }
    switch offer.sellerRelationshipStatus {
    case .preferred:
        score += 12
    case .shortlisted:
        score += 6
    case .watching:
        break
    }
    if offer.isLegallyCoordinated {
        score += 7
    }
    if offer.contractPacket != nil {
        score += 5
    }
    if offer.amount >= listing.askingPrice {
        score += 6
    } else if offer.amount >= Int((Double(listing.askingPrice) * 0.97).rounded()) {
        score += 3
    }
    if offer.createdAt > Date.now.addingTimeInterval(-(60 * 60 * 24 * 2)) {
        score += 4
    }

    return SellerOfferPriority(
        score: min(score, 100),
        label: label,
        detail: detail,
        tint: tint,
        background: background
    )
}

private func buyerOfferPriority(
    for offer: OfferRecord,
    listing: PropertyListing,
    seller: UserProfile
) -> BuyerOfferPriority {
    var score: Int
    let label: String
    let detail: String
    let tint: Color
    let background: Color

    if offer.settlementCompletedAt != nil {
        score = 100
        label = "Settled"
        detail = "Settlement has been confirmed, and the shared deal room now acts as your completed sale record."
        tint = BrandPalette.teal
        background = BrandPalette.teal.opacity(0.14)
    } else if offer.contractPacket?.isFullySigned == true {
        score = 96
        label = "Final settlement"
        detail = "Both sides have signed. Focus on settlement statement review and final handover."
        tint = BrandPalette.navy
        background = BrandPalette.navy.opacity(0.12)
    } else if offer.status == .accepted {
        score = 90
        label = offer.contractPacket == nil ? "Legal handoff" : "Sign and settle"
        detail = offer.contractPacket == nil
            ? "The seller accepted your offer. Finish finance proof and legal coordination so the contract packet can issue."
            : "The offer is accepted and the contract packet is live. Finish signatures and settlement steps from this hub."
        tint = BrandPalette.teal
        background = BrandPalette.teal.opacity(0.14)
    } else if offer.status == .countered {
        score = 84
        label = "Counter to review"
        detail = "The seller has countered. Review the new amount and conditions, then respond from the buyer hub."
        tint = BrandPalette.coral
        background = BrandPalette.coral.opacity(0.14)
    } else if offer.status == .changesRequested {
        score = 78
        label = "Seller wants changes"
        detail = "The seller wants updated terms before accepting. Revise the offer without leaving your shortlist."
        tint = BrandPalette.gold
        background = BrandPalette.gold.opacity(0.22)
    } else {
        score = 70
        label = "Offer live"
        detail = "Your offer is with the seller. Keep the deal room active and use secure messages if the seller needs more context."
        tint = BrandPalette.navy
        background = BrandPalette.navy.opacity(0.12)
    }

    if seller.hasVerifiedCheck(.ownership) {
        score += 6
    }
    if offer.isLegallyCoordinated {
        score += 5
    }
    if offer.contractPacket != nil {
        score += 5
    }
    if offer.amount >= listing.askingPrice {
        score += 3
    }
    if offer.createdAt > Date.now.addingTimeInterval(-(60 * 60 * 24 * 2)) {
        score += 4
    }

    return BuyerOfferPriority(
        score: min(score, 100),
        label: label,
        detail: detail,
        tint: tint,
        background: background
    )
}

private func activeExecutionOffer(
    for listingID: UUID,
    offers: [OfferRecord]
) -> OfferRecord? {
    offers
        .filter {
            $0.listingID == listingID &&
            ($0.status == .accepted || $0.contractPacket?.isFullySigned == true)
        }
        .sorted { left, right in
            if left.contractPacket?.isFullySigned == right.contractPacket?.isFullySigned {
                return left.createdAt > right.createdAt
            }
            return left.contractPacket?.isFullySigned == true
        }
        .first
}

private func canSellerAccept(
    offer: OfferRecord,
    among offers: [OfferRecord]
) -> Bool {
    guard offer.contractPacket?.isFullySigned != true else {
        return false
    }

    guard let activeOffer = activeExecutionOffer(for: offer.listingID, offers: offers) else {
        return true
    }

    return activeOffer.id == offer.id
}

private func priceDeltaTint(for offer: OfferRecord, askingPrice: Int) -> Color {
    if offer.amount > askingPrice {
        return BrandPalette.teal
    }
    if offer.amount < askingPrice {
        return BrandPalette.coral
    }
    return .secondary
}

private func sellerRelationshipSortRank(_ status: SellerBuyerRelationshipStatus) -> Int {
    switch status {
    case .preferred:
        return 3
    case .shortlisted:
        return 2
    case .watching:
        return 1
    }
}

private func sellerRelationshipTint(for status: SellerBuyerRelationshipStatus) -> Color {
    switch status {
    case .preferred:
        return BrandPalette.teal
    case .shortlisted:
        return BrandPalette.gold
    case .watching:
        return BrandPalette.navy
    }
}

private func sellerRelationshipBackground(for status: SellerBuyerRelationshipStatus) -> Color {
    switch status {
    case .preferred:
        return BrandPalette.teal.opacity(0.14)
    case .shortlisted:
        return BrandPalette.gold.opacity(0.22)
    case .watching:
        return BrandPalette.navy.opacity(0.12)
    }
}

private func verificationActionTitle(
    for kind: VerificationCheckKind,
    role: UserRole
) -> String {
    switch kind {
    case .identity:
        return role == .seller ? "Complete seller identity" : "Complete buyer identity"
    case .mobile:
        return "Confirm mobile"
    case .finance:
        return "Upload finance proof"
    case .ownership:
        return "Upload ownership proof"
    case .legal:
        return "Complete from workflow"
    }
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
