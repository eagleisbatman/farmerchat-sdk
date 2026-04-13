#if canImport(UIKit)
import UIKit

/// Delegate for assistant message cell actions.
internal protocol AssistantMessageCellDelegate: AnyObject {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapFollowUp text: String)
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapFeedback rating: String)
}

/// Left-aligned assistant message cell with avatar, markdown, follow-ups, and feedback.
internal final class AssistantMessageCell: UITableViewCell {

    static let reuseIdentifier = "AssistantMessageCell"

    weak var delegate: AssistantMessageCellDelegate?

    private var followUps: [FollowUpQuestionOption] = []
    private var currentFeedbackRating: String?
    private var isStreaming = false

    // MARK: - Subviews

    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#1B6B3A")
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.text = "FC"
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let markdownView: MarkdownLabel = {
        let view = MarkdownLabel(frame: .zero, textContainer: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cursorView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#1B6B3A")
        v.layer.cornerRadius = 1
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let followUpStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 6
        sv.alignment = .center
        sv.distribution = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let followUpScroll: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let feedbackStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let thumbsUpButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        btn.setImage(UIImage(systemName: "hand.thumbsup.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.accessibilityLabel = "Helpful"
        return btn
    }()

    private let thumbsDownButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        btn.setImage(UIImage(systemName: "hand.thumbsdown.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.accessibilityLabel = "Not helpful"
        return btn
    }()

    // Cursor animation
    private var cursorTimer: Timer?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    deinit {
        cursorTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Avatar
        contentView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)

        // Markdown view
        contentView.addSubview(markdownView)

        // Cursor
        contentView.addSubview(cursorView)

        // Follow-up scroll + stack
        followUpScroll.addSubview(followUpStack)
        contentView.addSubview(followUpScroll)

        // Feedback
        feedbackStack.addArrangedSubview(thumbsUpButton)
        feedbackStack.addArrangedSubview(thumbsDownButton)
        // Spacer
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        feedbackStack.addArrangedSubview(spacer)
        contentView.addSubview(feedbackStack)

        thumbsUpButton.addTarget(self, action: #selector(thumbsUpTapped), for: .touchUpInside)
        thumbsDownButton.addTarget(self, action: #selector(thumbsDownTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Avatar
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            // Markdown
            markdownView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            markdownView.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            markdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            // Cursor
            cursorView.topAnchor.constraint(equalTo: markdownView.bottomAnchor, constant: 2),
            cursorView.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            cursorView.widthAnchor.constraint(equalToConstant: 8),
            cursorView.heightAnchor.constraint(equalToConstant: 16),

            // Follow-up scroll
            followUpScroll.topAnchor.constraint(equalTo: cursorView.bottomAnchor, constant: 4),
            followUpScroll.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            followUpScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            followUpScroll.heightAnchor.constraint(equalToConstant: 32),

            followUpStack.topAnchor.constraint(equalTo: followUpScroll.topAnchor),
            followUpStack.bottomAnchor.constraint(equalTo: followUpScroll.bottomAnchor),
            followUpStack.leadingAnchor.constraint(equalTo: followUpScroll.leadingAnchor),
            followUpStack.trailingAnchor.constraint(equalTo: followUpScroll.trailingAnchor),
            followUpStack.heightAnchor.constraint(equalTo: followUpScroll.heightAnchor),

            // Feedback
            feedbackStack.topAnchor.constraint(equalTo: followUpScroll.bottomAnchor, constant: 4),
            feedbackStack.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            feedbackStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            feedbackStack.heightAnchor.constraint(equalToConstant: 32),
            feedbackStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Configure

    func configure(with message: ChatViewModel.ChatMessage, isStreaming: Bool) {
        self.isStreaming = isStreaming
        self.followUps = message.followUps
        self.currentFeedbackRating = message.feedbackRating

        markdownView.markdownText = message.text

        // Cursor visibility
        cursorView.isHidden = !isStreaming
        if isStreaming {
            startCursorAnimation()
        } else {
            stopCursorAnimation()
        }

        // Follow-ups
        buildFollowUpChips()
        followUpScroll.isHidden = isStreaming || message.followUps.isEmpty

        // Feedback
        feedbackStack.isHidden = isStreaming
        updateFeedbackColors()
    }

    // MARK: - Follow-up Chips

    private func buildFollowUpChips() {
        followUpStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let primaryColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        let cornerRadius = FarmerChat.getConfig().theme?.cornerRadius ?? 12

        for followUp in followUps {
            let btn = UIButton(type: .system)
            btn.setTitle(followUp.question ?? "", for: .normal)
            btn.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
            btn.setTitleColor(primaryColor, for: .normal)
            btn.layer.cornerRadius = CGFloat(min(cornerRadius, 16))
            btn.layer.borderWidth = 1
            btn.layer.borderColor = primaryColor.withAlphaComponent(0.3).cgColor
            btn.backgroundColor = primaryColor.withAlphaComponent(0.08)
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            btn.addTarget(self, action: #selector(followUpTapped(_:)), for: .touchUpInside)
            followUpStack.addArrangedSubview(btn)
        }
    }

    // MARK: - Cursor Animation

    private func startCursorAnimation() {
        cursorTimer?.invalidate()
        cursorView.alpha = 1.0
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.25) {
                self.cursorView.alpha = self.cursorView.alpha > 0.5 ? 0.0 : 1.0
            }
        }
    }

    private func stopCursorAnimation() {
        cursorTimer?.invalidate()
        cursorTimer = nil
    }

    // MARK: - Feedback

    private func updateFeedbackColors() {
        let greenColor = UIColor(hex: "#1B6B3A")
        thumbsUpButton.tintColor = currentFeedbackRating == "positive" ? greenColor : .secondaryLabel
        thumbsDownButton.tintColor = currentFeedbackRating == "negative" ? .systemRed : .secondaryLabel
    }

    // MARK: - Actions

    @objc private func followUpTapped(_ sender: UIButton) {
        guard let text = sender.title(for: .normal) else { return }
        delegate?.assistantMessageCell(self, didTapFollowUp: text)
    }

    @objc private func thumbsUpTapped() {
        delegate?.assistantMessageCell(self, didTapFeedback: "positive")
    }

    @objc private func thumbsDownTapped() {
        delegate?.assistantMessageCell(self, didTapFeedback: "negative")
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        stopCursorAnimation()
        cursorView.isHidden = true
        followUpStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        delegate = nil
    }
}
#endif
