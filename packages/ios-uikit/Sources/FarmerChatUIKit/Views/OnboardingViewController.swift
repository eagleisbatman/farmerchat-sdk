#if canImport(UIKit)
import UIKit
import CoreLocation
import Combine

/// Onboarding view controller with two steps: location permission and language selection.
internal final class OnboardingViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()
    private var step = 1
    private var selectedLanguageCode = ""

    // Location
    private let locationManager = CLLocationManager()
    private var latitude: Double = 0.0
    private var longitude: Double = 0.0
    private var locationObtained = false
    private var locationDenied = false

    // MARK: - Subviews

    private let progressBar1 = UIView()
    private let progressBar2 = UIView()
    private let containerView = UIView()

    // Location step views
    private let locationIcon = UIImageView()
    private let locationTitle = UILabel()
    private let locationDescription = UILabel()
    private let locationDeniedLabel = UILabel()
    private let shareLocationButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let locationObtainedLabel = UILabel()
    private let continueButton = UIButton(type: .system)

    // Language step views
    private let langIcon = UIImageView()
    private let langTitle = UILabel()
    private let langDescription = UILabel()
    private let langTableView = UITableView()
    private let getStartedButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

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
        view.backgroundColor = .systemBackground
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        setupUI()
        bindViewModel()
        viewModel.loadLanguages()
        showStep(1)
    }

    // MARK: - Setup

    private func setupUI() {
        let themeColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        let cornerRadius = CGFloat(FarmerChat.getConfig().theme?.cornerRadius ?? 12)

        // Progress bars
        for bar in [progressBar1, progressBar2] {
            bar.layer.cornerRadius = 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(bar)
        }
        progressBar1.backgroundColor = themeColor
        progressBar2.backgroundColor = UIColor.systemGray4

        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Location step
        setupLocationStep(themeColor: themeColor, cornerRadius: cornerRadius)

        // Language step
        setupLanguageStep(themeColor: themeColor, cornerRadius: cornerRadius)

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

    private func setupLocationStep(themeColor: UIColor, cornerRadius: CGFloat) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 72, weight: .regular)
        locationIcon.image = UIImage(systemName: "location.circle.fill", withConfiguration: iconConfig)
        locationIcon.tintColor = themeColor
        locationIcon.translatesAutoresizingMaskIntoConstraints = false

        locationTitle.text = "Share Your Location"
        locationTitle.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        locationTitle.textAlignment = .center
        locationTitle.translatesAutoresizingMaskIntoConstraints = false

        locationDescription.text = "Your location helps us provide accurate, region-specific agricultural advice for your area."
        locationDescription.font = .preferredFont(forTextStyle: .body)
        locationDescription.textColor = .secondaryLabel
        locationDescription.textAlignment = .center
        locationDescription.numberOfLines = 0
        locationDescription.translatesAutoresizingMaskIntoConstraints = false

        locationDeniedLabel.text = "Location access was denied. You can change this in Settings."
        locationDeniedLabel.font = .preferredFont(forTextStyle: .caption1)
        locationDeniedLabel.textColor = .secondaryLabel
        locationDeniedLabel.textAlignment = .center
        locationDeniedLabel.numberOfLines = 0
        locationDeniedLabel.isHidden = true
        locationDeniedLabel.translatesAutoresizingMaskIntoConstraints = false

        shareLocationButton.setTitle("  Share Location", for: .normal)
        shareLocationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        shareLocationButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        shareLocationButton.tintColor = .white
        shareLocationButton.setTitleColor(.white, for: .normal)
        shareLocationButton.backgroundColor = themeColor
        shareLocationButton.layer.cornerRadius = cornerRadius
        shareLocationButton.addTarget(self, action: #selector(shareLocationTapped), for: .touchUpInside)
        shareLocationButton.translatesAutoresizingMaskIntoConstraints = false

        skipButton.setTitle("Skip for now", for: .normal)
        skipButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        skipButton.setTitleColor(.secondaryLabel, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false

        locationObtainedLabel.text = "\u{2705} Location shared"
        locationObtainedLabel.font = .preferredFont(forTextStyle: .subheadline)
        locationObtainedLabel.textColor = .secondaryLabel
        locationObtainedLabel.textAlignment = .center
        locationObtainedLabel.isHidden = true
        locationObtainedLabel.translatesAutoresizingMaskIntoConstraints = false

        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = themeColor
        continueButton.layer.cornerRadius = cornerRadius
        continueButton.isHidden = true
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupLanguageStep(themeColor: UIColor, cornerRadius: CGFloat) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        langIcon.image = UIImage(systemName: "globe", withConfiguration: iconConfig)
        langIcon.tintColor = themeColor
        langIcon.translatesAutoresizingMaskIntoConstraints = false

        langTitle.text = "Choose Your Language"
        langTitle.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        langTitle.textAlignment = .center
        langTitle.translatesAutoresizingMaskIntoConstraints = false

        langDescription.text = "Select the language you'd like to use for your farming conversations."
        langDescription.font = .preferredFont(forTextStyle: .body)
        langDescription.textColor = .secondaryLabel
        langDescription.textAlignment = .center
        langDescription.numberOfLines = 0
        langDescription.translatesAutoresizingMaskIntoConstraints = false

        langTableView.register(LanguageCell.self, forCellReuseIdentifier: LanguageCell.reuseIdentifier)
        langTableView.dataSource = self
        langTableView.delegate = self
        langTableView.separatorStyle = .none
        langTableView.backgroundColor = .clear
        langTableView.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        getStartedButton.setTitleColor(.white, for: .normal)
        getStartedButton.backgroundColor = themeColor
        getStartedButton.layer.cornerRadius = cornerRadius
        getStartedButton.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Show Steps

    private func showStep(_ step: Int) {
        self.step = step
        containerView.subviews.forEach { $0.removeFromSuperview() }

        let themeColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        progressBar2.backgroundColor = step >= 2 ? themeColor : UIColor.systemGray4

        if step == 1 {
            showLocationStep()
        } else {
            showLanguageStep()
        }
    }

    private func showLocationStep() {
        let views: [UIView] = [locationIcon, locationTitle, locationDescription, locationDeniedLabel,
                                shareLocationButton, skipButton, locationObtainedLabel, continueButton]
        views.forEach {
            containerView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            locationIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 60),
            locationIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            locationTitle.topAnchor.constraint(equalTo: locationIcon.bottomAnchor, constant: 24),
            locationTitle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            locationDescription.topAnchor.constraint(equalTo: locationTitle.bottomAnchor, constant: 16),
            locationDescription.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            locationDescription.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),

            locationDeniedLabel.topAnchor.constraint(equalTo: locationDescription.bottomAnchor, constant: 16),
            locationDeniedLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            locationDeniedLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),

            shareLocationButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -12),
            shareLocationButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            shareLocationButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            shareLocationButton.heightAnchor.constraint(equalToConstant: 52),

            skipButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            skipButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            locationObtainedLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            locationObtainedLabel.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -12),

            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        updateLocationUI()
    }

    private func showLanguageStep() {
        let views: [UIView] = [langIcon, langTitle, langDescription, langTableView,
                                loadingIndicator, getStartedButton]
        views.forEach {
            containerView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            langIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            langIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            langTitle.topAnchor.constraint(equalTo: langIcon.bottomAnchor, constant: 16),
            langTitle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            langDescription.topAnchor.constraint(equalTo: langTitle.bottomAnchor, constant: 16),
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

        langTableView.reloadData()
        let hasLanguages = !viewModel.availableLanguages.isEmpty
        langTableView.isHidden = !hasLanguages
        loadingIndicator.isHidden = hasLanguages
        if !hasLanguages { loadingIndicator.startAnimating() }
    }

    private func updateLocationUI() {
        if locationObtained {
            shareLocationButton.isHidden = true
            skipButton.isHidden = true
            locationObtainedLabel.isHidden = false
            continueButton.isHidden = false
        } else {
            shareLocationButton.isHidden = false
            skipButton.isHidden = false
            locationObtainedLabel.isHidden = true
            continueButton.isHidden = true
        }
        locationDeniedLabel.isHidden = !locationDenied
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.$availableLanguages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] languages in
                guard let self = self, self.step == 2 else { return }
                let hasLanguages = !languages.isEmpty
                self.langTableView.isHidden = !hasLanguages
                self.loadingIndicator.isHidden = hasLanguages
                if hasLanguages { self.loadingIndicator.stopAnimating() }
                self.langTableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func shareLocationTapped() {
        locationManager.requestWhenInUseAuthorization()
    }

    @objc private func skipTapped() {
        showStep(2)
    }

    @objc private func continueTapped() {
        showStep(2)
    }

    @objc private func getStartedTapped() {
        let language = selectedLanguageCode.isEmpty ? viewModel.selectedLanguage : selectedLanguageCode
        viewModel.completeOnboarding(lat: latitude, lng: longitude, language: language)
    }
}

// MARK: - CLLocationManagerDelegate

extension OnboardingViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        locationObtained = true
        updateLocationUI()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[FC.Onboarding] Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationObtained = false
            manager.requestLocation()
        case .denied, .restricted:
            locationDenied = true
            updateLocationUI()
        default:
            break
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension OnboardingViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.availableLanguages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LanguageCell.reuseIdentifier,
            for: indexPath
        ) as! LanguageCell
        let language = viewModel.availableLanguages[indexPath.row]
        let resolvedSelection = selectedLanguageCode.isEmpty ? viewModel.selectedLanguage : selectedLanguageCode
        let themeColor = UIColor(hex: FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
        cell.configure(language: language, isSelected: resolvedSelection == language.code, themeColor: themeColor)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedLanguageCode = viewModel.availableLanguages[indexPath.row].code
        tableView.reloadData()
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
