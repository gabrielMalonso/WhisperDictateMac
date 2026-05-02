import SwiftData
import SwiftUI

struct ReplacementRulesView: View {
    @Query(sort: \ReplacementRule.createdAt, order: .reverse)
    private var rules: [ReplacementRule]

    @Environment(\.modelContext) private var modelContext

    @AppStorage(MacAppKeys.replacementRulesEnabled, store: .app)
    private var rulesEnabled: Bool = true

    @State private var sheetMode: SheetMode?
    @State private var selection: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var showDeleteAlert = false
    @State private var pendingDeleteRules: [ReplacementRule] = []

    // MARK: - Computed properties

    private var filteredRules: [ReplacementRule] {
        guard !searchText.isEmpty else { return rules }
        return rules.filter {
            $0.originalText.localizedCaseInsensitiveContains(searchText) ||
            $0.replacementText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                Toggle(String(localized: "Ativar substituições"), isOn: $rulesEnabled)
                    .toggleStyle(.switch)
            }

            if rules.isEmpty {
                ContentUnavailableView(
                    String(localized: "Nenhuma regra criada"),
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text(String(localized: "Regras de substituição corrigem automaticamente palavras frequentes."))
                )
                .listRowBackground(Color.clear)
            } else if filteredRules.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredRules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.originalText)
                                    .font(AppTypography.row)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(AppTypography.helper)
                                        .foregroundStyle(.secondary)
                                    Text(rule.replacementText)
                                        .font(AppTypography.row)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                if rule.useCount > 0 {
                                    Text(String(localized: "Usada \(rule.useCount)×"))
                                        .font(AppTypography.helper)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { newValue in
                                    rule.isEnabled = newValue
                                    markUpdatedAndPush(rule)
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }
                        .opacity(rule.isEnabled ? 1 : 0.5)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(String(localized: "Editar")) { sheetMode = .edit(rule) }
                            Divider()
                            Button(rule.isEnabled
                                ? String(localized: "Desativar Regra")
                                : String(localized: "Ativar Regra")
                            ) {
                                rule.isEnabled.toggle()
                                markUpdatedAndPush(rule)
                            }
                            Divider()
                            Button(String(localized: "Apagar"), role: .destructive) {
                                pendingDeleteRules = [rule]
                                showDeleteAlert = true
                            }
                        }
                    }
                    .onDelete(perform: deleteRules)
                }
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "Buscar regras"))
        .onDeleteCommand {
            let selected = rules.filter { selection.contains($0.id) }
            guard !selected.isEmpty else { return }
            pendingDeleteRules = selected
            showDeleteAlert = true
        }
        .onKeyPress(.return) {
            guard selection.count == 1,
                  let rule = rules.first(where: { $0.id == selection.first }) else {
                return .ignored
            }
            sheetMode = .edit(rule)
            return .handled
        }
        .listStyle(.inset)
        .safeAreaPadding(.horizontal, 12)
        .navigationTitle(String(localized: "Regras de Substituição"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheetMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            if selection.count == 1,
               let rule = rules.first(where: { $0.id == selection.first }) {
                ToolbarItem(placement: .automatic) {
                    Button {
                        sheetMode = .edit(rule)
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }

            if !selection.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        pendingDeleteRules = rules.filter { selection.contains($0.id) }
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .sheet(item: $sheetMode) { mode in
            RuleFormSheet(mode: mode, modelContext: modelContext, onDelete: { rule in
                deleteRule(rule)
                selection.remove(rule.id)
            })
        }
        .alert(
            pendingDeleteRules.count == 1
                ? String(localized: "Excluir Regra")
                : String(localized: "Excluir \(pendingDeleteRules.count) Regras"),
            isPresented: $showDeleteAlert
        ) {
            Button(String(localized: "Cancelar"), role: .cancel) { pendingDeleteRules = [] }
            Button(String(localized: "Excluir"), role: .destructive) { performPendingDelete() }
        } message: {
            Text(
                pendingDeleteRules.count == 1
                    ? String(localized: "Tem certeza que deseja excluir esta regra?")
                    : String(localized: "Tem certeza que deseja excluir as \(pendingDeleteRules.count) regras selecionadas?")
            )
        }
    }

    // MARK: - Actions

    private func markUpdatedAndPush(_ rule: ReplacementRule) {
        rule.updatedAt = .now
        try? modelContext.save()
    }

    private func deleteRule(_ rule: ReplacementRule) {
        modelContext.delete(rule)
        try? modelContext.save()
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            let rule = filteredRules[index]
            rule.updatedAt = .now
            modelContext.delete(rule)
        }
        try? modelContext.save()
    }

    private func performPendingDelete() {
        for rule in pendingDeleteRules {
            deleteRule(rule)
        }
        selection.subtract(pendingDeleteRules.map { $0.id })
        pendingDeleteRules = []
    }
}

// MARK: - Sheet Mode

private enum SheetMode: Identifiable {
    case create
    case edit(ReplacementRule)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let rule): rule.id.uuidString
        }
    }

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }

    var rule: ReplacementRule? {
        if case .edit(let rule) = self { return rule }
        return nil
    }
}

// MARK: - Rule Form Sheet

private struct RuleFormSheet: View {
    let mode: SheetMode
    let modelContext: ModelContext
    var onDelete: ((ReplacementRule) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var originalText: String
    @State private var replacementText: String

    init(mode: SheetMode, modelContext: ModelContext, onDelete: ((ReplacementRule) -> Void)? = nil) {
        self.mode = mode
        self.modelContext = modelContext
        self.onDelete = onDelete
        _originalText = State(initialValue: mode.rule?.originalText ?? "")
        _replacementText = State(initialValue: mode.rule?.replacementText ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(String(localized: "Cancelar")) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(mode.isEditing ? String(localized: "Editar Regra") : String(localized: "Nova Regra"))
                    .font(.headline)

                Spacer()

                Button(mode.isEditing ? String(localized: "Salvar") : String(localized: "Adicionar")) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(originalText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Form content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Quando transcrever"))
                        .font(AppTypography.row)
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "Texto original"), text: $originalText)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Substituir por"))
                        .font(AppTypography.row)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $replacementText)
                        .disableAutocorrection(true)
                        .font(AppTypography.row)
                        .frame(maxHeight: .infinity)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                }

                if mode.isEditing {
                    Divider()
                        .padding(.top, 4)

                    Button(role: .destructive) {
                        deleteCurrentRule()
                    } label: {
                        Text(String(localized: "Excluir Regra"))
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
        .frame(width: 640, height: mode.isEditing ? 480 : 400)
    }

    private func save() {
        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespaces)
        let trimmedReplacement = replacementText.trimmingCharacters(in: .whitespaces)

        let rule: ReplacementRule
        if let existing = mode.rule {
            existing.updatedAt = .now
            existing.originalText = trimmedOriginal
            existing.replacementText = trimmedReplacement
            rule = existing
        } else {
            rule = ReplacementRule(
                originalText: trimmedOriginal,
                replacementText: trimmedReplacement
            )
            modelContext.insert(rule)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteCurrentRule() {
        guard let rule = mode.rule else { return }
        dismiss()
        onDelete?(rule)
    }
}
