import SwiftUI

/// User profile and settings view — dark forest-green theme.
///
/// Loads supported languages from the server and allows the user to select one.
/// Navigates back to the chat screen after a language is chosen.
struct ProfileView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    // Flatten all languages from all groups for display
    private var allLanguages: [SupportedLanguage] {
        viewModel.availableLanguageGroups.flatMap { $0.languages }
    }

    // MARK: – Dark palette (matches Chat / History screens)
    private let bg         = Color(red: 0.059, green: 0.102, blue: 0.051)   // #0F1A0D
    private let toolbar    = Color(red: 0.102, green: 0.137, blue: 0.094)   // #1A2318
    private let surface    = Color(red: 0.102, green: 0.137, blue: 0.094)   // #1A2318
    private let surface2   = Color(red: 0.141, green: 0.188, blue: 0.125)   // #243020
    private let accentGreen = Color(red: 0.298, green: 0.686, blue: 0.314)  // #4CAF50
    private let onlineGreen = Color(red: 0.412, green: 0.941, blue: 0.682)  // #69F0AE
    private let textPrimary  = Color(red: 0.910, green: 0.961, blue: 0.914) // #E8F5E9
    private let textSecondary = Color(red: 0.561, green: 0.659, blue: 0.549) // #8FA88C
    private let textMuted  = Color(red: 0.353, green: 0.420, blue: 0.345)   // #5A6B58

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarView
                languageSection
                footerView
            }
        }
        .onAppear { viewModel.loadLanguages() }
    }

    // MARK: – Toolbar

    private var toolbarView: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.navigateTo(.chat)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Back to chat")

            VStack(alignment: .leading, spacing: 2) {
                Text("Language")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textPrimary)
                Text("Choose your preferred language")
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(alignment: .top) {
            toolbar.ignoresSafeArea(edges: .top)
        }
    }

    // MARK: – Language list

    private var languageSection: some View {
        ScrollView {
            VStack(spacing: 8) {
                if allLanguages.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: accentGreen))
                            .scaleEffect(1.2)
                        Text("Loading languages…")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(allLanguages) { language in
                        LanguageRow(
                            language: language,
                            isSelected: language.code == viewModel.selectedLanguage,
                            accentGreen: accentGreen,
                            surface: surface,
                            surface2: surface2,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onSelect: {
                                viewModel.setPreferredLanguage(language)
                                viewModel.navigateTo(.chat)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: – Footer

    private var footerView: some View {
        VStack(spacing: 4) {
            Divider()
                .background(textMuted.opacity(0.5))
            if config.showPoweredBy {
                Text("Powered by FarmerChat")
                    .font(.system(size: 12))
                    .foregroundColor(textMuted)
                    .padding(.top, 8)
            }
            Text("SDK v0.0.0")
                .font(.system(size: 11))
                .foregroundColor(textMuted.opacity(0.6))
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Language row

private struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let accentGreen: Color
    let surface: Color
    let surface2: Color
    let textPrimary: Color
    let textSecondary: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Speaker icon
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? accentGreen : textSecondary)
                    .frame(width: 20)

                // Names
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName.isEmpty ? language.name : language.displayName)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(textPrimary)
                    if !language.name.isEmpty && language.name != language.displayName {
                        Text(language.name)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                }

                Spacer()

                // Check indicator
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(accentGreen)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentGreen.opacity(0.12) : surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? accentGreen.opacity(0.6) : surface2, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(language.displayName.isEmpty ? language.name : language.displayName), \(isSelected ? "selected" : "not selected")")
    }
}
