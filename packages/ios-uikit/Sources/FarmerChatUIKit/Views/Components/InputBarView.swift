#if canImport(UIKit)
import UIKit

/// Delegate protocol for input bar actions.
internal protocol InputBarViewDelegate: AnyObject {
    /// Called when the user taps the send button.
    func inputBarDidSend(text: String)
    /// Called when the user taps the camera button.
    func inputBarDidTapCamera()
    /// Called when the user taps the voice button.
    func inputBarDidTapVoice()
}

/// Chat input bar with text field, voice, and camera buttons.
///
/// Displays a text field with an adaptive trailing button: voice (mic) when the
/// field is empty, send (arrow) when text is present. An optional camera button
/// appears to the left.
internal final class InputBarView: UIView, UITextFieldDelegate {

    // MARK: - Properties

    weak var delegate: InputBarViewDelegate?
    var isEnabled: Bool = true {
        didSet { updateEnabledState() }
    }
    var voiceEnabled: Bool = true
    var cameraEnabled: Bool = true {
        didSet { cameraButton.isHidden = !cameraEnabled }
    }

    // MARK: - Subviews

    private let cameraButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        btn.setImage(UIImage(systemName: "camera.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityLabel = "Attach image"
        return btn
    }()

    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Ask about farming\u{2026}"
        tf.font = .preferredFont(forTextStyle: .body)
        tf.borderStyle = .none
        tf.returnKeyType = .send
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let textFieldContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 20
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.systemGray4.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        btn.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityLabel = "Send"
        return btn
    }()

    private let voiceButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        btn.setImage(UIImage(systemName: "mic.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityLabel = "Voice input"
        return btn
    }()

    private let topBorder: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.06)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
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
        backgroundColor = .systemBackground

        addSubview(topBorder)
        addSubview(cameraButton)
        addSubview(textFieldContainer)
        addSubview(sendButton)
        addSubview(voiceButton)

        textFieldContainer.addSubview(textField)
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),

            cameraButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            cameraButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            cameraButton.widthAnchor.constraint(equalToConstant: 36),
            cameraButton.heightAnchor.constraint(equalToConstant: 36),

            textFieldContainer.leadingAnchor.constraint(equalTo: cameraButton.trailingAnchor, constant: 8),
            textFieldContainer.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textFieldContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            textField.leadingAnchor.constraint(equalTo: textFieldContainer.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: textFieldContainer.trailingAnchor, constant: -12),
            textField.topAnchor.constraint(equalTo: textFieldContainer.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: textFieldContainer.bottomAnchor, constant: -8),

            sendButton.leadingAnchor.constraint(equalTo: textFieldContainer.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),

            voiceButton.leadingAnchor.constraint(equalTo: textFieldContainer.trailingAnchor, constant: 8),
            voiceButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            voiceButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            voiceButton.widthAnchor.constraint(equalToConstant: 36),
            voiceButton.heightAnchor.constraint(equalToConstant: 36),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])

        updateTrailingButton()
    }

    // MARK: - State

    @objc private func textChanged() {
        updateTrailingButton()
    }

    private func updateTrailingButton() {
        let hasText = !(textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if hasText {
            sendButton.isHidden = false
            voiceButton.isHidden = true
            let color = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
            sendButton.tintColor = isEnabled ? color : .secondaryLabel
        } else if voiceEnabled {
            sendButton.isHidden = true
            voiceButton.isHidden = false
        } else {
            sendButton.isHidden = false
            voiceButton.isHidden = true
            sendButton.tintColor = .secondaryLabel
        }
    }

    private func updateEnabledState() {
        alpha = isEnabled ? 1.0 : 0.5
        textField.isEnabled = isEnabled
        cameraButton.isEnabled = isEnabled
        sendButton.isEnabled = isEnabled
        voiceButton.isEnabled = isEnabled
        updateTrailingButton()
    }

    // MARK: - Actions

    @objc private func cameraTapped() {
        delegate?.inputBarDidTapCamera()
    }

    @objc private func voiceTapped() {
        delegate?.inputBarDidTapVoice()
    }

    @objc private func sendTapped() {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        delegate?.inputBarDidSend(text: text)
        textField.text = ""
        updateTrailingButton()
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return false
    }
}
#endif
