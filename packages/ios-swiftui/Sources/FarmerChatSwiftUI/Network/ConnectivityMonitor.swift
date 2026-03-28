import Foundation
import Network
import Combine

/// Monitors network connectivity using `NWPathMonitor`.
///
/// Publishes `isConnected` as a `@Published` property so SwiftUI views can react to
/// connectivity changes via `@ObservedObject` / `@EnvironmentObject`.
///
/// Usage:
/// ```swift
/// let monitor = ConnectivityMonitor()
/// monitor.start()
/// // observe monitor.isConnected
/// // ...
/// monitor.stop()
/// ```
internal final class ConnectivityMonitor: ObservableObject {

    /// Whether the device currently has a usable network path.
    @Published private(set) var isConnected: Bool = true

    /// The underlying NWPathMonitor instance — recreated per start() since cancel() is terminal.
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
    /// Creates a fresh NWPathMonitor each time since cancel() is terminal.
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let newMonitor = NWPathMonitor()
        self.monitor = newMonitor

        newMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                if self.isConnected != connected {
                    self.isConnected = connected
                }
            }
        }

        newMonitor.start(queue: queue)
    }

    /// Stop monitoring network connectivity.
    ///
    /// Safe to call multiple times -- subsequent calls are no-ops.
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor?.cancel()
        monitor = nil
    }

    deinit {
        stop()
    }
}
