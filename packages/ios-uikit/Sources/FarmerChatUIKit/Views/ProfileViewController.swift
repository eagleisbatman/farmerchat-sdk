#if canImport(UIKit)
import UIKit
import Combine

/// Profile/settings view controller for language selection and SDK branding.
internal final class ProfileViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Subviews

    private let topBar = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let sectionLabel = UILabel()
    private let tableView = UITableView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let footerStack = UIStackView()
    private let poweredByLabel = UILabel()
    private let versionLabel = UILabel()

    private var tableHeightConstraint: NSLayoutConstraint!

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
        bindViewModel()
        if viewModel.availableLanguages.isEmpty {
            viewModel.loadLanguages()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        let config = FarmerChat.getConfig()
        let themeColor = UIColor(hex: config.theme?.primaryColor ?? "#1B6B3A")

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

        titleLabel.text = "Settings"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        // Section label
        sectionLabel.text = "LANGUAGE"
        sectionLabel.font = .preferredFont(forTextStyle: .subheadline)
        sectionLabel.textColor = .secondaryLabel
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Table view
        tableView.register(LanguageCell.self, forCellReuseIdentifier: LanguageCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)

        // Loading
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Footer
        footerStack.axis = .vertical
        footerStack.alignment = .center
        footerStack.spacing = 8
        footerStack.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        poweredByLabel.text = config.showPoweredBy ? "Powered by FarmerChat" : nil
        poweredByLabel.font = .preferredFont(forTextStyle: .caption1)
        poweredByLabel.textColor = .tertiaryLabel
        poweredByLabel.isHidden = !config.showPoweredBy

        versionLabel.text = "SDK v0.0.0"
        versionLabel.font = .preferredFont(forTextStyle: .caption2)
        versionLabel.textColor = .quaternaryLabel

        footerStack.addArrangedSubview(separator)
        footerStack.addArrangedSubview(poweredByLabel)
        footerStack.addArrangedSubview(versionLabel)

        // Content stack in scroll view
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(sectionLabel)
        contentStack.setCustomSpacing(12, after: sectionLabel)
        contentStack.addArrangedSubview(loadingIndicator)
        contentStack.addArrangedSubview(tableView)
        contentStack.setCustomSpacing(32, after: tableView)
        contentStack.addArrangedSubview(footerStack)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 48),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            separator.leadingAnchor.constraint(equalTo: footerStack.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: footerStack.trailingAnchor),

            tableHeightConstraint,
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.$availableLanguages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] languages in
                guard let self = self else { return }
                let hasLanguages = !languages.isEmpty
                self.tableView.isHidden = !hasLanguages
                self.loadingIndicator.isHidden = hasLanguages
                if hasLanguages { self.loadingIndicator.stopAnimating() }
                else { self.loadingIndicator.startAnimating() }
                self.tableView.reloadData()
                self.updateTableHeight()
            }
            .store(in: &cancellables)

        viewModel.$selectedLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func updateTableHeight() {
        // Each row is ~60pts
        let rowHeight: CGFloat = 64
        let count = CGFloat(viewModel.availableLanguages.count)
        tableHeightConstraint.constant = rowHeight * count
    }

    // MARK: - Actions

    @objc private func backTapped() {
        viewModel.navigateTo(screen: .chat)
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.availableLanguages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LanguageCell.reuseIdentifier,
            for: indexPath
        ) as! LanguageCell
        let language = viewModel.availableLanguages[indexPath.row]
        let themeColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        cell.configure(
            language: language,
            isSelected: viewModel.selectedLanguage == language.code,
            themeColor: themeColor
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let code = viewModel.availableLanguages[indexPath.row].code
        viewModel.setLanguage(code: code)
    }
}
#endif
