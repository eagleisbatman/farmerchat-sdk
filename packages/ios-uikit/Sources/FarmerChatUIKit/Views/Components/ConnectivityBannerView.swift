#if canImport(UIKit)
import UIKit

/// Banner shown when the device is offline.
///
/// Full-width bar with a wifi.slash icon and reconnecting message.
/// Uses a red-tinted background. Hidden when connected.
internal final class ConnectivityBannerView: UIView {

    // MARK: - Subviews

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = UIImage(systemName: "wifi.slash", withConfiguration: config)
        let iv = UIImageView(image: image)
        iv.tintColor = .systemRed
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "You\u{2019}re offline. Reconnecting\u{2026}"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .systemRed
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
        isAccessibilityElement = true
        accessibilityLabel = "You are offline. Reconnecting."

        addSubview(iconView)
        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 36),
        ])
    }
}
#endif
