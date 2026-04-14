#if canImport(UIKit)
import UIKit
import Combine

/// Chat history screen.
/// Fetches the conversation list, shows search, pull-to-refresh,
/// and on row tap loads the selected conversation into ChatViewModel before navigating back.
internal final class HistoryViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()
    private var allConversations: [ConversationListItem] = []
    private var filtered: [ConversationListItem] = []
    private var isLoading = true
    private var errorMessage: String?

    // MARK: - Subviews

    private let topBar    = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let newConvButton = UIButton(type: .system)

    private let searchField = UITextField()
    private let searchContainer = UIView()

    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let emptyView  = UIView()
    private let errorView  = UIView()
    private let errorLabel = UILabel()

    // MARK: - Init

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.12, alpha: 1)
        setupUI()
        observeViewModel()
        viewModel.loadConversationList()
    }

    // MARK: - Setup

    private func setupUI() {
        let themeColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")

        // Top bar
        topBar.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: iconCfg), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(backButton)

        titleLabel.text = "Chat History"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.text = "Your farming conversations"
        subLabel.font = .systemFont(ofSize: 12)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(subLabel)

        newConvButton.setImage(UIImage(systemName: "plus", withConfiguration: iconCfg), for: .normal)
        newConvButton.tintColor = .white
        newConvButton.addTarget(self, action: #selector(newConversationTapped), for: .touchUpInside)
        newConvButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(newConvButton)

        // Search
        searchContainer.backgroundColor = UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)
        searchContainer.layer.cornerRadius = 12
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = UIColor.white.withAlphaComponent(0.5)
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchIcon)

        searchField.placeholder = "Search conversations..."
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search conversations...",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        )
        searchField.textColor = .white
        searchField.font = .systemFont(ofSize: 15)
        searchField.returnKeyType = .search
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)

        // Table
        tableView.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Pull-to-refresh
        refreshControl.tintColor = themeColor
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl

        // Loading
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = themeColor
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        setupEmptyView()
        setupErrorView(themeColor: themeColor)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 64),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 4),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            titleLabel.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 14),

            subLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            newConvButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            newConvButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            newConvButton.widthAnchor.constraint(equalToConstant: 38),
            newConvButton.heightAnchor.constraint(equalToConstant: 38),

            searchContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
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
    }

    private func setupEmptyView() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        let stack = UIStackView()
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)

        let icon = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)))
        icon.tintColor = UIColor.white.withAlphaComponent(0.3)

        let l1 = UILabel(); l1.text = "No conversations yet"
        l1.font = .boldSystemFont(ofSize: 18); l1.textColor = UIColor.white.withAlphaComponent(0.9)

        let l2 = UILabel(); l2.text = "Your past conversations will appear here"
        l2.font = .systemFont(ofSize: 14); l2.textColor = UIColor.white.withAlphaComponent(0.5)
        l2.textAlignment = .center; l2.numberOfLines = 0

        [icon, l1, l2].forEach { stack.addArrangedSubview($0) }
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
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40)))
        icon.tintColor = .systemOrange

        errorLabel.font = .systemFont(ofSize: 14); errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center; errorLabel.numberOfLines = 0

        let retry = UIButton(type: .system)
        retry.setTitle("Try Again", for: .normal)
        retry.setTitleColor(.white, for: .normal)
        retry.backgroundColor = themeColor
        retry.layer.cornerRadius = 8
        retry.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        [icon, errorLabel, retry].forEach { stack.addArrangedSubview($0) }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: errorView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: errorView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor),
        ])
    }

    // MARK: - Observe ViewModel

    private func observeViewModel() {
        viewModel.$conversationList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self else { return }
                self.allConversations = list
                self.applyFilter()
                self.isLoading = false
                self.errorMessage = nil
                self.refreshControl.endRefreshing()
                self.updateViewState()
                self.tableView.reloadData()
            }
            .store(in: &cancellables)

        // Navigation back to chat is handled by ChatViewController.handleScreenNavigation(.chat)
        // via viewModel.navigateTo(.chat) — no duplicate pop needed here.
    }

    // MARK: - State

    private func updateViewState() {
        tableView.isHidden      = isLoading || errorMessage != nil || filtered.isEmpty
        loadingIndicator.isHidden = !isLoading
        if isLoading { loadingIndicator.startAnimating() } else { loadingIndicator.stopAnimating() }
        emptyView.isHidden  = isLoading || errorMessage != nil || !filtered.isEmpty
        errorView.isHidden  = isLoading || errorMessage == nil
        if let err = errorMessage { errorLabel.text = err }
    }

    private func applyFilter() {
        let q = searchField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if q.isEmpty {
            filtered = allConversations
        } else {
            filtered = allConversations.filter {
                ($0.conversationTitle ?? "").localizedCaseInsensitiveContains(q)
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        // Route through ViewModel so ChatViewController.handleScreenNavigation pops
        // all child VCs correctly via popToViewController(self) — handles stacked case.
        viewModel.navigateTo(screen: .chat)
    }

    @objc private func newConversationTapped() {
        viewModel.startNewConversation()
        viewModel.navigateTo(screen: .chat)
    }

    @objc private func searchChanged() {
        applyFilter()
        tableView.reloadData()
        updateViewState()
    }

    @objc private func refreshPulled() {
        viewModel.loadConversationList()
    }

    @objc private func retryTapped() {
        isLoading = true; errorMessage = nil
        updateViewState()
        viewModel.loadConversationList()
    }
}

// MARK: - UITableViewDataSource & Delegate

extension HistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConversationCell.reuseIdentifier, for: indexPath
        ) as! ConversationCell
        cell.configureWithListItem(filtered[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Load the selected conversation's messages — navigation happens via $currentScreen observer
        viewModel.loadConversation(filtered[indexPath.row])
    }
}
#endif
