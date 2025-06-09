import SwiftUI

struct ProductFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProductsViewModel()
    
    let product: Product?
    
    @State private var name = ""
    @State private var upc = ""
    @State private var selectedDepartment: Department?
    @State private var price = ""
    @State private var caseCost = ""
    @State private var unitsPerCase = ""
    @State private var isActive = true
    @State private var showingScanner = false
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isEditing: Bool { product != nil }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Product Information") {
                    TextField("Product Name", text: $name)
                    
                    HStack {
                        TextField("UPC/Barcode", text: $upc)
                            .keyboardType(.numberPad)
                        
                        Button(action: { showingScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Department
                Section("Department") {
                    Picker("Department", selection: $selectedDepartment) {
                        Text("Select Department").tag(nil as Department?)
                        
                        ForEach(viewModel.departments) { department in
                            HStack {
                                Text(department.name)
                                
                                Spacer()
                                
                                if department.taxable {
                                    Text("TAX")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                if department.ageRestriction != nil {
                                    Image(systemName: "person.badge.minus")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .tag(department as Department?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if let department = selectedDepartment {
                        VStack(alignment: .leading, spacing: 8) {
                            if department.taxable {
                                Label("Taxable item", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let age = department.ageRestriction {
                                Label("Age restriction: \(age)+", systemImage: "person.badge.minus")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            if let time = department.timeRestriction {
                                Label("Time restriction: \(time.displayString)", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                // Pricing
                Section("Pricing") {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Cost & Margin (Optional)
                Section {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $caseCost)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Units per Case", text: $unitsPerCase)
                        .keyboardType(.numberPad)
                    
                    if let margin = calculateMargin() {
                        HStack {
                            Text("Estimated Margin")
                            
                            Spacer()
                            
                            Text("\(Int(margin))%")
                                .fontWeight(.medium)
                                .foregroundColor(margin > 30 ? .green : margin > 15 ? .orange : .red)
                        }
                    }
                } header: {
                    Text("Cost & Margin (Optional)")
                } footer: {
                    Text("Enter case cost and units to calculate profit margin")
                }
                
                // Status
                if isEditing {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    } footer: {
                        Text("Inactive products won't appear in checkout")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Product" : "New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveProduct()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isLoading)
                }
            }
            .onAppear {
                viewModel.loadDepartments()
                if let product = product {
                    loadProduct(product)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerSheet { scannedCode in
                    upc = scannedCode
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty &&
        selectedDepartment != nil &&
        !price.isEmpty &&
        (Double(price) ?? 0) > 0
    }
    
    private var hasChanges: Bool {
        if isEditing {
            return true // Simplified - in production, compare with original
        }
        return !name.isEmpty || !upc.isEmpty || !price.isEmpty
    }
    
    private func calculateMargin() -> Double? {
        guard let priceValue = Double(price),
              let caseCostValue = Double(caseCost),
              let unitsValue = Int(unitsPerCase),
              unitsValue > 0,
              priceValue > 0 else { return nil }
        
        let unitCost = caseCostValue / Double(unitsValue)
        return ((priceValue - unitCost) / priceValue) * 100
    }
    
    private func loadProduct(_ product: Product) {
        name = product.name
        upc = product.upc ?? ""
        selectedDepartment = product.department
        price = String(format: "%.2f", Double(product.price) / 100.0)
        
        if let cost = product.caseCost {
            caseCost = String(format: "%.2f", Double(cost) / 100.0)
        }
        
        if let units = product.unitsPerCase {
            unitsPerCase = String(units)
        }
        
        isActive = product.active
    }
    
    private func saveProduct() {
        guard let department = selectedDepartment,
              let priceValue = Double(price) else { return }
        
        isLoading = true
        
        let request = ProductRequest(
            upc: upc.isEmpty ? nil : upc,
            name: name,
            departmentId: department.id,
            price: Int(priceValue * 100),
            caseCost: caseCost.isEmpty ? nil : Int((Double(caseCost) ?? 0) * 100),
            unitsPerCase: unitsPerCase.isEmpty ? nil : Int(unitsPerCase)
        )
        
        Task {
            do {
                if let product = product {
                    _ = try await viewModel.updateProduct(product.id, request: request)
                } else {
                    _ = try await viewModel.createProduct(request)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Barcode Scanner Sheet

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) var dismiss
    let onScan: (String) -> Void
    
    var body: some View {
        NavigationView {
            ScannerViewSimple { result in
                switch result {
                case .success(let scanResult):
                    onScan(scanResult.string)
                    dismiss()
                case .failure:
                    break
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Simple scanner wrapper
struct ScannerViewSimple: UIViewControllerRepresentable {
    let completion: (Result<ScanResult, ScanError>) -> Void
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let scanner = ScannerViewController()
        scanner.completion = completion
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

class ScannerViewController: UIViewController {
    var completion: ((Result<ScanResult, ScanError>) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Scanner implementation
    }
}
