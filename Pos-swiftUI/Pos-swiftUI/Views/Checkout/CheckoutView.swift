import SwiftUI

struct CheckoutView: View {
    @StateObject private var viewModel = CheckoutViewModel()
    @StateObject private var cart = Cart()
    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var showingPayment = false
    @State private var showingDepartments = false
    @State private var searchText = ""
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - Products
                productsSection
                    .frame(width: geometry.size.width * 0.65)
                
                Divider()
                
                // Right side - Cart
                CartView(cart: cart, showingPayment: $showingPayment)
                    .frame(width: geometry.size.width * 0.35)
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingDepartments.toggle() }) {
                    Label("Departments", systemImage: "square.grid.3x3")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingScanner = true }) {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScannerView(cart: cart)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(cart: cart)
        }
        .sheet(isPresented: $showingPayment) {
            PaymentView(cart: cart)
        }
        .environmentObject(cart)
        .onAppear {
            viewModel.loadProducts()
            viewModel.loadDepartments()
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name or UPC", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.title3)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
            
            // Department Filter
            if showingDepartments {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        DepartmentChip(
                            name: "All",
                            count: viewModel.products.count,
                            isSelected: viewModel.selectedDepartment == nil
                        ) {
                            viewModel.selectedDepartment = nil
                            viewModel.filterProducts()
                        }
                        
                        ForEach(viewModel.departments) { department in
                            DepartmentChip(
                                name: department.displayName,
                                count: viewModel.products.filter { $0.departmentId == department.id }.count,
                                isSelected: viewModel.selectedDepartment?.id == department.id
                            ) {
                                viewModel.selectedDepartment = department
                                viewModel.filterProducts()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            
            // Products Grid
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(100)
                } else if viewModel.filteredProducts.isEmpty {
                    EmptyStateCard(
                        icon: "cube.box",
                        title: searchText.isEmpty ? "No products yet" : "No products found",
                        subtitle: searchText.isEmpty ? "Add products to start selling" : "Try a different search"
                    )
                    .padding(40)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200))
                    ], spacing: 15) {
                        // Manual Entry Card
                        ManualEntryCard {
                            showingManualEntry = true
                        }
                        
                        // Product Cards
                        ForEach(viewModel.filteredProducts) { product in
                            ProductCard(product: product) {
                                viewModel.addToCart(product, cart: cart)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: searchText) { _ in
            viewModel.searchProducts(searchText)
        }
    }
}

// MARK: - Supporting Views
    
    private var productsSection: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name or UPC", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.title3)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
            
            // Department Filter
            if showingDepartments {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        DepartmentChip(
                            name: "All",
                            isSelected: viewModel.selectedDepartment == nil,
                            action: {
                                viewModel.selectedDepartment = nil
                                viewModel.filterProducts()
                            }
                        )
                        
                        ForEach(viewModel.departments) { department in
                            DepartmentChip(
                                name: department.displayName,
                                isSelected: viewModel.selectedDepartment?.id == department.id,
                                action: {
                                    viewModel.selectedDepartment = department
                                    viewModel.filterProducts()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            
            // Products Grid
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(100)
                } else if viewModel.filteredProducts.isEmpty {
                    EmptyStateCard(
                        icon: "cube.box",
                        title: "No products found",
                        subtitle: searchText.isEmpty ? "Add products to start selling" : "Try a different search"
                    )
                    .padding(40)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200))
                    ], spacing: 15) {
                        // Manual Entry Card
                        ManualEntryCard {
                            showingManualEntry = true
                        }
                        
                        // Product Cards
                        ForEach(viewModel.filteredProducts) { product in
                            ProductCard(product: product) {
                                viewModel.addToCart(product, cart: cart)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: searchText) { _ in
            viewModel.searchProducts(searchText)
        }
    }
    
    // MARK: - Cart Section
    
    private var cartSection: some View {
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
            
            // Cart Items
            if cart.items.isEmpty {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "cart")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Cart is empty")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Scan items or select from the left")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                            CartItemRow(item: item) {
                                cart.removeItem(at: index)
                            }
                        }
                    }
                    .padding()
                }
                
                // Age Warning if needed
                if cart.requiresAgeVerification {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Age verification required (21+)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                }
            }
            
            Divider()
            
            // Cart Summary
            VStack(spacing: 15) {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text(cart.subtotal.asCurrency)
                }
                .font(.title3)
                
                HStack {
                    Text("Tax")
                    Spacer()
                    Text(cart.taxAmount.asCurrency)
                }
                .font(.title3)
                .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(cart.total.asCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Payment Button
                Button(action: {
                    showingPayment = true
                }) {
                    Text("Charge \(cart.total.asCurrency)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(cart.items.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(cart.items.isEmpty)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

// MARK: - Supporting Views

struct DepartmentChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ManualEntryCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Manual")
                    .font(.headline)
                
                Text("Entry")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Manual Entry View

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cart: Cart
    @StateObject private var viewModel = CheckoutViewModel()
    
    @State private var selectedDepartment: Department?
    @State private var price = ""
    @State private var quantity = "1"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Manual Entry")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // Department Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Department")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.departments) { department in
                                DepartmentCard(
                                    department: department,
                                    isSelected: selectedDepartment?.id == department.id
                                ) {
                                    selectedDepartment = department
                                }
                            }
                        }
                    }
                }
                
                // Price Entry
                VStack(alignment: .leading, spacing: 10) {
                    Text("Price")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("$")
                            .font(.title)
                        
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .font(.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Quantity
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quantity")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("1", text: $quantity)
                        .keyboardType(.numberPad)
                        .font(.title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Spacer()
                
                // Add to Cart Button
                Button(action: addToCart) {
                    Text("Add to Cart")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(isValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isValid)
            }
            .padding(40)
            .frame(maxWidth: 600)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
    
    private var isValid: Bool {
        selectedDepartment != nil &&
        !price.isEmpty &&
        (Double(price) ?? 0) > 0 &&
        (Int(quantity) ?? 0) > 0
    }
    
    private func addToCart() {
        guard let department = selectedDepartment,
              let priceValue = Double(price),
              let quantityValue = Int(quantity) else { return }
        
        let priceCents = Int(priceValue * 100)
        
        // Create a temporary product for manual entry
        let product = Product(
            id: UUID(),
            businessId: AuthService.shared.currentUser?.businessId ?? UUID(),
            departmentId: department.id,
            upc: nil,
            name: "\(department.name) Item",
            price: priceCents,
            caseCost: nil,
            unitsPerCase: nil,
            margin: nil,
            active: true,
            createdAt: Date(),
            updatedAt: Date(),
            department: department
        )
        
        let taxRate = AuthService.shared.currentUser?.business?.taxRate ?? 0
        cart.addItem(product, quantity: quantityValue, taxRate: taxRate)
        
        dismiss()
    }
}

struct DepartmentCard: View {
    let department: Department
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(department.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if department.taxable {
                    Text("Taxable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 80)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}
