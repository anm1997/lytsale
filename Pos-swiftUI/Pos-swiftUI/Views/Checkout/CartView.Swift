import SwiftUI

struct CartView: View {
    @ObservedObject var cart: Cart
    @Binding var showingPayment: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Cart Header
            HStack {
                Text("Cart")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if !cart.items.isEmpty {
                    Button("Clear") {
                        cart.clear()
                    }
                    .foregroundColor(.red)
                }
            }
            .padding()
            
            Divider()
            
            // Cart Content
            if cart.items.isEmpty {
                emptyCartView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                            CartItemView(
                                item: item,
                                onUpdateQuantity: { newQuantity in
                                    cart.updateQuantity(at: index, quantity: newQuantity)
                                },
                                onDelete: {
                                    cart.removeItem(at: index)
                                }
                            )
                            
                            if index < cart.items.count - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                
                // Age Warning
                if cart.requiresAgeVerification {
                    ageVerificationWarning
                }
            }
            
            Spacer()
            
            // Cart Summary
            cartSummary
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Empty Cart View
    
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Your cart is empty")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Add items to get started")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Age Verification Warning
    
    private var ageVerificationWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Age Verification Required")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Customer must be \(cart.highestAgeRequirement ?? 21)+ years old")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Cart Summary
    
    private var cartSummary: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Subtotal
                HStack {
                    Text("Subtotal")
                        .font(.body)
                    Spacer()
                    Text(cart.subtotal.asCurrency)
                        .font(.body)
                }
                
                // Tax
                HStack {
                    Text("Tax")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(cart.taxAmount.asCurrency)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Total
                HStack {
                    Text("Total")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(cart.total.asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // Checkout Button
                Button(action: {
                    showingPayment = true
                }) {
                    HStack {
                        Text("Checkout")
                        Text("•")
                        Text(cart.total.asCurrency)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(cart.items.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(cart.items.isEmpty)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

// MARK: - Cart Item View

struct CartItemView: View {
    let item: CartItem
    let onUpdateQuantity: (Int) -> Void
    let onDelete: () -> Void
    
    @State private var showingQuantityPicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let department = item.product.department {
                        HStack(spacing: 8) {
                            Text(department.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if department.ageRestriction != nil {
                                Image(systemName: "person.badge.minus")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Price & Total
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.formattedTotal)
                        .font(.headline)
                    
                    if item.quantity > 1 {
                        Text("\(item.quantity) × \(item.formattedPrice)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Quantity & Actions
            HStack {
                // Quantity Selector
                Button(action: {
                    showingQuantityPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text("Qty: \(item.quantity)")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                .foregroundColor(.primary)
                
                Spacer()
                
                // Quick quantity buttons
                HStack(spacing: 8) {
                    Button(action: {
                        if item.quantity > 1 {
                            onUpdateQuantity(item.quantity - 1)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(item.quantity > 1 ? .blue : .gray)
                    }
                    .disabled(item.quantity <= 1)
                    
                    Button(action: {
                        onUpdateQuantity(item.quantity + 1)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingQuantityPicker) {
            QuantityPickerView(
                currentQuantity: item.quantity,
                productName: item.product.name,
                onSelect: { newQuantity in
                    onUpdateQuantity(newQuantity)
                    showingQuantityPicker = false
                }
            )
        }
    }
}

// MARK: - Quantity Picker

struct QuantityPickerView: View {
    let currentQuantity: Int
    let productName: String
    let onSelect: (Int) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedQuantity: Int
    
    init(currentQuantity: Int, productName: String, onSelect: @escaping (Int) -> Void) {
        self.currentQuantity = currentQuantity
        self.productName = productName
        self.onSelect = onSelect
        self._selectedQuantity = State(initialValue: currentQuantity)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(productName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Picker("Quantity", selection: $selectedQuantity) {
                    ForEach(1...99, id: \.self) { quantity in
                        Text("\(quantity)").tag(quantity)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)
                
                Button(action: {
                    onSelect(selectedQuantity)
                }) {
                    Text("Update Quantity")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Select Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}
