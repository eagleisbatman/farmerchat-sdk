#if canImport(UIKit)
import UIKit
import Combine
import AVFoundation
import PhotosUI

/// Main chat view controller.
/// Layout: TopBar + ConnectivityBanner + WeatherWidget (optional) + (StarterArea or MessageList)
///         + StreamingBar + ErrorBar + InputBar
internal final class ChatViewController: UIViewController {

    // MARK: - Properties

    private let viewModel = ChatViewModel()
    private var cancellables = Set<AnyCancellable>()

    // Audio recording
    private var audioRecorder: AVAudioRecorder?
    private var audioRecordingURL: URL?
    private var isRecording = false
    private var recordingTimer: Timer?
    private var voiceOverlay: UIView?

    // Weather widget
    private let weatherCard = UIView()
    private var weatherCardHeightConstraint: NSLayoutConstraint!

    // MARK: - Subviews

    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let historyButton = UIButton(type: .system)
    private let profileButton = UIButton(type: .system)
    private let connectivityBanner = ConnectivityBannerView()
    private let tableView = UITableView()
    private let starterScrollView = UIScrollView()
    private let starterStack = UIStackView()
    private let starterIcon = UIImageView()
    private let starterPromptLabel = UILabel()
    private let starterChipStack = UIStackView()
    private let streamingBar = UIView()
    private let streamingDot = UIView()
    private let streamingLabel = UILabel()
    private let stopButton = UIButton(type: .system)
    private let errorBar = UIView()
    private let errorIcon = UIImageView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let inputBar = InputBarView()

    // Cursor animation
    private var dotTimer: Timer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        bindViewModel()
        viewModel.loadStarters()
        // Ensure language list is loaded and auto-sync runs for returning users.
        // Returning users skip OnboardingViewController so loadLanguages is never called
        // from there; without this call the server never receives set_preferred_language
        // and returns response: null.
        viewModel.loadLanguages()

        // Emit chatOpened
        FarmerChat.shared.eventCallback?(.chatOpened(
            sessionId: FarmerChat.shared.getSessionId(),
            timestamp: Date()
        ))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dotTimer?.invalidate()

        // Only emit chatClosed when truly dismissed (not on push navigation)
        if isMovingFromParent || isBeingDismissed {
            FarmerChat.shared.eventCallback?(.chatClosed(
                sessionId: FarmerChat.shared.getSessionId(),
                messageCount: viewModel.messages.count,
                timestamp: Date()
            ))
        }
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.12, alpha: 1)

        setupTopBar()
        setupConnectivityBanner()
        setupWeatherWidget()
        setupStarterArea()
        setupTableView()
        setupStreamingBar()
        setupErrorBar()
        setupInputBar()
        setupConstraints()
        setupKeyboardHandling()
    }

    private func setupWeatherWidget() {
        let config = FarmerChat.getConfig()
        weatherCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(weatherCard)

        let hasWeather = config.weatherTemp != nil
        weatherCardHeightConstraint = weatherCard.heightAnchor.constraint(equalToConstant: hasWeather ? 72 : 0)

        guard hasWeather,
              let temp = config.weatherTemp,
              let loc  = config.weatherLocation else { return }

        weatherCard.backgroundColor = UIColor(red: 0.0, green: 0.39, blue: 0.22, alpha: 0.85)
        weatherCard.layer.cornerRadius = 12
        weatherCard.layer.masksToBounds = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(weatherCardTapped))
        weatherCard.addGestureRecognizer(tap)

        let tempLabel = UILabel()
        tempLabel.text = temp
        tempLabel.font = .boldSystemFont(ofSize: 20)
        tempLabel.textColor = .white
        tempLabel.translatesAutoresizingMaskIntoConstraints = false

        let locLabel = UILabel()
        locLabel.text = loc
        locLabel.font = .systemFont(ofSize: 12)
        locLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        locLabel.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [tempLabel, locLabel])
        leftStack.axis = .vertical; leftStack.spacing = 2
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        weatherCard.addSubview(leftStack)

        if let crop = config.cropName {
            let cropChip = UILabel()
            cropChip.text = "🌱 \(crop)"
            cropChip.font = .systemFont(ofSize: 12, weight: .medium)
            cropChip.textColor = .white
            cropChip.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            cropChip.layer.cornerRadius = 8
            cropChip.layer.masksToBounds = true
            cropChip.textAlignment = .center
            cropChip.translatesAutoresizingMaskIntoConstraints = false
            weatherCard.addSubview(cropChip)
            NSLayoutConstraint.activate([
                cropChip.trailingAnchor.constraint(equalTo: weatherCard.trailingAnchor, constant: -12),
                cropChip.centerYAnchor.constraint(equalTo: weatherCard.centerYAnchor),
                cropChip.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
                cropChip.heightAnchor.constraint(equalToConstant: 28),
            ])
        }

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: weatherCard.leadingAnchor, constant: 16),
            leftStack.centerYAnchor.constraint(equalTo: weatherCard.centerYAnchor),
        ])
    }

    @objc private func weatherCardTapped() {
        let question = "What is the weather forecast for my area and how does it affect my crops?"
        viewModel.sendWeatherQuery(question)
    }

    private func setupTopBar() {
        let config = FarmerChat.getConfig()
        let primaryColor = UIColor(hex: config.theme?.primaryColor ?? "#1B6B3A")

        topBar.backgroundColor = primaryColor
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        titleLabel.text = config.headerTitle
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)

        historyButton.setImage(UIImage(systemName: "clock.arrow.circlepath", withConfiguration: iconConfig), for: .normal)
        historyButton.tintColor = .white
        historyButton.isHidden = !config.historyEnabled
        historyButton.accessibilityLabel = "Chat history"
        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(historyButton)

        profileButton.setImage(UIImage(systemName: "person.circle", withConfiguration: iconConfig), for: .normal)
        profileButton.tintColor = .white
        profileButton.isHidden = !config.profileEnabled
        profileButton.accessibilityLabel = "Settings"
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(profileButton)
    }

    private func setupConnectivityBanner() {
        connectivityBanner.translatesAutoresizingMaskIntoConstraints = false
        connectivityBanner.isHidden = true
        view.addSubview(connectivityBanner)
    }

    private func setupStarterArea() {
        starterScrollView.translatesAutoresizingMaskIntoConstraints = false
        starterScrollView.alwaysBounceVertical = true
        view.addSubview(starterScrollView)

        starterStack.axis = .vertical
        starterStack.alignment = .center
        starterStack.spacing = 24
        starterStack.translatesAutoresizingMaskIntoConstraints = false
        starterScrollView.addSubview(starterStack)

        let primaryColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        starterIcon.image = UIImage(systemName: "leaf.fill", withConfiguration: iconConfig)
        starterIcon.tintColor = primaryColor.withAlphaComponent(0.6)
        starterIcon.translatesAutoresizingMaskIntoConstraints = false

        starterPromptLabel.text = "Ask a question about farming to get started"
        starterPromptLabel.font = .preferredFont(forTextStyle: .body)
        starterPromptLabel.textColor = .secondaryLabel
        starterPromptLabel.textAlignment = .center
        starterPromptLabel.numberOfLines = 0
        starterPromptLabel.translatesAutoresizingMaskIntoConstraints = false

        starterChipStack.axis = .vertical
        starterChipStack.alignment = .center
        starterChipStack.spacing = 8
        starterChipStack.translatesAutoresizingMaskIntoConstraints = false

        // Add spacer on top
        let topSpacer = UIView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        topSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true

        starterStack.addArrangedSubview(topSpacer)
        starterStack.addArrangedSubview(starterIcon)
        starterStack.addArrangedSubview(starterPromptLabel)
        starterStack.addArrangedSubview(starterChipStack)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.register(UserMessageCell.self, forCellReuseIdentifier: UserMessageCell.reuseIdentifier)
        tableView.register(AssistantMessageCell.self, forCellReuseIdentifier: AssistantMessageCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.isHidden = true
        view.addSubview(tableView)
    }

    private func setupStreamingBar() {
        streamingBar.backgroundColor = .systemBackground
        streamingBar.isHidden = true
        streamingBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(streamingBar)

        let primaryColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")

        streamingDot.backgroundColor = primaryColor
        streamingDot.layer.cornerRadius = 4
        streamingDot.translatesAutoresizingMaskIntoConstraints = false
        streamingBar.addSubview(streamingDot)

        streamingLabel.text = "Generating response..."
        streamingLabel.font = .preferredFont(forTextStyle: .caption1)
        streamingLabel.textColor = .secondaryLabel
        streamingLabel.translatesAutoresizingMaskIntoConstraints = false
        streamingBar.addSubview(streamingLabel)

        let stopConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        stopButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: stopConfig), for: .normal)
        stopButton.tintColor = .white
        stopButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        stopButton.layer.cornerRadius = 16
        stopButton.addTarget(self, action: #selector(stopStreamTapped), for: .touchUpInside)
        stopButton.accessibilityLabel = "Stop generating"
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        streamingBar.addSubview(stopButton)

        NSLayoutConstraint.activate([
            streamingBar.heightAnchor.constraint(equalToConstant: 40),
            streamingDot.leadingAnchor.constraint(equalTo: streamingBar.leadingAnchor, constant: 16),
            streamingDot.centerYAnchor.constraint(equalTo: streamingBar.centerYAnchor),
            streamingDot.widthAnchor.constraint(equalToConstant: 8),
            streamingDot.heightAnchor.constraint(equalToConstant: 8),
            streamingLabel.leadingAnchor.constraint(equalTo: streamingDot.trailingAnchor, constant: 8),
            streamingLabel.centerYAnchor.constraint(equalTo: streamingBar.centerYAnchor),
            stopButton.trailingAnchor.constraint(equalTo: streamingBar.trailingAnchor, constant: -16),
            stopButton.centerYAnchor.constraint(equalTo: streamingBar.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 32),
            stopButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func setupErrorBar() {
        let cornerRadius = FarmerChat.getConfig().theme?.cornerRadius ?? 12
        errorBar.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.08)
        errorBar.layer.cornerRadius = CGFloat(cornerRadius)
        errorBar.layer.borderWidth = 1
        errorBar.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
        errorBar.isHidden = true
        errorBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorBar)

        let warnConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        errorIcon.image = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: warnConfig)
        errorIcon.tintColor = .systemOrange
        errorIcon.translatesAutoresizingMaskIntoConstraints = false
        errorBar.addSubview(errorIcon)

        errorLabel.font = .preferredFont(forTextStyle: .subheadline)
        errorLabel.textColor = .label
        errorLabel.numberOfLines = 2
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorBar.addSubview(errorLabel)

        let primaryColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = primaryColor
        retryButton.layer.cornerRadius = 8
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        errorBar.addSubview(retryButton)

        NSLayoutConstraint.activate([
            errorIcon.leadingAnchor.constraint(equalTo: errorBar.leadingAnchor, constant: 12),
            errorIcon.centerYAnchor.constraint(equalTo: errorBar.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: errorIcon.trailingAnchor, constant: 12),
            errorLabel.topAnchor.constraint(equalTo: errorBar.topAnchor, constant: 12),
            errorLabel.bottomAnchor.constraint(equalTo: errorBar.bottomAnchor, constant: -12),
            retryButton.leadingAnchor.constraint(greaterThanOrEqualTo: errorLabel.trailingAnchor, constant: 8),
            retryButton.trailingAnchor.constraint(equalTo: errorBar.trailingAnchor, constant: -12),
            retryButton.centerYAnchor.constraint(equalTo: errorBar.centerYAnchor),
        ])
    }

    private func setupInputBar() {
        let config = FarmerChat.getConfig()
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.delegate = self
        inputBar.voiceEnabled = config.voiceInputEnabled
        inputBar.cameraEnabled = config.imageInputEnabled
        view.addSubview(inputBar)
    }

    private var connectivityTopConstraint: NSLayoutConstraint!
    private var starterTopToWeather: NSLayoutConstraint!
    private var tableTopToWeather: NSLayoutConstraint!

    private func setupConstraints() {
        connectivityTopConstraint = connectivityBanner.topAnchor.constraint(equalTo: topBar.bottomAnchor)
        starterTopToWeather = starterScrollView.topAnchor.constraint(equalTo: weatherCard.bottomAnchor, constant: 4)
        tableTopToWeather   = tableView.topAnchor.constraint(equalTo: weatherCard.bottomAnchor, constant: 4)

        NSLayoutConstraint.activate([
            // Top bar
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            profileButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            profileButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            historyButton.trailingAnchor.constraint(equalTo: profileButton.leadingAnchor, constant: -12),
            historyButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            // Connectivity
            connectivityTopConstraint,
            connectivityBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            connectivityBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Weather card
            weatherCard.topAnchor.constraint(equalTo: connectivityBanner.bottomAnchor, constant: 8),
            weatherCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            weatherCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            weatherCardHeightConstraint,

            // Starter area
            starterTopToWeather,
            starterScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            starterScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            starterScrollView.bottomAnchor.constraint(equalTo: streamingBar.topAnchor),

            starterStack.topAnchor.constraint(equalTo: starterScrollView.topAnchor),
            starterStack.leadingAnchor.constraint(equalTo: starterScrollView.leadingAnchor, constant: 16),
            starterStack.trailingAnchor.constraint(equalTo: starterScrollView.trailingAnchor, constant: -16),
            starterStack.bottomAnchor.constraint(equalTo: starterScrollView.bottomAnchor),
            starterStack.widthAnchor.constraint(equalTo: starterScrollView.widthAnchor, constant: -32),

            starterPromptLabel.leadingAnchor.constraint(equalTo: starterStack.leadingAnchor, constant: 16),
            starterPromptLabel.trailingAnchor.constraint(equalTo: starterStack.trailingAnchor, constant: -16),

            // Table view
            tableTopToWeather,
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: streamingBar.topAnchor),

            // Streaming bar
            streamingBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            streamingBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            streamingBar.bottomAnchor.constraint(equalTo: errorBar.topAnchor),

            // Error bar
            errorBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            errorBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            errorBar.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -4),

            // Input bar
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private var bottomConstraint: NSLayoutConstraint? {
        view.constraints.first { constraint in
            constraint.firstItem === inputBar && constraint.firstAttribute == .bottom
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        let offset = keyboardFrame.height - view.safeAreaInsets.bottom
        additionalSafeAreaInsets.bottom = offset
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        scrollToBottom(animated: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        additionalSafeAreaInsets.bottom = 0
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        viewModel.$messages
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                guard let self = self else { return }
                let hasMessages = !messages.isEmpty
                self.tableView.isHidden = !hasMessages
                self.starterScrollView.isHidden = hasMessages
                self.tableView.reloadData()
                if hasMessages {
                    // Defer scroll until after reloadData layout completes
                    DispatchQueue.main.async {
                        self.scrollToBottom(animated: true)
                    }
                }
            }
            .store(in: &cancellables)

        viewModel.$chatState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateChatStateUI(state)
            }
            .store(in: &cancellables)

        viewModel.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.connectivityBanner.isHidden = connected
                self?.updateInputEnabled()
            }
            .store(in: &cancellables)

        viewModel.$starterQuestions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] starters in
                self?.buildStarterStringChips(starters)
            }
            .store(in: &cancellables)

        viewModel.$currentScreen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] screen in
                self?.handleScreenNavigation(screen)
            }
            .store(in: &cancellables)
    }

    // MARK: - State Updates

    private func updateChatStateUI(_ state: ChatViewModel.ChatUiState) {
        switch state {
        case .idle, .complete:
            streamingBar.isHidden = true
            errorBar.isHidden = true
            stopDotAnimation()
        case .sending:
            streamingBar.isHidden = false
            errorBar.isHidden = true
            startDotAnimation()
        case .error(_, let message, let retryable):
            streamingBar.isHidden = true
            errorBar.isHidden = false
            errorLabel.text = message
            retryButton.isHidden = !retryable
            stopDotAnimation()
        }
        updateInputEnabled()
    }

    private func updateInputEnabled() {
        let isInputDisabled: Bool
        switch viewModel.chatState {
        case .sending: isInputDisabled = true
        default:       isInputDisabled = false
        }
        inputBar.isEnabled = !isInputDisabled && viewModel.isConnected
    }

    // MARK: - Dot Animation

    private func startDotAnimation() {
        dotTimer?.invalidate()
        streamingDot.alpha = 0.3
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.3) {
                self.streamingDot.alpha = self.streamingDot.alpha < 0.5 ? 1.0 : 0.3
            }
        }
    }

    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    // MARK: - Starter Chips

    private func buildStarterStringChips(_ starters: [String]) {
        starterChipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let primaryColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        let cornerRadius = FarmerChat.getConfig().theme?.cornerRadius ?? 12
        for text in starters {
            let btn = UIButton(type: .system)
            btn.setTitle(text, for: .normal)
            btn.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            btn.titleLabel?.numberOfLines = 0; btn.titleLabel?.textAlignment = .center
            btn.setTitleColor(primaryColor, for: .normal)
            btn.backgroundColor = primaryColor.withAlphaComponent(0.08)
            btn.layer.cornerRadius = CGFloat(cornerRadius)
            btn.layer.borderWidth = 1
            btn.layer.borderColor = primaryColor.withAlphaComponent(0.3).cgColor
            btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
            btn.addTarget(self, action: #selector(starterTapped(_:)), for: .touchUpInside)
            starterChipStack.addArrangedSubview(btn)
        }
    }


    // MARK: - Navigation

    private func handleScreenNavigation(_ screen: ChatViewModel.Screen) {
        switch screen {
        case .history:
            let historyVC = HistoryViewController(viewModel: viewModel)
            navigationController?.pushViewController(historyVC, animated: true)
        case .profile:
            let profileVC = ProfileViewController(viewModel: viewModel)
            navigationController?.pushViewController(profileVC, animated: true)
        case .onboarding:
            let onboardingVC = OnboardingViewController()
            navigationController?.pushViewController(onboardingVC, animated: true)
        case .chat:
            // Pop back to this VC if navigated away
            navigationController?.popToViewController(self, animated: true)
        }
    }

    // MARK: - Scroll

    private func scrollToBottom(animated: Bool) {
        guard !viewModel.messages.isEmpty else { return }
        let lastRow = viewModel.messages.count - 1
        let indexPath = IndexPath(row: lastRow, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    // MARK: - Actions

    @objc private func historyTapped() {
        viewModel.navigateTo(screen: .history)
    }

    @objc private func profileTapped() {
        viewModel.navigateTo(screen: .profile)
    }

    @objc private func stopStreamTapped() {
        viewModel.stopStream()
    }

    @objc private func retryTapped() {
        viewModel.retryLastQuery()
    }

    @objc private func starterTapped(_ sender: UIButton) {
        guard let text = sender.title(for: .normal) else { return }
        viewModel.sendQuery(text: text, inputMethod: "starter")
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = viewModel.messages[indexPath.row]

        if message.role == "user" {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: UserMessageCell.reuseIdentifier,
                for: indexPath
            ) as! UserMessageCell
            cell.configure(with: message)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: AssistantMessageCell.reuseIdentifier,
                for: indexPath
            ) as! AssistantMessageCell
            let isStreaming = false  // UIKit SDK uses non-streaming JSON responses
            cell.configure(with: message, isStreaming: isStreaming)
            cell.delegate = self
            return cell
        }
    }
}

// MARK: - InputBarViewDelegate

extension ChatViewController: InputBarViewDelegate {

    func inputBarDidSend(text: String) {
        viewModel.sendQuery(text: text)
    }

    // MARK: Camera / Gallery

    func inputBarDidTapCamera() {
        let sheet = UIAlertController(title: "Add Image", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            self?.launchCamera()
        })
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.launchPhotoLibrary()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func launchCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = self
        present(picker, animated: true)
    }

    private func launchPhotoLibrary() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func handleSelectedImage(_ image: UIImage) {
        let config  = FarmerChat.getConfig()
        let maxDim  = CGFloat(config.maxImageDimension)
        let quality = CGFloat(config.imageCompressionQuality) / 100.0
        let resized = resizeImage(image, maxDimension: maxDim)
        guard let data   = resized.jpegData(compressionQuality: quality) else { return }
        let base64 = data.base64EncodedString()
        let name   = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
        viewModel.sendQueryWithImage(base64Image: base64, imageName: name)
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return result
    }

    // MARK: Voice recording

    func inputBarDidTapVoice() {
        if isRecording {
            stopRecording()
        } else {
            requestMicPermissionAndRecord()
        }
    }

    private func requestMicPermissionAndRecord() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startRecording()
                } else {
                    self?.showMicPermissionAlert()
                }
            }
        }
    }

    private func startRecording() {
        let tmpDir = FileManager.default.temporaryDirectory
        let url    = tmpDir.appendingPathComponent("fc_recording_\(Int(Date().timeIntervalSince1970)).m4a")
        audioRecordingURL = url

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey:          44100,
                AVNumberOfChannelsKey:    1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            showRecordingOverlay()
        } catch {
            print("[FC.ChatVC] Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        dismissRecordingOverlay()

        guard let url = audioRecordingURL,
              let data = try? Data(contentsOf: url) else { return }
        audioRecordingURL = nil
        viewModel.transcribeAndSendAudio(data)
    }

    private func showRecordingOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let card = UIView()
        card.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(card)

        let micIcon = UIImageView(image: UIImage(systemName: "mic.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)))
        micIcon.tintColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        micIcon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Recording... Tap to stop"
        label.textColor = .white; label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(micIcon); card.addSubview(label)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 260),
            card.heightAnchor.constraint(equalToConstant: 160),
            micIcon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            micIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            label.topAnchor.constraint(equalTo: micIcon.bottomAnchor, constant: 16),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(recordingOverlayTapped))
        overlay.addGestureRecognizer(tap)
        view.addSubview(overlay)
        voiceOverlay = overlay
    }

    private func dismissRecordingOverlay() {
        voiceOverlay?.removeFromSuperview()
        voiceOverlay = nil
    }

    @objc private func recordingOverlayTapped() {
        stopRecording()
    }

    private func showMicPermissionAlert() {
        let alert = UIAlertController(
            title: "Microphone Access",
            message: "Please allow microphone access in Settings to use voice input.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ChatViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.handleSelectedImage(image)
                }
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            handleSelectedImage(image)
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - AssistantMessageCellDelegate

extension ChatViewController: AssistantMessageCellDelegate {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapFollowUp text: String) {
        viewModel.sendFollowUp(text: text)
    }

    func assistantMessageCell(_ cell: AssistantMessageCell, didTapFeedback rating: String) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let message = viewModel.messages[indexPath.row]
        viewModel.submitFeedback(messageId: message.id, rating: rating)
    }

    func assistantMessageCell(_ cell: AssistantMessageCell,
                               synthesiseAudioFor msgId: String,
                               text: String,
                               completion: @escaping (String?) -> Void) {
        Task {
            let url = await viewModel.synthesiseAudio(serverMessageId: msgId, text: text)
            completion(url)
        }
    }
}

// MARK: - UIFont+Traits

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
}
#endif
