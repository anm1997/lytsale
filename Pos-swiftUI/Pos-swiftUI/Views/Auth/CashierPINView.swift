import SwiftUI

struct CashierPINView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    
    @State private var businessId = ""
    @State private var selectedCashier: Cashier?
    @State private var pin = ""
    @State private var cashiers: [Cashier] = []
    @State private var isLoadingCashiers = false
    @State private var isLoggingIn = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Grid layout for PIN pad
    let pinPadButtons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Back") {
                        dismiss()
                    }
                    .font(.title3)
                    .padding()
                    
                    Spacer()
                    
                    Text("Cashier Login")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Text("Back")
                        .font(.title3)
                        .padding()
                        .opacity(0)
                }
                .background(Color(UIColor.secondarySystemBackground))
                
                if businessId.isEmpty {
                    // Business ID Entry
                    businessIdEntryView
                } else if selectedCashier == nil {
                    // Cashier Selection
                    cashierSelectionView
                } else {
                    // PIN Entry
                    pinEntryView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Business ID Entry View
    
    private var businessIdEntryView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "building.2")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Enter Business ID")
                    .font(.title)
                    .fontWeight(.medium)
                
                TextField("Business ID", text: $businessId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title2)
                    .frame(width: 400, height: 60)
                    .multilineTextAlignment(.center)
                
                Button("Continue") {
                    loadCashiers()
                }
                .frame(width: 200, height: 50)
                .background(!businessId.isEmpty ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(businessId.isEmpty)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Cashier Selection View
    
    private var cashierSelectionView: some View {
        VStack(spacing: 30) {
            Text("Select Cashier")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            if isLoadingCashiers {
                ProgressView("Loading cashiers...")
                    .frame(maxHeight: .infinity)
            } else if cashiers.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No cashiers found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200), spacing: 20)
                    ], spacing: 20) {
                        ForEach(cashiers) { cashier in
                            Button(action: {
                                selectedCashier = cashier
                            }) {
                                VStack(spacing: 15) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    
                                    Text(cashier.name)
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 200, height: 150)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            
            Button("Change Business") {
                businessId = ""
                cashiers = []
            }
            .font(.headline)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - PIN Entry View
    
    private var pinEntryView: some View {
        VStack(spacing: 40) {
            // Cashier Info
            VStack(spacing: 15) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text(selectedCashier?.name ?? "")
                    .font(.title)
                    .fontWeight(.medium)
            }
            .padding(.top, 40)
            
            // PIN Display
            HStack(spacing: 20) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index < pin.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
            }
            
            // PIN Pad
            VStack(spacing: 15) {
                ForEach(pinPadButtons, id: \.self) { row in
                    HStack(spacing: 15) {
                        ForEach(row, id: \.self) { button in
                            if button.isEmpty {
                                Color.clear
                                    .frame(width: Constants.UI.pinPadButtonSize, height: Constants.UI.pinPadButtonSize)
                            } else {
                                Button(action: {
                                    handlePinButton(button)
                                }) {
                                    if button == "⌫" {
                                        Image(systemName: "delete.left")
                                            .font(.title)
                                            .frame(width: Constants.UI.pinPadButtonSize, height: Constants.UI.pinPadButtonSize)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(Constants.UI.pinPadButtonSize / 2)
                                    } else {
                                        Text(button)
                                            .font(.title)
                                            .fontWeight(.medium)
                                            .frame(width: Constants.UI.pinPadButtonSize, height: Constants.UI.pinPadButtonSize)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(Constants.UI.pinPadButtonSize / 2)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            
            // Loading indicator
            if isLoggingIn {
                ProgressView("Logging in...")
                    .padding(.top, 20)
            }
            
            // Change Cashier Button
            Button("Change Cashier") {
                selectedCashier = nil
                pin = ""
            }
            .font(.headline)
            .padding(.top, 20)
        }
        .frame(maxWidth: 500)
    }
    
    // MARK: - Helper Methods
    
    private func handlePinButton(_ button: String) {
        if button == "⌫" {
            if !pin.isEmpty {
                pin.removeLast()
            }
        } else if pin.count < 4 {
            pin += button
            
            // Auto-submit when 4 digits entered
            if pin.count == 4 {
                login()
            }
        }
    }
    
    private func loadCashiers() {
        isLoadingCashiers = true
        
        Task {
            do {
                let fetchedCashiers = try await authService.getCashierList(businessId: businessId)
                
                await MainActor.run {
                    cashiers = fetchedCashiers
                    isLoadingCashiers = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load cashiers. Please check the Business ID."
                    showingError = true
                    isLoadingCashiers = false
                    businessId = ""
                }
            }
        }
    }
    
    private func login() {
        guard let cashier = selectedCashier else { return }
        
        isLoggingIn = true
        
        Task {
            do {
                _ = try await authService.loginWithPIN(businessId: businessId, pin: pin)
                
                await MainActor.run {
                    // Success - app will navigate automatically
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid PIN"
                    showingError = true
                    pin = ""
                    isLoggingIn = false
                }
            }
        }
    }
}
