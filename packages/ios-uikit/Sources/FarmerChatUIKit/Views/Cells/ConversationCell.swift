#if canImport(UIKit)
import UIKit

/// History list cell representing a single conversation.
internal final class ConversationCell: UITableViewCell {

    static let reuseIdentifier = "ConversationCell"

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    // MARK: - Subviews

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.systemGray5.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
        label.textColor = .label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let previewLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let chevronView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let iv = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        iv.tintColor = .tertiaryLabel
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    // MARK: - Setup

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(previewLabel)
        cardView.addSubview(dateLabel)
        cardView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8),

            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            previewLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            dateLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

            chevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
        ])
    }

    // MARK: - Configure

    func configure(with conversation: ConversationResponse) {
        // Title
        if !conversation.title.isEmpty {
            titleLabel.text = conversation.title
        } else if let first = conversation.messages.first {
            titleLabel.text = String(first.text.prefix(60))
        } else {
            titleLabel.text = "Conversation"
        }

        // Preview
        if let last = conversation.messages.last {
            let preview = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
            previewLabel.text = preview.isEmpty ? nil : String(preview.prefix(120))
            previewLabel.isHidden = preview.isEmpty
        } else {
            previewLabel.isHidden = true
        }

        // Date
        let timestamp = conversation.updatedAt > 0 ? conversation.updatedAt : conversation.createdAt
        if timestamp > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
            dateLabel.text = Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
        } else {
            dateLabel.text = nil
        }
    }
}

// MARK: - UIFont+Traits Helper

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
}
#endif
