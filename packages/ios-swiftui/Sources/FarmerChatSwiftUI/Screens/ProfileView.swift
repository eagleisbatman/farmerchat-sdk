import SwiftUI

/// User profile and settings view.
///
/// Displays language selection and SDK branding. Language changes are applied
/// immediately via `viewModel.setLanguage`.
struct ProfileView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    private var themeColor: Color {
        colorFromHex(config.theme?.primaryColor ?? "#1B6B3A")
    }

    private var cornerRadius: Double {
        config.theme?.cornerRadius ?? 12
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    viewModel.navigateTo(screen: .chat)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Back to chat")

                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeColor)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Language section
                    Text("Language")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    if viewModel.availableLanguages.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Loading languages...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.availableLanguages, id: \.code) { language in
                                ProfileLanguageCard(
                                    language: language,
                                    isSelected: viewModel.selectedLanguage == language.code,
                                    themeColor: themeColor,
                                    cornerRadius: cornerRadius,
                                    onTap: {
                                        viewModel.setLanguage(code: language.code)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 32)

                    // Footer
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.horizontal, 16)

                        if config.showPoweredBy {
                            Text("Powered by FarmerChat")
                                .font(.caption)
                                .foregroundColor(Color.gray.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)
                        }

                        Text("SDK v0.0.0")
                            .font(.caption2)
                            .foregroundColor(Color.gray.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .background(Color(white: 0.95))
        .task {
            if viewModel.availableLanguages.isEmpty {
                viewModel.loadLanguages()
            }
        }
    }
}

// MARK: - ProfileLanguageCard

/// A language option card with selection checkmark.
private struct ProfileLanguageCard: View {
    let language: LanguageResponse
    let isSelected: Bool
    let themeColor: Color
    let cornerRadius: Double
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)

                    if language.nativeName != language.name {
                        Text(language.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(themeColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? themeColor.opacity(0.06) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isSelected ? themeColor : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}
