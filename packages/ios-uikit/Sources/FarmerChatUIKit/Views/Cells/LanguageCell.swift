#if canImport(UIKit)
import UIKit

/// Language card cell for both onboarding and profile language lists.
internal final class LanguageCell: UITableViewCell {

    static let reuseIdentifier = "LanguageCell"

    // MARK: - Subviews

    private let cardView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nativeNameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body, compatibleWith: nil)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkmarkView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: config))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
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
        cardView.addSubview(nativeNameLabel)
        cardView.addSubview(nameLabel)
        cardView.addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            nativeNameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            nativeNameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            nativeNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),

            nameLabel.topAnchor.constraint(equalTo: nativeNameLabel.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

            checkmarkView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            checkmarkView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 22),
            checkmarkView.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    // MARK: - Configure

    func configure(language: LanguageResponse, isSelected: Bool, themeColor: UIColor) {
        nativeNameLabel.text = language.nativeName
        nameLabel.text = language.nativeName != language.name ? language.name : nil
        nameLabel.isHidden = language.nativeName == language.name

        checkmarkView.isHidden = !isSelected
        checkmarkView.tintColor = themeColor

        if isSelected {
            cardView.backgroundColor = themeColor.withAlphaComponent(0.06)
            cardView.layer.borderColor = themeColor.cgColor
            cardView.layer.borderWidth = 2
        } else {
            cardView.backgroundColor = UIColor.systemGray6
            cardView.layer.borderColor = UIColor.clear.cgColor
            cardView.layer.borderWidth = 0
        }
    }
}
#endif
