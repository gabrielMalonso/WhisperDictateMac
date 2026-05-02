import SwiftUI
import UniformTypeIdentifiers

struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    @AppStorage(MacAppKeys.keyboardAccentColor, store: .app)
    private var accentColorRaw: String = AccentColorOption.default.rawValue

    @State private var showFileImporter = false

    private var accentColor: Color {
        (AccentColorOption(rawValue: accentColorRaw) ?? .default).color
    }

    private let rowFont = SettingsComponents.rowFont
    private let helperFont = SettingsComponents.helperFont

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                topicSection
                subjectSection
                descriptionSection

                Text(String(localized: "O envio abre uma issue no GitHub com a mensagem preenchida."))
                    .font(helperFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                submitButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .navigationTitle(String(localized: "Enviar Feedback"))
        .tint(accentColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(String(localized: "Feedback Enviado"), isPresented: $viewModel.showSuccess) {
            Button(String(localized: "OK")) { dismiss() }
        } message: {
            Text(String(localized: "Obrigado pelo seu feedback!"))
        }
        .alert(String(localized: "Erro"), isPresented: $viewModel.showError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.loadImages(from: urls)
            case .failure:
                viewModel.errorMessage = AppText.imageImportFailure()
                viewModel.showError = true
            }
        }
    }

    // MARK: - Topic Section

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsComponents.sectionHeader(String(localized: "Tópico"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FeedbackTopic.allCases) { topic in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.selectedTopic = topic
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: topic.symbolName)
                                    .font(rowFont)
                                Text(topic.label)
                                    .font(rowFont)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedTopic == topic ? accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                            .foregroundStyle(viewModel.selectedTopic == topic ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Subject Section

    private var subjectSection: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Assunto"))

            VStack(alignment: .trailing, spacing: 4) {
                TextField(String(localized: "Descreva brevemente..."), text: $viewModel.subject)
                    .font(rowFont)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .onChange(of: viewModel.subject) { _, newValue in
                        if newValue.count > 100 {
                            viewModel.subject = String(newValue.prefix(100))
                        }
                    }

                Text("\(viewModel.subject.count)/100")
                    .font(helperFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Descrição"))

            VStack(alignment: .trailing, spacing: 4) {
                TextEditor(text: $viewModel.descriptionText)
                    .font(rowFont)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .onChange(of: viewModel.descriptionText) { _, newValue in
                        if newValue.count > 1000 {
                            viewModel.descriptionText = String(newValue.prefix(1000))
                        }
                    }

                Text("\(viewModel.descriptionText.count)/1000")
                    .font(helperFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Screenshots Section

    private var screenshotsSection: some View {
        SettingsComponents.card {
            SettingsComponents.sectionHeader(String(localized: "Capturas de tela"))

            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.loadedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.loadedImages.enumerated()), id: \.offset) { index, nsImage in
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    Button {
                                        withAnimation {
                                            viewModel.removeImage(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(rowFont)
                        Text(String(localized: "Adicionar imagens"))
                            .font(rowFont)
                    }
                    .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Text(String(localized: "Opcional. Até 3 imagens."))
                    .font(helperFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 14)
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task { await viewModel.submitFeedback() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(String(localized: "Enviar Feedback"))
                    .font(rowFont.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(viewModel.isValid && !viewModel.isSubmitting ? accentColor : accentColor.opacity(0.4))
            )
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isValid || viewModel.isSubmitting)
    }
}
