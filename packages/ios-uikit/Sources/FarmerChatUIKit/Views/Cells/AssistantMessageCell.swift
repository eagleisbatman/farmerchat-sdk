#if canImport(UIKit)
import AVFoundation
import UIKit

/// Delegate for assistant message cell actions.
internal protocol AssistantMessageCellDelegate: AnyObject {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapFollowUp text: String)
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapFeedback rating: String)
    /// Called when the Listen button is tapped. Implementor calls synthesiseAudio and returns the URL.
    func assistantMessageCell(_ cell: AssistantMessageCell,
                               synthesiseAudioFor msgId: String,
                               text: String,
                               completion: @escaping (String?) -> Void)
}

/// Left-aligned assistant message cell with avatar, markdown, follow-ups, actions and feedback.
internal final class AssistantMessageCell: UITableViewCell {

    static let reuseIdentifier = "AssistantMessageCell"

    weak var delegate: AssistantMessageCellDelegate?

    private var followUps: [FollowUpQuestionOption] = []
    private var currentFeedbackRating: String?
    private var isStreaming = false
    private var currentMessageId: String?
    private var currentText: String = ""

    // Audio playback
    private var audioPlayer: AVPlayer?
    private var playerObserver: Any?
    private var listenState: ListenButtonState = .idle {
        didSet { updateListenButton() }
    }
    enum ListenButtonState { case idle, loading, playing }

    // MARK: - Subviews

    private let primaryColor: UIColor = UIColor(hex: "#1B6B3A")

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

    // ── Actions row: Listen + Copy ──────────────────────────────────────────────

    private lazy var actionsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var listenButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 12
        btn.layer.borderWidth = 1
        btn.layer.borderColor = primaryColor.cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.addTarget(self, action: #selector(listenTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private lazy var listenSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = primaryColor
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private lazy var copyButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        btn.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: cfg), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.backgroundColor = UIColor.systemGray5
        btn.layer.cornerRadius = 15
        btn.widthAnchor.constraint(equalToConstant: 30).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        btn.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Copy response"
        return btn
    }()

    // ── Feedback ──────────────────────────────────────────────────────────────

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
        stopAudio()
    }

    // MARK: - Setup

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(markdownView)
        contentView.addSubview(cursorView)

        followUpScroll.addSubview(followUpStack)
        contentView.addSubview(followUpScroll)

        // Actions row
        listenButton.addSubview(listenSpinner)
        actionsStack.addArrangedSubview(listenButton)
        actionsStack.addArrangedSubview(copyButton)
        let actionsSpacer = UIView()
        actionsSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionsStack.addArrangedSubview(actionsSpacer)
        contentView.addSubview(actionsStack)

        // Feedback
        feedbackStack.addArrangedSubview(thumbsUpButton)
        feedbackStack.addArrangedSubview(thumbsDownButton)
        let fbSpacer = UIView()
        fbSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        feedbackStack.addArrangedSubview(fbSpacer)
        contentView.addSubview(feedbackStack)

        thumbsUpButton.addTarget(self, action: #selector(thumbsUpTapped), for: .touchUpInside)
        thumbsDownButton.addTarget(self, action: #selector(thumbsDownTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            markdownView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            markdownView.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            markdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            cursorView.topAnchor.constraint(equalTo: markdownView.bottomAnchor, constant: 2),
            cursorView.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            cursorView.widthAnchor.constraint(equalToConstant: 8),
            cursorView.heightAnchor.constraint(equalToConstant: 16),

            followUpScroll.topAnchor.constraint(equalTo: cursorView.bottomAnchor, constant: 4),
            followUpScroll.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            followUpScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            followUpScroll.heightAnchor.constraint(equalToConstant: 32),

            followUpStack.topAnchor.constraint(equalTo: followUpScroll.topAnchor),
            followUpStack.bottomAnchor.constraint(equalTo: followUpScroll.bottomAnchor),
            followUpStack.leadingAnchor.constraint(equalTo: followUpScroll.leadingAnchor),
            followUpStack.trailingAnchor.constraint(equalTo: followUpScroll.trailingAnchor),
            followUpStack.heightAnchor.constraint(equalTo: followUpScroll.heightAnchor),

            actionsStack.topAnchor.constraint(equalTo: followUpScroll.bottomAnchor, constant: 6),
            actionsStack.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            actionsStack.heightAnchor.constraint(equalToConstant: 32),

            listenSpinner.centerXAnchor.constraint(equalTo: listenButton.centerXAnchor),
            listenSpinner.centerYAnchor.constraint(equalTo: listenButton.centerYAnchor),

            feedbackStack.topAnchor.constraint(equalTo: actionsStack.bottomAnchor, constant: 4),
            feedbackStack.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            feedbackStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            feedbackStack.heightAnchor.constraint(equalToConstant: 32),
            feedbackStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])

        updateListenButton()
    }

    // MARK: - Configure

    func configure(with message: ChatViewModel.ChatMessage, isStreaming: Bool) {
        self.isStreaming = isStreaming
        self.followUps = message.followUps
        self.currentFeedbackRating = message.feedbackRating
        self.currentMessageId = message.serverMessageId
        self.currentText = message.text

        markdownView.markdownText = message.text

        cursorView.isHidden = !isStreaming
        if isStreaming { startCursorAnimation() } else { stopCursorAnimation() }

        buildFollowUpChips()
        followUpScroll.isHidden = isStreaming || message.followUps.isEmpty

        // Actions row
        let showListen = !isStreaming && !message.hideTtsSpeaker && !(message.serverMessageId ?? "").isEmpty
        listenButton.isHidden = !showListen
        actionsStack.isHidden = isStreaming

        feedbackStack.isHidden = isStreaming
        updateFeedbackColors()

        // Reset listen state when cell is rebound to a new message
        if listenState != .idle { stopAudio() }
    }

    // MARK: - Listen button states

    private func updateListenButton() {
        switch listenState {
        case .idle:
            listenSpinner.stopAnimating()
            listenButton.isEnabled = true
            let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let img = UIImage(systemName: "speaker.wave.2.fill", withConfiguration: cfg)
            listenButton.setImage(img, for: .normal)
            listenButton.setTitle(" Listen", for: .normal)
            listenButton.tintColor = primaryColor
            listenButton.setTitleColor(primaryColor, for: .normal)
        case .loading:
            listenButton.setImage(nil, for: .normal)
            listenButton.setTitle("", for: .normal)
            listenButton.isEnabled = false
            listenSpinner.startAnimating()
        case .playing:
            listenSpinner.stopAnimating()
            listenButton.isEnabled = true
            let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let img = UIImage(systemName: "stop.fill", withConfiguration: cfg)
            listenButton.setImage(img, for: .normal)
            listenButton.setTitle(" Stop", for: .normal)
            listenButton.tintColor = primaryColor
            listenButton.setTitleColor(primaryColor, for: .normal)
        }
    }

    // MARK: - Audio

    private func playAudio(urlString: String) {
        guard let url = URL(string: urlString) else { listenState = .idle; return }
        stopAudio()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        audioPlayer = player
        player.play()
        listenState = .playing
        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.listenState = .idle
        }
        playerObserver = obs
    }

    private func stopAudio() {
        audioPlayer?.pause()
        audioPlayer = nil
        if let obs = playerObserver {
            NotificationCenter.default.removeObserver(obs)
            playerObserver = nil
        }
        listenState = .idle
    }

    // MARK: - Follow-up chips

    private func buildFollowUpChips() {
        followUpStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        let cornerRadius = FarmerChat.getConfig().theme?.cornerRadius ?? 12
        for followUp in followUps {
            let btn = UIButton(type: .system)
            btn.setTitle(followUp.question ?? "", for: .normal)
            btn.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
            btn.setTitleColor(pColor, for: .normal)
            btn.layer.cornerRadius = CGFloat(min(cornerRadius, 16))
            btn.layer.borderWidth = 1
            btn.layer.borderColor = pColor.withAlphaComponent(0.3).cgColor
            btn.backgroundColor = pColor.withAlphaComponent(0.08)
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            btn.addTarget(self, action: #selector(followUpTapped(_:)), for: .touchUpInside)
            followUpStack.addArrangedSubview(btn)
        }
    }

    // MARK: - Cursor animation

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
        thumbsUpButton.tintColor  = currentFeedbackRating == "positive" ? greenColor : .secondaryLabel
        thumbsDownButton.tintColor = currentFeedbackRating == "negative" ? .systemRed  : .secondaryLabel
    }

    // MARK: - Actions

    @objc private func listenTapped() {
        switch listenState {
        case .idle:
            guard let msgId = currentMessageId, !msgId.isEmpty else { return }
            listenState = .loading
            delegate?.assistantMessageCell(self, synthesiseAudioFor: msgId, text: currentText) { [weak self] url in
                DispatchQueue.main.async {
                    if let url = url, !url.isEmpty {
                        self?.playAudio(urlString: url)
                    } else {
                        self?.listenState = .idle
                    }
                }
            }
        case .playing:
            stopAudio()
        case .loading:
            break
        }
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = currentText
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        copyButton.setImage(UIImage(systemName: "checkmark", withConfiguration: cfg), for: .normal)
        copyButton.tintColor = primaryColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let cfgR = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            self?.copyButton.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: cfgR), for: .normal)
            self?.copyButton.tintColor = .secondaryLabel
        }
    }

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
        stopAudio()
        delegate = nil
    }
}
#endif
