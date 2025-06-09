import SwiftUI
import CodeScanner

struct ScannerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cart: Cart
    @StateObject private var viewModel = CheckoutViewModel()
    
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var lastScannedCode = ""
    @State private var flashlightOn = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Scanner
                CodeScannerView(
                    codeTypes: [.ean8, .ean13, .upce, .code128, .code39],
                    scanMode: .continuous,
                    showViewfinder: true,
                    simulatedData: "123456789012", // For testing in simulator
                    shouldVibrateOnSuccess: true,
                    completion: handleScan
                )
                .ignoresSafeArea()
                
                // Overlay
                VStack {
                    // Top Bar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.title3)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Spacer()
                        
                        Button(action: {
                            flashlightOn.toggle()
                        }) {
                            Image(systemName: flashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.title3)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Scanning Frame
                    Rectangle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: Constants.UI.scannerFrameSize, height: Constants.UI.scannerFrameSize)
                        .overlay(
                            // Corner accents
                            ZStack {
                                // Top left
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 20))
                                    path.addLine(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 20, y: 0))
                                }
                                .stroke(Color.green, lineWidth: 4)
                                
                                // Top right
                                Path { path in
                                    path.move(to: CGPoint(x: Constants.UI.scannerFrameSize - 20, y: 0))
                                    path.addLine(to: CGPoint(x: Constants.UI.scannerFrameSize, y: 0))
                                    path.addLine(to: CGPoint(x: Constants.UI.scannerFrameSize, y: 20))
                                }
                                .stroke(Color.green, lineWidth: 4)
                                
                                // Bottom left
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: Constants.UI.scannerFrameSize - 20))
                                    path.addLine(to: CGPoint(x: 0, y: Constants.UI.scannerFrameSize))
                                    path.addLine(to: CGPoint(x: 20, y: Constants.UI.scannerFrameSize))
                                }
                                .stroke(Color.green, lineWidth: 4)
                                
                                // Bottom right
                                Path { path in
                                    path.move(to: CGPoint(x: Constants.UI.scannerFrameSize - 20, y: Constants.UI.scannerFrameSize))
                                    path.addLine(to: CGPoint(x: Constants.UI.scannerFrameSize, y: Constants.UI.scannerFrameSize))
                                    path.addLine(to: CGPoint(x: Constants.UI.scannerFrameSize, y: Constants.UI.scannerFrameSize - 20))
                                }
                                .stroke(Color.green, lineWidth: 4)
                            }
                        )
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 10) {
                        Text("Position barcode within frame")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Looking up product...")
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let scanResult):
            let code = scanResult.string
            
            // Prevent scanning the same code repeatedly
            guard code != lastScannedCode || !isProcessing else { return }
            
            lastScannedCode = code
            lookupProduct(upc: code)
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func lookupProduct(upc: String) {
        isProcessing = true
        
        Task {
            do {
                let product = try await viewModel.scanProduct(upc: upc)
                
                await MainActor.run {
                    // Check restrictions
                    if let timeRestriction = product.department?.timeRestriction,
                       !product.department!.isSaleAllowedNow() {
                        errorMessage = "This product cannot be sold at this time. Sales restricted between \(timeRestriction.displayString)"
                        showingError = true
                    } else {
                        // Add to cart
                        let taxRate = AuthService.shared.currentUser?.business?.taxRate ?? 0
                        cart.addItem(product, quantity: 1, taxRate: taxRate)
                        
                        // Success feedback
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        
                        // Brief delay before allowing next scan
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            lastScannedCode = ""
                        }
                    }
                    
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Product not found. Please add it to your inventory first."
                    showingError = true
                    isProcessing = false
                    lastScannedCode = ""
                }
            }
        }
    }
}
