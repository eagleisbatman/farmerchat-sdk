#if canImport(UIKit)
import UIKit
import Combine

/// Chat history view controller (data fetched from server).
///
/// Displays a list of past conversations. Tapping a conversation loads its messages
/// into the chat and navigates back.
internal final class HistoryViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()
    private var conversations: [ConversationResponse] = []
    private var isLoading = true
    private var errorMessage: String?

    // MARK: - Subviews

    private let topBar = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let emptyView = UIView()
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    // MARK: - Init

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        setupUI()
        fetchHistory()
    }

    // MARK: - Setup

    private func setupUI() {
        let themeColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")

        // Top bar
        topBar.backgroundColor = themeColor
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: iconConfig), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.accessibilityLabel = "Back to chat"
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(backButton)

        titleLabel.text = "Chat History"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)

        // Table view
        tableView.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Loading
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        // Empty
        setupEmptyView()

        // Error
        setupErrorView(themeColor: themeColor)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 48),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        updateViewState()
    }

    private func setupEmptyView() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        let emptyIcon = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right", withConfiguration: iconConfig))
        emptyIcon.tintColor = UIColor.systemGray3

        let label1 = UILabel()
        label1.text = "No conversations yet"
        label1.font = .preferredFont(forTextStyle: .body)
        label1.textColor = .secondaryLabel

        let label2 = UILabel()
        label2.text = "Start chatting to see your history here."
        label2.font = .preferredFont(forTextStyle: .caption1)
        label2.textColor = .tertiaryLabel

        stack.addArrangedSubview(emptyIcon)
        stack.addArrangedSubview(label1)
        stack.addArrangedSubview(label2)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: emptyView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),
        ])
    }

    private func setupErrorView(themeColor: UIColor) {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.isHidden = true
        view.addSubview(errorView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        let errIcon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle", withConfiguration: iconConfig))
        errIcon.tintColor = .systemOrange

        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0

        retryButton.setTitle("Try Again", for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = themeColor
        retryButton.layer.cornerRadius = 8
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        stack.addArrangedSubview(errIcon)
        stack.addArrangedSubview(errorLabel)
        stack.addArrangedSubview(retryButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: errorView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: errorView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor),
        ])
    }

    // MARK: - State

    private func updateViewState() {
        tableView.isHidden = isLoading || errorMessage != nil || conversations.isEmpty
        loadingIndicator.isHidden = !isLoading
        if isLoading { loadingIndicator.startAnimating() } else { loadingIndicator.stopAnimating() }
        emptyView.isHidden = isLoading || errorMessage != nil || !conversations.isEmpty
        errorView.isHidden = isLoading || errorMessage == nil
        if let error = errorMessage {
            errorLabel.text = error
        }
    }

    // MARK: - Data

    private func fetchHistory() {
        isLoading = true
        errorMessage = nil
        updateViewState()

        Task {
            do {
                guard let client = FarmerChat.shared.apiClient else {
                    await MainActor.run {
                        self.errorMessage = "SDK not initialized"
                        self.isLoading = false
                        self.updateViewState()
                    }
                    return
                }

                let result = try await client.getHistory()
                await MainActor.run {
                    self.conversations = result
                    self.isLoading = false
                    self.updateViewState()
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load history. Please check your connection."
                    self.isLoading = false
                    self.updateViewState()
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        viewModel.navigateTo(screen: .chat)
        navigationController?.popViewController(animated: true)
    }

    @objc private func retryTapped() {
        fetchHistory()
    }
}

// MARK: - UITableViewDataSource & Delegate

extension HistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConversationCell.reuseIdentifier,
            for: indexPath
        ) as! ConversationCell
        cell.configure(with: conversations[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.loadHistory()
        viewModel.navigateTo(screen: .chat)
        navigationController?.popViewController(animated: true)
    }
}
#endif
