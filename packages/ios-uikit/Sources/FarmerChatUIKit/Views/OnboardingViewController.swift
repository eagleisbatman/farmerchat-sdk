#if canImport(UIKit)
import UIKit
import Combine

/// Two-step onboarding:
///   Step 1 — Shows the IP-geolocation region detected by `initialize_user` (no GPS permission).
///   Step 2 — Language selection.
///
/// On completion saves language to `SdkPreferences`, marks onboarding done, and pushes `ChatViewController`.
internal final class OnboardingViewController: UIViewController {

    // MARK: - Properties

    private let ownViewModel = ChatViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var step = 1
    private var selectedLanguageCode = ""

    // MARK: - Subviews

    private let progressBar1 = UIView()
    private let progressBar2 = UIView()
    private let containerView = UIView()

    // Step 1 — Region
    private let regionIcon         = UIImageView()
    private let regionTitle        = UILabel()
    private let regionDescription  = UILabel()
    private let regionChip         = UILabel()
    private let continueButton     = UIButton(type: .system)

    // Step 2 — Language
    private let langIcon           = UIImageView()
    private let langTitle          = UILabel()
    private let langDescription    = UILabel()
    private let langTableView      = UITableView()
    private let loadingIndicator   = UIActivityIndicatorView(style: .medium)
    private let getStartedButton   = UIButton(type: .system)

    // MARK: - Init

    init() { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.12, alpha: 1)
        setupUI()
        bindViewModel()
        ownViewModel.loadLanguages()
        showStep(1)
    }

    // MARK: - Setup

    private func setupUI() {
        let theme = FarmerChat.getConfig().theme
        let primary = UIColor(hex: theme?.primaryColor ?? "#1B6B3A")
        let radius  = CGFloat(theme?.cornerRadius ?? 12)

        for bar in [progressBar1, progressBar2] {
            bar.layer.cornerRadius = 2; bar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(bar)
        }
        progressBar1.backgroundColor = primary
        progressBar2.backgroundColor = UIColor.white.withAlphaComponent(0.2)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        setupRegionStep(primary: primary, radius: radius)
        setupLanguageStep(primary: primary, radius: radius)

        NSLayoutConstraint.activate([
            progressBar1.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            progressBar1.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            progressBar1.heightAnchor.constraint(equalToConstant: 4),
            progressBar2.topAnchor.constraint(equalTo: progressBar1.topAnchor),
            progressBar2.leadingAnchor.constraint(equalTo: progressBar1.trailingAnchor, constant: 8),
            progressBar2.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            progressBar2.heightAnchor.constraint(equalToConstant: 4),
            progressBar1.widthAnchor.constraint(equalTo: progressBar2.widthAnchor),
            containerView.topAnchor.constraint(equalTo: progressBar1.bottomAnchor, constant: 24),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func setupRegionStep(primary: UIColor, radius: CGFloat) {
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 72)
        regionIcon.image = UIImage(systemName: "mappin.circle.fill", withConfiguration: iconCfg)
        regionIcon.tintColor = primary
        regionIcon.translatesAutoresizingMaskIntoConstraints = false

        regionTitle.text = "Your Region"
        regionTitle.font = .boldSystemFont(ofSize: 24)
        regionTitle.textColor = .white; regionTitle.textAlignment = .center
        regionTitle.translatesAutoresizingMaskIntoConstraints = false

        regionDescription.text = "We detected your region based on your network. This helps us provide relevant agricultural advice."
        regionDescription.font = .systemFont(ofSize: 15); regionDescription.textColor = UIColor.white.withAlphaComponent(0.7)
        regionDescription.textAlignment = .center; regionDescription.numberOfLines = 0
        regionDescription.translatesAutoresizingMaskIntoConstraints = false

        regionChip.text = "Detecting region..."
        regionChip.font = .systemFont(ofSize: 14, weight: .medium)
        regionChip.textColor = .white
        regionChip.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        regionChip.layer.cornerRadius = 12; regionChip.layer.masksToBounds = true
        regionChip.textAlignment = .center
        regionChip.translatesAutoresizingMaskIntoConstraints = false

        continueButton.setTitle("Continue →", for: .normal)
        continueButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = primary; continueButton.layer.cornerRadius = radius
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false

        // Populate chip with TokenStore data (async)
        Task { [weak self] in
            let country = await TokenStore.shared.country
            let state   = await TokenStore.shared.state
            await MainActor.run {
                let text = [state, country].filter { !$0.isEmpty }.joined(separator: ", ")
                self?.regionChip.text = text.isEmpty ? "📍 Region detected" : "📍 \(text)"
            }
        }
    }

    private func setupLanguageStep(primary: UIColor, radius: CGFloat) {
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 48)
        langIcon.image = UIImage(systemName: "globe", withConfiguration: iconCfg)
        langIcon.tintColor = primary; langIcon.translatesAutoresizingMaskIntoConstraints = false

        langTitle.text = "Choose Your Language"
        langTitle.font = .boldSystemFont(ofSize: 22); langTitle.textColor = .white
        langTitle.textAlignment = .center; langTitle.translatesAutoresizingMaskIntoConstraints = false

        langDescription.text = "Select the language you'd like to use for your farming conversations."
        langDescription.font = .systemFont(ofSize: 15); langDescription.textColor = UIColor.white.withAlphaComponent(0.7)
        langDescription.textAlignment = .center; langDescription.numberOfLines = 0
        langDescription.translatesAutoresizingMaskIntoConstraints = false

        langTableView.register(LanguageCell.self, forCellReuseIdentifier: LanguageCell.reuseIdentifier)
        langTableView.dataSource = self; langTableView.delegate = self
        langTableView.separatorStyle = .none; langTableView.backgroundColor = .clear
        langTableView.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicator.hidesWhenStopped = true; loadingIndicator.color = primary
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        getStartedButton.setTitleColor(.white, for: .normal)
        getStartedButton.backgroundColor = primary; getStartedButton.layer.cornerRadius = radius
        getStartedButton.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Show steps

    private func showStep(_ n: Int) {
        self.step = n
        containerView.subviews.forEach { $0.removeFromSuperview() }
        let primary = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        progressBar2.backgroundColor = n >= 2 ? primary : UIColor.white.withAlphaComponent(0.2)
        if n == 1 { showRegionStep() } else { showLanguageStep() }
    }

    private func showRegionStep() {
        [regionIcon, regionTitle, regionDescription, regionChip, continueButton].forEach {
            containerView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            regionIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 60),
            regionIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            regionTitle.topAnchor.constraint(equalTo: regionIcon.bottomAnchor, constant: 24),
            regionTitle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            regionDescription.topAnchor.constraint(equalTo: regionTitle.bottomAnchor, constant: 16),
            regionDescription.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            regionDescription.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            regionChip.topAnchor.constraint(equalTo: regionDescription.bottomAnchor, constant: 24),
            regionChip.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            regionChip.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            regionChip.heightAnchor.constraint(equalToConstant: 36),
            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func showLanguageStep() {
        [langIcon, langTitle, langDescription, langTableView, loadingIndicator, getStartedButton].forEach {
            containerView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            langIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            langIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            langTitle.topAnchor.constraint(equalTo: langIcon.bottomAnchor, constant: 16),
            langTitle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            langDescription.topAnchor.constraint(equalTo: langTitle.bottomAnchor, constant: 12),
            langDescription.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            langDescription.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            langTableView.topAnchor.constraint(equalTo: langDescription.bottomAnchor, constant: 16),
            langTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            langTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            langTableView.bottomAnchor.constraint(equalTo: getStartedButton.topAnchor, constant: -16),
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            getStartedButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            getStartedButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            getStartedButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            getStartedButton.heightAnchor.constraint(equalToConstant: 52),
        ])
        let hasLangs = !ownViewModel.availableLanguages.isEmpty
        langTableView.isHidden = !hasLangs
        loadingIndicator.isHidden = hasLangs
        if !hasLangs { loadingIndicator.startAnimating() }
        langTableView.reloadData()
    }

    // MARK: - Binding

    private func bindViewModel() {
        ownViewModel.$availableLanguages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] langs in
                guard let self, self.step == 2 else { return }
                let has = !langs.isEmpty
                self.langTableView.isHidden = !has
                self.loadingIndicator.isHidden = has
                if has { self.loadingIndicator.stopAnimating() }
                self.langTableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func continueTapped() { showStep(2) }

    @objc private func getStartedTapped() {
        let lang = selectedLanguageCode.isEmpty ? (ownViewModel.availableLanguages.first?.code ?? "en") : selectedLanguageCode
        // Persist and mark done
        SdkPreferences.selectedLanguage   = lang
        SdkPreferences.isOnboardingDone   = true
        // Replace onboarding with chat in the nav stack
        let chatVC = ChatViewController()
        var stack  = navigationController?.viewControllers ?? []
        stack.removeLast()
        stack.append(chatVC)
        navigationController?.setViewControllers(stack, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension OnboardingViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        ownViewModel.availableLanguages.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LanguageCell.reuseIdentifier, for: indexPath) as! LanguageCell
        let lang     = ownViewModel.availableLanguages[indexPath.row]
        let selected = selectedLanguageCode.isEmpty ? ownViewModel.selectedLanguage : selectedLanguageCode
        cell.configure(language: lang, isSelected: selected == lang.code,
                        themeColor: UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A"))
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedLanguageCode = ownViewModel.availableLanguages[indexPath.row].code
        tableView.reloadData()
    }
}
#endif
