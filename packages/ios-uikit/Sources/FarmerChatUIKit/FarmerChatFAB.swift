#if canImport(UIKit)
import UIKit

/// Floating Action Button for launching the FarmerChat widget.
///
/// A circular green button with a white message icon and shadow.
/// Place this in your view hierarchy and set `tapAction` to handle taps.
///
/// ```swift
/// let fab = FarmerChatFAB()
/// fab.tapAction = { [weak self] in
///     let chatNav = FarmerChat.shared.chatViewController()
///     self?.present(chatNav, animated: true)
/// }
/// view.addSubview(fab)
/// ```
public final class FarmerChatFAB: UIButton {

    /// Closure invoked when the FAB is tapped.
    public var tapAction: (() -> Void)?

    /// Diameter of the FAB circle in points. Defaults to 56.
    public var size: CGFloat = 56 {
        didSet { invalidateIntrinsicContentSize(); setNeedsLayout() }
    }

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupFAB()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFAB()
    }

    // MARK: - Setup

    private func setupFAB() {
        let config = FarmerChat.getConfig()
        let primaryHex = config.theme?.primaryColor ?? "#1B6B3A"
        backgroundColor = UIColor(hex: primaryHex)

        // Message icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let icon = UIImage(systemName: "message.fill", withConfiguration: iconConfig)
        setImage(icon, for: .normal)
        tintColor = .white
        imageView?.contentMode = .scaleAspectFit

        // Shape and shadow
        layer.cornerRadius = size / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        // Action
        addTarget(self, action: #selector(fabTapped), for: .touchUpInside)

        // Accessibility
        accessibilityLabel = "Open FarmerChat"
    }

    // MARK: - Layout

    public override var intrinsicContentSize: CGSize {
        CGSize(width: size, height: size)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    // MARK: - Action

    @objc private func fabTapped() {
        tapAction?()
    }
}
#endif
