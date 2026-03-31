import SwiftUI

struct ReflectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: JournalStore

    let existingEntry: JournalEntry?
    let suggestedPrompt: ReflectionPrompt

    @State private var draft: JournalDraft

    init(existingEntry: JournalEntry? = nil, suggestedPrompt: ReflectionPrompt) {
        self.existingEntry = existingEntry
        self.suggestedPrompt = suggestedPrompt

        if let existingEntry {
            _draft = State(initialValue: JournalDraft(entry: existingEntry))
        } else {
            _draft = State(initialValue: JournalDraft(prompt: suggestedPrompt.title))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextField("Prompt", text: $draft.prompt, axis: .vertical)
                        .lineLimit(2...4)

                    if !suggestedPrompt.followUp.isEmpty {
                        Text(suggestedPrompt.followUp)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reflection") {
                    TextField("Title (optional)", text: $draft.title)

                    TextEditor(text: $draft.body)
                        .frame(minHeight: 180)
                        .overlay(alignment: .topLeading) {
                            if draft.body.isEmpty {
                                Text("Write what happened, what you noticed, or what you want to remember.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Details") {
                    DatePicker("Date", selection: $draft.entryDate, displayedComponents: .date)
                    Toggle("Mark as favorite", isOn: $draft.isFavorite)
                    TextField("Tags separated by commas", text: $draft.tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section("Mood") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(ReflectionMood.allCases) { mood in
                            Button {
                                draft.mood = mood
                            } label: {
                                Label(mood.title, systemImage: mood.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(draft.mood == mood ? .white : mood.tint)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(draft.mood == mood ? mood.tint : mood.tint.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existingEntry == nil ? "New Reflection" : "Edit Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.save(draft: draft, editing: existingEntry)
                        dismiss()
                    }
                    .disabled(!draft.isSaveable)
                }
            }
        }
    }
}
