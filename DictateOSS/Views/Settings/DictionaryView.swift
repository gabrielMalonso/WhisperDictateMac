import SwiftData
import SwiftUI

struct DictionaryView: View {
    @Query(sort: \DictionaryEntry.term)
    private var allEntries: [DictionaryEntry]

    @Environment(\.modelContext) private var modelContext

    @AppStorage(MacAppKeys.transcriptionLanguage, store: .app)
    private var activeLanguage: String = "pt"

    @AppStorage(MacAppKeys.dictionaryEnabled, store: .app)
    private var dictionaryEnabled: Bool = true

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var selectedLanguage: String = ""
    @State private var searchText: String = ""
    @State private var sheetMode: DictionarySheetMode?
    @State private var showLimitAlert = false
    @State private var selection: Set<UUID> = []
    @State private var showDeleteAlert = false
    @State private var pendingDeleteEntries: [DictionaryEntry] = []

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let maxTermsPerLanguage = 100

    // MARK: - Computed properties

    private var availableLanguages: [String] {
        let langs = Set(allEntries.map { $0.language })
        return Array(langs).sorted()
    }

    private var effectiveLanguage: String {
        if !selectedLanguage.isEmpty && availableLanguages.contains(selectedLanguage) {
            return selectedLanguage
        }
        return availableLanguages.first ?? activeLanguage
    }

    private var entriesForLanguage: [DictionaryEntry] {
        allEntries.filter { $0.language == effectiveLanguage }
    }

    private var filteredEntries: [DictionaryEntry] {
        guard !searchText.isEmpty else { return entriesForLanguage }
        return entriesForLanguage.filter {
            $0.term.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var currentLanguageCount: Int {
        entriesForLanguage.count
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selection) {
            Section {
                Toggle(String(localized: "Ativar dicionário"), isOn: $dictionaryEnabled)
                    .toggleStyle(.switch)
            }

            if availableLanguages.count > 1 {
                Section {
                    Picker(String(localized: "Idioma"), selection: $selectedLanguage) {
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(DictionaryView.displayName(for: lang)).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }

            if entriesForLanguage.isEmpty {
                ContentUnavailableView(
                    String(localized: "Nenhum termo adicionado"),
                    systemImage: "text.book.closed",
                    description: Text(
                        String(localized: "Termos do dicionário ajudam a melhorar a precisão da transcrição.")
                    )
                )
                .listRowBackground(Color.clear)
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.term)
                                    .font(AppTypography.row)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(
                                        entry.createdAt.formatted(
                                            .dateTime
                                                .locale(AppUILanguage.current.locale)
                                                .day()
                                                .month(.abbreviated)
                                                .year()
                                        )
                                    )
                                        .font(AppTypography.helper)
                                        .foregroundStyle(.secondary)

                                    if availableLanguages.count > 1 {
                                        Text(languageShortName(for: entry.language))
                                            .font(AppTypography.helper.weight(.bold))
                                            .foregroundStyle(accentColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(accentColor.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                }

                                if entry.useCount > 0 {
                                    Text(String(localized: "Usado \(entry.useCount)×"))
                                        .font(AppTypography.helper)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(String(localized: "Editar")) { sheetMode = .edit(entry) }
                            Divider()
                            Button(String(localized: "Apagar"), role: .destructive) {
                                pendingDeleteEntries = [entry]
                                showDeleteAlert = true
                            }
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "Buscar termo"))
        .onDeleteCommand {
            let selected = entriesForLanguage.filter { selection.contains($0.id) }
            guard !selected.isEmpty else { return }
            pendingDeleteEntries = selected
            showDeleteAlert = true
        }
        .onKeyPress(.return) {
            guard selection.count == 1,
                  let entry = entriesForLanguage.first(where: { $0.id == selection.first }) else {
                return .ignored
            }
            sheetMode = .edit(entry)
            return .handled
        }
        .listStyle(.inset)
        .safeAreaPadding(.horizontal, 12)
        .navigationTitle(String(localized: "Dicionário Pessoal"))
        .onAppear {
            if selectedLanguage.isEmpty {
                selectedLanguage = availableLanguages.contains(activeLanguage)
                    ? activeLanguage
                    : (availableLanguages.first ?? activeLanguage)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if currentLanguageCount >= maxTermsPerLanguage {
                        showLimitAlert = true
                    } else {
                        sheetMode = .create
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            if selection.count == 1,
               let entry = entriesForLanguage.first(where: { $0.id == selection.first }) {
                ToolbarItem(placement: .automatic) {
                    Button {
                        sheetMode = .edit(entry)
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }

            if !selection.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        pendingDeleteEntries = entriesForLanguage.filter { selection.contains($0.id) }
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .sheet(item: $sheetMode) { mode in
            TermFormSheet(
                mode: mode,
                modelContext: modelContext,
                defaultLanguage: effectiveLanguage,
                availableLanguages: availableLanguages,
                allEntries: allEntries,
                maxTermsPerLanguage: maxTermsPerLanguage,
                onDelete: { entry in
                    deleteEntry(entry)
                    selection.remove(entry.id)
                }
            )
        }
        .alert(
            String(localized: "Limite atingido"),
            isPresented: $showLimitAlert
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Você atingiu o limite de \(maxTermsPerLanguage) termos para este idioma."))
            + Text(" ")
            + Text(String(localized: "Remova termos existentes para adicionar novos."))
        }
        .alert(
            pendingDeleteEntries.count == 1
                ? String(localized: "Excluir Termo")
                : String(localized: "Excluir \(pendingDeleteEntries.count) Termos"),
            isPresented: $showDeleteAlert
        ) {
            Button(String(localized: "Cancelar"), role: .cancel) { pendingDeleteEntries = [] }
            Button(String(localized: "Excluir"), role: .destructive) { performPendingDelete() }
        } message: {
            Text(
                pendingDeleteEntries.count == 1
                    ? String(localized: "Tem certeza que deseja excluir este termo?")
                    : String(localized: "Tem certeza que deseja excluir os \(pendingDeleteEntries.count) termos selecionados?")
            )
        }
    }

    // MARK: - Helpers

    private func languageShortName(for code: String) -> String {
        switch code {
        case "pt": return "PT"
        case "en": return "EN"
        case "es": return "ES"
        case "fr": return "FR"
        default: return code.uppercased()
        }
    }

    // MARK: - Actions

    private func deleteEntry(_ entry: DictionaryEntry) {
        entry.updatedAt = .now
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            deleteEntry(filteredEntries[index])
        }
    }

    private func performPendingDelete() {
        for entry in pendingDeleteEntries {
            deleteEntry(entry)
        }
        selection.subtract(pendingDeleteEntries.map { $0.id })
        pendingDeleteEntries = []
    }

    // MARK: - Language display names

    static func displayName(for code: String) -> String {
        switch code {
        case "pt": return String(localized: "Português")
        case "en": return String(localized: "English")
        case "es": return String(localized: "Español")
        case "fr": return String(localized: "Français")
        default: return code.uppercased()
        }
    }
}

// MARK: - Sheet Mode

private enum DictionarySheetMode: Identifiable {
    case create
    case edit(DictionaryEntry)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let entry): entry.id.uuidString
        }
    }

    var entry: DictionaryEntry? {
        if case .edit(let entry) = self { return entry }
        return nil
    }

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

// MARK: - Term Form Sheet

private struct TermFormSheet: View {
    let mode: DictionarySheetMode
    let modelContext: ModelContext
    let defaultLanguage: String
    let availableLanguages: [String]
    let allEntries: [DictionaryEntry]
    let maxTermsPerLanguage: Int
    var onDelete: ((DictionaryEntry) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var term: String
    @State private var selectedLanguage: String
    @State private var showLimitAlert = false

    private let allLanguages = ["pt", "en", "es", "fr"]

    private var languageOptions: [String] {
        let combined = Set(availableLanguages + allLanguages)
        return Array(combined).sorted()
    }

    private var countForSelectedLanguage: Int {
        allEntries.filter { $0.language == effectiveLanguage }.count
    }

    private var effectiveLanguage: String {
        selectedLanguage.isEmpty ? defaultLanguage : selectedLanguage
    }

    init(
        mode: DictionarySheetMode,
        modelContext: ModelContext,
        defaultLanguage: String,
        availableLanguages: [String],
        allEntries: [DictionaryEntry],
        maxTermsPerLanguage: Int,
        onDelete: ((DictionaryEntry) -> Void)? = nil
    ) {
        self.mode = mode
        self.modelContext = modelContext
        self.defaultLanguage = defaultLanguage
        self.availableLanguages = availableLanguages
        self.allEntries = allEntries
        self.maxTermsPerLanguage = maxTermsPerLanguage
        self.onDelete = onDelete
        _term = State(initialValue: mode.entry?.term ?? "")
        _selectedLanguage = State(initialValue: mode.entry?.language ?? defaultLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(String(localized: "Cancelar")) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(mode.isEditing ? String(localized: "Editar Termo") : String(localized: "Novo Termo"))
                    .font(.headline)

                Spacer()

                Button(mode.isEditing ? String(localized: "Salvar") : String(localized: "Adicionar")) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Form content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Termo"))
                        .font(AppTypography.row)
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "Ex: OpenAI, Kubernetes, etc."), text: $term)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Idioma"))
                        .font(AppTypography.row)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedLanguage) {
                        ForEach(languageOptions, id: \.self) { lang in
                            Text(DictionaryView.displayName(for: lang)).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                if mode.isEditing {
                    Divider()
                        .padding(.top, 4)

                    Button(role: .destructive) {
                        deleteCurrentEntry()
                    } label: {
                        Text(String(localized: "Excluir Termo"))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 420)
        .alert(
            String(localized: "Limite atingido"),
            isPresented: $showLimitAlert
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Você atingiu o limite de \(maxTermsPerLanguage) termos para este idioma."))
            + Text(" ")
            + Text(String(localized: "Remova termos existentes para adicionar novos."))
        }
    }

    private func save() {
        let trimmedTerm = term.trimmingCharacters(in: .whitespaces)
        guard !trimmedTerm.isEmpty else { return }

        if let existingEntry = mode.entry {
            let languageChanged = effectiveLanguage != existingEntry.language
            if languageChanged && countForSelectedLanguage >= maxTermsPerLanguage {
                showLimitAlert = true
                return
            }
            existingEntry.term = trimmedTerm
            existingEntry.language = effectiveLanguage
            existingEntry.updatedAt = .now
        } else {
            if countForSelectedLanguage >= maxTermsPerLanguage {
                showLimitAlert = true
                return
            }
            let entry = DictionaryEntry(
                term: trimmedTerm,
                language: effectiveLanguage
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteCurrentEntry() {
        guard let entry = mode.entry else { return }
        dismiss()
        onDelete?(entry)
    }
}
