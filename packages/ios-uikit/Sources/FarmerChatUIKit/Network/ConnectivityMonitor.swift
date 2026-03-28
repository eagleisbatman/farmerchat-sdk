import Foundation
import Network
import Combine

/// Monitors network connectivity using `NWPathMonitor`.
///
/// Publishes `isConnected` as a `@Published` property so UIKit view controllers
/// can react to connectivity changes via Combine subscribers.
///
/// This class is `@MainActor`-isolated — all property access and state mutations
/// happen on the main thread, matching its consumers (UIKit view controllers).
///
/// **Note:** This class is single-use. After ``stop()`` is called, the underlying
/// `NWPathMonitor` is cancelled and cannot be restarted. Create a new instance
/// if you need to monitor again.
///
/// Usage:
/// ```swift
/// let monitor = ConnectivityMonitor()
/// monitor.start()
/// // observe monitor.$isConnected
/// // ...
/// monitor.stop()
/// ```
@MainActor
internal final class ConnectivityMonitor: ObservableObject {

    /// Whether the device currently has a usable network path.
    @Published private(set) var isConnected: Bool = true

    /// The underlying NWPathMonitor instance.
    private var monitor: NWPathMonitor?

    /// Dedicated serial queue for NWPathMonitor callbacks.
    private let queue = DispatchQueue(
        label: "org.digitalgreen.farmerchat.connectivity",
        qos: .utility
    )

    /// Whether monitoring has been started.
    private var isMonitoring = false

    /// Begin monitoring network connectivity.
    ///
    /// Updates `isConnected` on the main thread whenever the network path status changes.
    /// Safe to call multiple times -- subsequent calls are no-ops.
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let newMonitor = NWPathMonitor()
        self.monitor = newMonitor

        newMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.isConnected != connected {
                    self.isConnected = connected
                }
            }
        }

        newMonitor.start(queue: queue)
    }

    /// Stop monitoring network connectivity.
    ///
    /// After calling this, the monitor is cancelled. Call ``start()`` to create
    /// a fresh monitor and resume monitoring.
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor?.cancel()
        monitor = nil
    }

    deinit {
        monitor?.cancel()
    }
}
