import Foundation
import StripeTerminal

class StripeTerminalService: NSObject, ObservableObject {
    static let shared = StripeTerminalService()
    
    @Published var isConnected = false
    @Published var connectionStatus = "Not Connected"
    @Published var discoveredReaders: [Reader] = []
    @Published var connectedReader: Reader?
    @Published var isDiscovering = false
    
    private var discoverCancelable: Cancelable?
    
    override init() {
        super.init()
        
        // Initialize Stripe Terminal
        Terminal.setTokenProvider(self)
        Terminal.shared.delegate = self
    }
    
    // MARK: - Reader Discovery & Connection
    
    func startDiscovery() {
        guard !isDiscovering else { return }
        
        DispatchQueue.main.async {
            self.isDiscovering = true
            self.discoveredReaders = []
            self.connectionStatus = "Searching for readers..."
        }
        
        let config = DiscoveryConfiguration(
            discoveryMethod: .bluetoothScan,
            simulated: false  // Set to true for testing without physical reader
        )
        
        discoverCancelable = Terminal.shared.discoverReaders(config, delegate: self) { error in
            DispatchQueue.main.async {
                self.isDiscovering = false
                if let error = error {
                    self.connectionStatus = "Discovery failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopDiscovery() {
        discoverCancelable?.cancel { error in
            DispatchQueue.main.async {
                self.isDiscovering = false
                if let error = error {
                    print("Failed to stop discovery: \(error)")
                }
            }
        }
    }
    
    func connectToReader(_ reader: Reader) {
        connectionStatus = "Connecting to \(reader.label ?? "reader")..."
        
        let connectionConfig = BluetoothConnectionConfiguration()
        
        Terminal.shared.connectBluetoothReader(reader, delegate: self, connectionConfig: connectionConfig) { reader, error in
            DispatchQueue.main.async {
                if let reader = reader {
                    self.connectedReader = reader
                    self.isConnected = true
                    self.connectionStatus = "Connected to \(reader.label ?? "reader")"
                } else if let error = error {
                    self.isConnected = false
                    self.connectedReader = nil
                    self.connectionStatus = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func disconnectReader() {
        guard connectedReader != nil else { return }
        
        Terminal.shared.disconnectReader { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.connectionStatus = "Disconnect failed: \(error.localizedDescription)"
                } else {
                    self.connectedReader = nil
                    self.isConnected = false
                    self.connectionStatus = "Disconnected"
                }
            }
        }
    }
    
    // MARK: - Payment Processing
    
    func collectPayment(amount: Int, paymentIntentId: String) async throws {
        guard connectedReader != nil else {
            throw StripeError.readerNotConnected
        }
        
        // Create payment intent on your backend first, then collect payment
        let paymentIntent = try await Terminal.shared.retrievePaymentIntent(clientSecret: paymentIntentId)
        
        // Collect payment method
        let collectConfig = CollectConfiguration()
        let collectedPaymentIntent = try await Terminal.shared.collectPaymentMethod(paymentIntent, collectConfig: collectConfig)
        
        // Process payment
        let processedIntent = try await Terminal.shared.processPayment(collectedPaymentIntent)
        
        // Payment successful if we get here
        print("Payment processed: \(processedIntent.stripeId)")
    }
    
    // MARK: - Reader Updates
    
    func checkForReaderUpdates() {
        Terminal.shared.checkForUpdate { update, error in
            if let update = update {
                // Install update
                Terminal.shared.installAvailableUpdate()
            }
        }
    }
}

// MARK: - TokenProvider

extension StripeTerminalService: ConnectionTokenProvider {
    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        // Fetch token from your backend
        Task {
            do {
                // This should call your backend endpoint to get a connection token
                let api = APIClient.shared
                let response = try await api.post("/stripe-terminal/connection-token", responseType: ConnectionTokenResponse.self)
                completion(response.secret, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}

// MARK: - DiscoveryDelegate

extension StripeTerminalService: DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        DispatchQueue.main.async {
            self.discoveredReaders = readers
            self.connectionStatus = "Found \(readers.count) reader(s)"
        }
    }
}

// MARK: - BluetoothReaderDelegate

extension StripeTerminalService: BluetoothReaderDelegate {
    func reader(_ reader: Reader, didReportAvailableUpdate update: ReaderSoftwareUpdate) {
        // Handle reader updates
        print("Reader update available: \(update)")
    }
    
    func reader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Installing update..."
        }
    }
    
    func reader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {
        DispatchQueue.main.async {
            self.connectionStatus = "Update progress: \(Int(progress * 100))%"
        }
    }
    
    func reader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.connectionStatus = "Update failed: \(error.localizedDescription)"
            } else {
                self.connectionStatus = "Update complete"
            }
        }
    }
    
    func reader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions = []) {
        // Handle reader input requests (insert card, remove card, etc.)
        DispatchQueue.main.async {
            if inputOptions.contains(.insertCard) {
                self.connectionStatus = "Insert card"
            } else if inputOptions.contains(.removeCard) {
                self.connectionStatus = "Remove card"
            } else if inputOptions.contains(.tapCard) {
                self.connectionStatus = "Tap card"
            }
        }
    }
    
    func reader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {
        // Handle display messages
        DispatchQueue.main.async {
            self.connectionStatus = displayMessage.rawValue
        }
    }
}

// MARK: - TerminalDelegate

extension StripeTerminalService: TerminalDelegate {
    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        DispatchQueue.main.async {
            self.connectedReader = nil
            self.isConnected = false
            self.connectionStatus = "Reader disconnected unexpectedly"
        }
    }
}

// MARK: - Supporting Types

enum StripeError: LocalizedError {
    case readerNotConnected
    case paymentFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .readerNotConnected:
            return "No card reader connected"
        case .paymentFailed(let message):
            return "Payment failed: \(message)"
        }
    }
}

struct ConnectionTokenResponse: Codable {
    let secret: String
}
