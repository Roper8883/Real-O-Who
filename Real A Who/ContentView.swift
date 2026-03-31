import SwiftUI

private enum AppTab: Hashable {
    case today
    case journal
    case insights
    case about
}

struct ContentView: View {
    @EnvironmentObject private var store: JournalStore

    @State private var selectedTab: AppTab = .today
    @State private var showingComposer = false
    @State private var editingEntry: JournalEntry?
    @State private var suggestedPrompt = PromptLibrary.prompt()

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                onNewReflection: openTodayPrompt,
                onQuickNote: openQuickNote,
                onEdit: edit
            )
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }
            .tag(AppTab.today)

            JournalView(
                onCreate: openQuickNote,
                onEdit: edit
            )
            .tabItem {
                Label("Journal", systemImage: "book.closed.fill")
            }
            .tag(AppTab.journal)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.insights)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
                .tag(AppTab.about)
        }
        .tint(.indigo)
        .sheet(isPresented: $showingComposer, onDismiss: clearComposerState) {
            ReflectionEditorView(
                existingEntry: editingEntry,
                suggestedPrompt: suggestedPrompt
            )
            .environmentObject(store)
        }
    }

    private func openTodayPrompt() {
        editingEntry = nil
        suggestedPrompt = PromptLibrary.prompt()
        showingComposer = true
    }

    private func openQuickNote() {
        editingEntry = nil
        suggestedPrompt = PromptLibrary.quickPrompt
        showingComposer = true
    }

    private func edit(_ entry: JournalEntry) {
        editingEntry = entry
        suggestedPrompt = ReflectionPrompt(
            id: -1,
            title: entry.prompt,
            followUp: "Tighten the story, add detail, or leave yourself a clearer note."
        )
        showingComposer = true
    }

    private func clearComposerState() {
        editingEntry = nil
        suggestedPrompt = PromptLibrary.prompt()
    }
}

private struct TodayView: View {
    @EnvironmentObject private var store: JournalStore

    let onNewReflection: () -> Void
    let onQuickNote: () -> Void
    let onEdit: (JournalEntry) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    LazyVGrid(columns: columns, spacing: 12) {
                        StatCard(
                            title: "Current streak",
                            value: "\(store.currentStreak)",
                            caption: store.currentStreak == 1 ? "day of reflection" : "days of reflection",
                            systemImage: "flame.fill",
                            tint: .orange
                        )
                        StatCard(
                            title: "Entries this week",
                            value: "\(store.entriesThisWeek)",
                            caption: "last 7 days",
                            systemImage: "calendar",
                            tint: .indigo
                        )
                        StatCard(
                            title: "Saved notes",
                            value: "\(store.entries.count)",
                            caption: "total reflections",
                            systemImage: "square.and.pencil",
                            tint: .teal
                        )
                        StatCard(
                            title: "Favorites",
                            value: "\(store.favoritesCount)",
                            caption: "worth revisiting",
                            systemImage: "heart.fill",
                            tint: .pink
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent reflections")
                            .font(.title3.weight(.semibold))

                        if store.sortedEntries.isEmpty {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(.white.opacity(0.78))
                                .overlay(alignment: .leading) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Nothing saved yet")
                                            .font(.headline)
                                        Text("Start with today's prompt or capture a quick note. Everything stays on this device.")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(20)
                                }
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.sortedEntries.prefix(3)) { entry in
                                    NavigationLink(value: entry.id) {
                                        EntryCard(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(todayBackground.ignoresSafeArea())
            .navigationTitle("Real A Who")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onQuickNote) {
                        Label("Quick Note", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { entryID in
                EntryDetailView(entryID: entryID, onEdit: onEdit)
            }
        }
    }

    private var heroCard: some View {
        let prompt = PromptLibrary.prompt()

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reflect on who you really are.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text("A calm, private space for honest notes, quick check-ins, and a clearer sense of what matters.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's prompt")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(prompt.title)
                    .font(.title2.weight(.semibold))

                Text(prompt.followUp)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onNewReflection) {
                    Label("Answer prompt", systemImage: "sparkles.rectangle.stack.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButtonStyle(tint: .indigo))

                Button(action: onQuickNote) {
                    Label("Quick note", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButtonStyle(tint: .white, foreground: .indigo))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.65), lineWidth: 1)
        )
    }

    private var todayBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.95, blue: 0.90),
                Color(red: 0.94, green: 0.95, blue: 1.0),
                Color(red: 0.89, green: 0.96, blue: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct JournalView: View {
    @EnvironmentObject private var store: JournalStore

    let onCreate: () -> Void
    let onEdit: (JournalEntry) -> Void

    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var filteredEntries: [JournalEntry] {
        store.sortedEntries.filter { entry in
            let matchesSearch: Bool

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let searchableText = [
                    entry.displayTitle,
                    entry.prompt,
                    entry.body,
                    entry.tags.joined(separator: " ")
                ]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)

                matchesSearch = searchableText
            }

            let matchesFavorites = !favoritesOnly || entry.isFavorite
            return matchesSearch && matchesFavorites
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        favoritesOnly || !searchText.isEmpty ? "No matching reflections" : "No reflections yet",
                        systemImage: favoritesOnly || !searchText.isEmpty ? "magnifyingglass" : "book.closed",
                        description: Text(emptyDescription)
                    )
                } else {
                    List {
                        Section {
                            ForEach(filteredEntries) { entry in
                                NavigationLink(value: entry.id) {
                                    EntryRow(entry: entry)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        store.toggleFavorite(entry)
                                    } label: {
                                        Label(
                                            entry.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: entry.isFavorite ? "heart.slash.fill" : "heart.fill"
                                        )
                                    }
                                    .tint(.pink)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        store.delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }

                                    Button {
                                        onEdit(entry)
                                    } label: {
                                        Label("Edit", systemImage: "slider.horizontal.3")
                                    }
                                    .tint(.indigo)
                                }
                            }
                        } footer: {
                            Text("Saved reflections are private and stored on this device.")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $favoritesOnly) {
                        Label("Favorites only", systemImage: favoritesOnly ? "heart.fill" : "heart")
                    }
                    .toggleStyle(.button)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onCreate) {
                        Label("New Reflection", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes, prompts, or tags")
            .navigationDestination(for: UUID.self) { entryID in
                EntryDetailView(entryID: entryID, onEdit: onEdit)
            }
        }
    }

    private var emptyDescription: String {
        if favoritesOnly || !searchText.isEmpty {
            return "Try a broader search or turn off the favorites filter."
        }

        return "Use the add button to save your first quick note."
    }
}

private struct InsightsView: View {
    @EnvironmentObject private var store: JournalStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.entries.isEmpty {
                        ContentUnavailableView(
                            "No insights yet",
                            systemImage: "chart.bar",
                            description: Text("Add a few reflections and this screen will show patterns in your mood, rhythm, and favorite themes.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Snapshot")
                                .font(.title3.weight(.semibold))

                            StatCard(
                                title: "Most common mood",
                                value: store.mostCommonMood?.title ?? "N/A",
                                caption: store.mostCommonMood?.insightLine ?? "Keep writing to surface trends.",
                                systemImage: store.mostCommonMood?.symbol ?? "face.smiling",
                                tint: store.mostCommonMood?.tint ?? .indigo
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mood balance")
                                .font(.title3.weight(.semibold))

                            ForEach(store.moodBreakdown) { item in
                                MoodBreakdownRow(item: item, totalEntries: max(store.entries.count, 1))
                            }
                        }
                        .padding(20)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top tags")
                                .font(.title3.weight(.semibold))

                            if store.tagCounts.isEmpty {
                                Text("Add comma-separated tags to reflections and they will appear here.")
                                    .foregroundStyle(.secondary)
                            } else {
                                FlowLayout(spacing: 10) {
                                    ForEach(store.tagCounts.prefix(8), id: \.tag) { tag in
                                        Text("\(tag.tag) (\(tag.count))")
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(tagCapsuleColor, in: Capsule())
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Writing volume")
                                .font(.title3.weight(.semibold))

                            HStack(spacing: 12) {
                                InsightMetric(
                                    title: "Words saved",
                                    value: "\(store.totalWordCount)"
                                )
                                InsightMetric(
                                    title: "Average per entry",
                                    value: "\(store.averageWordCount)"
                                )
                            }
                        }
                        .padding(20)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.97, green: 0.94, blue: 0.91)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Insights")
        }
    }

    private var tagCapsuleColor: Color {
        Color.indigo.opacity(0.12)
    }
}

private struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("What It Does") {
                    Label("Daily reflection prompt", systemImage: "sun.max")
                    Label("Quick offline note capture", systemImage: "square.and.pencil")
                    Label("Journal history with search and favorites", systemImage: "magnifyingglass")
                    Label("On-device mood and tag insights", systemImage: "chart.bar")
                }

                Section("Privacy") {
                    Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
                    Label("No analytics or tracking SDKs", systemImage: "hand.raised.fill")
                    Label("Entries stay on this device", systemImage: "lock.fill")
                }

                Section("Legal") {
                    Link(destination: LegalDocumentURL.privacyPolicy) {
                        Label("Privacy Policy", systemImage: "lock.doc")
                    }

                    Link(destination: LegalDocumentURL.termsOfUse) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }

                    Link(destination: LegalDocumentURL.support) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                }

                Section("Tips") {
                    Text("Use tags like `work`, `family`, or `health` to make patterns easier to spot.")
                    Text("Mark important entries as favorites so they stay easy to revisit.")
                    Text("A short, honest sentence is enough. The goal is clarity, not perfection.")
                }

                Section("App Info") {
                    LabeledContent("Version", value: Bundle.main.releaseVersionNumber ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.buildNumber ?? "1")
                }
            }
            .navigationTitle("About")
            .listStyle(.insetGrouped)
        }
    }
}

private struct EntryDetailView: View {
    @EnvironmentObject private var store: JournalStore

    let entryID: UUID
    let onEdit: (JournalEntry) -> Void

    var body: some View {
        Group {
            if let entry = store.entry(id: entryID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        detailHeader(for: entry)

                        detailSection(title: "Prompt") {
                            Text(entry.prompt)
                                .font(.body)
                        }

                        detailSection(title: "Reflection") {
                            Text(entry.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !entry.tags.isEmpty {
                            detailSection(title: "Tags") {
                                FlowLayout(spacing: 10) {
                                    ForEach(entry.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.indigo.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(entry.displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ShareLink(item: entry.shareText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            onEdit(entry)
                        } label: {
                            Label("Edit", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Reflection not found",
                    systemImage: "exclamationmark.bubble",
                    description: Text("This entry may have been deleted.")
                )
            }
        }
    }

    private func detailHeader(for entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MoodBadge(mood: entry.mood)

                if entry.isFavorite {
                    Label("Favorite", systemImage: "heart.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.pink)
                }
            }

            Text(entry.displayTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content()
                .foregroundStyle(.primary)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct EntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MoodBadge(mood: entry.mood)
                Spacer()
                Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(entry.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !entry.tags.isEmpty {
                Text(entry.tags.prefix(3).joined(separator: "  ·  "))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .center, spacing: 6) {
                Image(systemName: entry.mood.symbol)
                    .font(.headline)
                    .foregroundStyle(entry.mood.tint)
                    .frame(width: 34, height: 34)
                    .background(entry.mood.tint.opacity(0.16), in: Circle())

                if entry.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.displayTitle)
                        .font(.headline)
                    Spacer()
                    Text(entry.entryDate.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !entry.tags.isEmpty {
                    Text(entry.tags.joined(separator: "  ·  "))
                        .font(.caption)
                        .foregroundStyle(.indigo)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MoodBadge: View {
    let mood: ReflectionMood

    var body: some View {
        Label(mood.title, systemImage: mood.symbol)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(mood.tint.opacity(0.14), in: Capsule())
            .foregroundStyle(mood.tint)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: Circle())

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(title)
                .font(.headline)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct InsightMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MoodBreakdownRow: View {
    let item: MoodBreakdownItem
    let totalEntries: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(item.mood.title, systemImage: item.mood.symbol)
                    .foregroundStyle(item.mood.tint)
                Spacer()
                Text("\(item.count)")
                    .font(.subheadline.weight(.semibold))
            }

            GeometryReader { geometry in
                let percentage = CGFloat(item.count) / CGFloat(totalEntries)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.black.opacity(0.06))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(item.mood.tint.gradient)
                            .frame(width: max(24, geometry.size.width * percentage))
                    }
            }
            .frame(height: 10)
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if lineWidth + size.width > maxWidth {
                width = max(width, lineWidth)
                height += lineHeight + spacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }

        width = max(width, lineWidth)
        height += lineHeight

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if point.x + size.width > bounds.minX + maxWidth {
                point.x = bounds.minX
                point.y += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: point,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            point.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct FilledButtonStyle: ButtonStyle {
    let tint: Color
    let foreground: Color

    init(tint: Color, foreground: Color = .white) {
        self.tint = tint
        self.foreground = foreground
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(tint.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension Bundle {
    var releaseVersionNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }
}

private enum LegalDocumentURL {
    static let privacyPolicy = URL(string: "https://roper8883.github.io/Real-A-Who/privacy-policy/")!
    static let termsOfUse = URL(string: "https://roper8883.github.io/Real-A-Who/terms-of-use/")!
    static let support = URL(string: "https://roper8883.github.io/Real-A-Who/support/")!
}

#Preview {
    ContentView()
        .environmentObject(JournalStore.preview)
}
