import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cart: Cart
    @StateObject private var stripeTerminal = StripeTerminalService.shared
    @StateObject private var checkoutService = CheckoutService.shared
    
    @State private var selectedPaymentMethod: PaymentMethod = .cash
    @State private var cashReceived = ""
    @State private var isProcessing = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingAgeVerification = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.title3)
                    
                    Spacer()
                    
                    Text("Payment")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Spacer for balance
                    Text("Cancel")
                        .font(.title3)
                        .opacity(0)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Order Summary
                        orderSummarySection
                        
                        // Age Verification if needed
                        if cart.requiresAgeVerification && !cart.customerAgeVerified {
                            ageVerificationSection
                        }
                        
                        // Payment Method Selection
                        paymentMethodSection
                        
                        // Payment Details
                        if selectedPaymentMethod == .cash {
                            cashPaymentSection
                        } else {
                            cardPaymentSection
                        }
                    }
                    .padding()
                }
                
                // Process Payment Button
                processPaymentButton
            }
        }
        .sheet(isPresented: $showingSuccess) {
            PaymentSuccessView(
                paymentMethod: selectedPaymentMethod,
                change: calculateChange()
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Order Summary
    
    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Order Summary")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                ForEach(cart.items) { item in
                    HStack {
                        Text("\(item.quantity)x \(item.product.name)")
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(item.formattedTotal)
                            .fontWeight(.medium)
                    }
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text(cart.subtotal.asCurrency)
                }
                
                HStack {
                    Text("Tax")
                    Spacer()
                    Text(cart.taxAmount.asCurrency)
                }
                .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 5)
                
                HStack {
                    Text("Total Due")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(cart.total.asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Age Verification
    
    private var ageVerificationSection: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text("Age Verification Required")
                        .font(.headline)
                    
                    Text("Customer must be \(cart.highestAgeRequirement ?? 21)+ years old")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(action: {
                showingAgeVerification = true
            }) {
                Text("Verify Age")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingAgeVerification) {
            AgeVerificationSheet(cart: cart)
        }
    }
    
    // MARK: - Payment Method
    
    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Payment Method")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 15) {
                PaymentMethodButton(
                    method: .cash,
                    isSelected: selectedPaymentMethod == .cash
                ) {
                    selectedPaymentMethod = .cash
                }
                
                PaymentMethodButton(
                    method: .card,
                    isSelected: selectedPaymentMethod == .card,
                    isConnected: stripeTerminal.isConnected
                ) {
                    selectedPaymentMethod = .card
                }
            }
        }
    }
    
    // MARK: - Cash Payment
    
    private var cashPaymentSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cash Received")
                .font(.headline)
            
            HStack {
                Text("$")
                    .font(.largeTitle)
                
                TextField("0.00", text: $cashReceived)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Quick cash buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([20, 50, 100, 200], id: \.self) { amount in
                        Button(action: {
                            cashReceived = String(amount)
                        }) {
                            Text("$\(amount)")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            // Change calculation
            if let change = calculateChange(), change >= 0 {
                HStack {
                    Text("Change Due")
                        .font(.title3)
                    
                    Spacer()
                    
                    Text(change.asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Card Payment
    
    private var cardPaymentSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            if stripeTerminal.isConnected {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Card reader connected")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(stripeTerminal.connectedReader?.label ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            } else {
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("No card reader connected")
                            .font(.headline)
                    }
                    
                    Button("Connect Reader") {
                        // Show reader connection view
                    }
                    .font(.headline)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Process Payment Button
    
    private var processPaymentButton: some View {
        Button(action: processPayment) {
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text(selectedPaymentMethod == .cash ? "Complete Sale" : "Charge Card")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(canProcess ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(0)
        .disabled(!canProcess || isProcessing)
    }
    
    // MARK: - Helper Methods
    
    private var canProcess: Bool {
        if cart.requiresAgeVerification && !cart.customerAgeVerified {
            return false
        }
        
        if selectedPaymentMethod == .cash {
            return (cashReceived.asCents ?? 0) >= cart.total
        } else {
            return stripeTerminal.isConnected
        }
    }
    
    private func calculateChange() -> Int? {
        guard selectedPaymentMethod == .cash,
              let received = cashReceived.asCents else { return nil }
        return received - cart.total
    }
    
    private func processPayment() {
        isProcessing = true
        
        Task {
            do {
                let cashReceivedCents = selectedPaymentMethod == .cash ? cashReceived.asCents : nil
                
                let response = try await checkoutService.processPayment(
                    cart: cart,
                    paymentMethod: selectedPaymentMethod,
                    cashReceived: cashReceivedCents
                )
                
                if selectedPaymentMethod == .card {
                    // Process card payment with Stripe Terminal
                    try await stripeTerminal.collectPayment(
                        amount: cart.total,
                        paymentIntentId: response.payment.clientSecret ?? ""
                    )
                    
                    // Confirm payment on backend
                    try await checkoutService.confirmCardPayment(
                        transactionId: response.transaction.id,
                        paymentIntentId: response.payment.paymentIntentId ?? ""
                    )
                }
                
                await MainActor.run {
                    showingSuccess = true
                    isProcessing = false
                    
                    // Clear cart after successful payment
                    cart.clear()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PaymentMethodButton: View {
    let method: PaymentMethod
    let isSelected: Bool
    var isConnected: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: method.icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(method.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                if method == .card && !isConnected {
                    Text("Not Connected")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AgeVerificationSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cart: Cart
    @State private var confirmedAge = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Age Verification Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Customer must be \(cart.highestAgeRequirement ?? 21) or older")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 20) {
                    Button(action: {
                        cart.verifyAge(cart.highestAgeRequirement ?? 21)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Customer is \(cart.highestAgeRequirement ?? 21)+ years old")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Customer is under \(cart.highestAgeRequirement ?? 21)")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

struct PaymentSuccessView: View {
    @Environment(\.dismiss) var dismiss
    let paymentMethod: PaymentMethod
    let change: Int?
    
    @State private var showCheckmark = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Success Animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .scaleEffect(showCheckmark ? 1.0 : 0.8)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCheckmark)
            
            Text("Payment Successful!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if paymentMethod == .cash, let change = change, change > 0 {
                VStack(spacing: 10) {
                    Text("Change Due")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(change.asCurrency)
                        .font(.system(size: 48))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            }
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .onAppear {
            // Trigger animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showCheckmark = true
            }
            
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }
}
