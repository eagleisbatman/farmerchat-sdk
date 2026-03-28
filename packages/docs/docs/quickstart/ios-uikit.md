---
sidebar_position: 4
title: iOS (UIKit)
---

# iOS (UIKit)

Integrate FarmerChat into your iOS app using UIKit.

## Prerequisites

- Xcode 16 or later
- Swift 5.9+
- iOS 15.0+ deployment target
- Swift Package Manager

## Installation

### Swift Package Manager

Add the FarmerChat UIKit package to your project:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/digitalgreenorg/farmerchat-ios-uikit.git
   ```
3. Set the version rule to **Up to Next Major Version** from `1.0.0`
4. Click **Add Package**

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/digitalgreenorg/farmerchat-ios-uikit.git",
        from: "1.0.0"
    )
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["FarmerChatUIKit"]
)
```

## Configuration

Initialize the SDK in your `AppDelegate`:

```swift
import UIKit
import FarmerChatUIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FarmerChat.shared.initialize(config: FarmerChatConfig(
            apiKey: "fc_pub_your_api_key"
        ))
        return true
    }
}
```

You can customize appearance and behavior via `FarmerChatConfig`:

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    theme: ThemeConfig(
        primaryColor: "#1B6B3A",
        secondaryColor: "#F0F7F2",
        cornerRadius: 16
    ),
    headerTitle: "Crop Advisor",
    defaultLanguage: "hi",
    voiceInputEnabled: true,
    imageInputEnabled: true
))
```

See [Configuration Options](#configuration-options) below for the full list.

## Basic Usage

### Add the FAB Programmatically

Add the floating action button to your view controller:

```swift
import UIKit
import FarmerChatUIKit

class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let fab = FarmerChat.shared.fabView { [weak self] in
            let chatNav = FarmerChat.shared.chatViewController()
            self?.present(chatNav, animated: true)
        }

        view.addSubview(fab)
        fab.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fab.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            fab.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            fab.widthAnchor.constraint(equalToConstant: 56),
            fab.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
}
```

### Using FarmerChatFAB Directly

You can also use the `FarmerChatFAB` class (a `UIButton` subclass) directly:

```swift
let fab = FarmerChatFAB()
fab.tapAction = { [weak self] in
    let chatNav = FarmerChat.shared.chatViewController()
    self?.present(chatNav, animated: true)
}

view.addSubview(fab)
fab.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    fab.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
    fab.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
])
```

The `FarmerChatFAB` has an intrinsic content size of 56x56 points, so width and height constraints are optional.

### Presenting the Chat

The `chatViewController()` method returns a `UINavigationController` with the chat UI as its root. You can present it modally or push it onto your own navigation stack:

```swift
// Modal presentation (default)
let chatNav = FarmerChat.shared.chatViewController()
present(chatNav, animated: true)

// Or push onto your navigation stack
let chatNav = FarmerChat.shared.chatViewController()
if let chatVC = chatNav.viewControllers.first {
    navigationController?.pushViewController(chatVC, animated: true)
}
```

## Event Listening

Listen to SDK lifecycle events by passing an `onEvent` callback in your config:

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    onEvent: { event in
        switch event {
        case .chatOpened(let sessionId, _):
            Analytics.track("farmerchat_opened", sessionId: sessionId)
        case .querySent(_, _, let inputMethod, _):
            Analytics.track("farmerchat_query", method: inputMethod)
        case .error(let code, let message, let fatal, _):
            print("FarmerChat error [\(code)]: \(message), fatal: \(fatal)")
        default:
            break
        }
    }
))
```

## Full Example

```swift
// AppDelegate.swift
import UIKit
import FarmerChatUIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FarmerChat.shared.initialize(config: FarmerChatConfig(
            apiKey: "fc_pub_your_api_key",
            theme: ThemeConfig(primaryColor: "#1B6B3A"),
            headerTitle: "Farm Advisor",
            defaultLanguage: "en",
            onEvent: { event in
                if case .error(let code, let message, _, _) = event {
                    print("SDK error [\(code)]: \(message)")
                }
            }
        ))

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(
            rootViewController: HomeViewController()
        )
        window?.makeKeyAndVisible()
        return true
    }
}

// HomeViewController.swift
import UIKit
import FarmerChatUIKit

class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Farming App"
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Welcome"
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        let fab = FarmerChat.shared.fabView { [weak self] in
            let chatNav = FarmerChat.shared.chatViewController()
            self?.present(chatNav, animated: true)
        }
        view.addSubview(fab)
        fab.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fab.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16
            ),
            fab.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16
            ),
            fab.widthAnchor.constraint(equalToConstant: 56),
            fab.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
}
```

## Objective-C Interop

The UIKit SDK includes an Objective-C bridging layer for legacy codebases. If your app is written in Objective-C, you can still use FarmerChat -- contact Digital Green for Objective-C integration guidance.

## Cleanup

When you need to release SDK resources:

```swift
FarmerChat.shared.destroy()
```

After calling `destroy()`, you can re-initialize the SDK by calling `FarmerChat.shared.initialize(config:)` again.

## Configuration Options

The `FarmerChatConfig` and `ThemeConfig` for the UIKit SDK are identical to the SwiftUI SDK. See the [iOS SwiftUI configuration table](./ios-swiftui#configuration-options) for the full list.
