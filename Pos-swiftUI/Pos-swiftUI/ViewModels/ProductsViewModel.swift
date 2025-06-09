import Foundation
import SwiftUI

@MainActor
class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    @Published var departments: [Department] = []
    @Published var selectedDepartment: Department? {
        didSet {
            filterProducts(searchText: currentSearchText)
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let productService = ProductService.shared
    private let departmentService = DepartmentService.shared
    private var currentSearchText = ""
    
    init() {
        // Subscribe to service updates
        productService.$products
            .assign(to: &$products)
        
        departmentService.$departments
            .assign(to: &$departments)
    }
    
    func loadData() {
        Task {
            isLoading = true
            
            async let productsTask: () = loadProducts()
            async let departmentsTask: () = loadDepartments()
            
            // Wait for both to complete
            _ = await (productsTask, departmentsTask)
            
            filterProducts(searchText: currentSearchText)
            isLoading = false
        }
    }
    
    func loadProducts() async {
        do {
            try await productService.fetchProducts()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    func loadDepartments() async {
        do {
            try await departmentService.fetchDepartments()
        } catch {
            errorMessage = "Failed to load departments: \(error.localizedDescription)"
        }
    }
    
    func filterProducts(searchText: String) {
        currentSearchText = searchText
        
        var filtered = products
        
        // Filter by department
        if let department = selectedDepartment {
            filtered = filtered.filter { $0.departmentId == department.id }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { product in
                product.name.lowercased().contains(searchLower) ||
                (product.upc?.contains(searchText) ?? false)
            }
        }
        
        // Sort by name
        filteredProducts = filtered.sorted { $0.name < $1.name }
    }
    
    func createProduct(_ request: ProductRequest) async throws -> Product {
        return try await productService.createProduct(request)
    }
    
    func updateProduct(_ id: UUID, request: ProductRequest) async throws -> Product {
        return try await productService.updateProduct(id: id, request: request)
    }
    
    func deleteProduct(_ product: Product) async throws {
        try await productService.deleteProduct(id: product.id)
    }
    
    func toggleProductStatus(_ product: Product) async {
        let request = ProductRequest(
            upc: product.upc,
            name: product.name,
            departmentId: product.departmentId,
            price: product.price,
            caseCost: product.caseCost,
            unitsPerCase: product.unitsPerCase
        )
        
        do {
            _ = try await productService.updateProduct(id: product.id, request: request)
        } catch {
            errorMessage = "Failed to update product: \(error.localizedDescription)"
        }
    }
    
    // Import products from CSV
    func importProducts(from data: Data) async throws {
        // Parse CSV data
        let csvString = String(data: data, encoding: .utf8) ?? ""
        let rows = csvString.components(separatedBy: .newlines)
        
        guard rows.count > 1 else {
            throw ImportError.invalidFormat
        }
        
        // Parse header
        let headers = rows[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard headers.contains("name"),
              headers.contains("price"),
              headers.contains("department") else {
            throw ImportError.missingRequiredColumns
        }
        
        var productsToImport: [ProductRequest] = []
        var errors: [String] = []
        
        // Parse each row
        for (index, row) in rows.dropFirst().enumerated() {
            guard !row.isEmpty else { continue }
            
            let values = row.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            guard values.count == headers.count else {
                errors.append("Row \(index + 2): Invalid column count")
                continue
            }
            
            // Create dictionary from row
            var rowData: [String: String] = [:]
            for (i, header) in headers.enumerated() {
                rowData[header.lowercased()] = values[i]
            }
            
            // Validate required fields
            guard let name = rowData["name"], !name.isEmpty,
                  let priceString = rowData["price"],
                  let price = Double(priceString),
                  let departmentName = rowData["department"] else {
                errors.append("Row \(index + 2): Missing required fields")
                continue
            }
            
            // Find department
            guard let department = departments.first(where: { $0.name.lowercased() == departmentName.lowercased() }) else {
                errors.append("Row \(index + 2): Department '\(departmentName)' not found")
                continue
            }
            
            // Create product request
            let request = ProductRequest(
                upc: rowData["upc"],
                name: name,
                departmentId: department.id,
                price: Int(price * 100),
                caseCost: rowData["case_cost"].flatMap { Double($0) }.map { Int($0 * 100) },
                unitsPerCase: rowData["units_per_case"].flatMap { Int($0) }
            )
            
            productsToImport.append(request)
        }
        
        // Import products
        if !productsToImport.isEmpty {
            let response = try await productService.bulkImportProducts(productsToImport)
            
            if let responseErrors = response.errors {
                errors.append(contentsOf: responseErrors)
            }
            
            // Reload products
            try await productService.fetchProducts()
            
            if !errors.isEmpty {
                throw ImportError.partialImport(errors: errors, imported: response.imported)
            }
        } else {
            throw ImportError.noValidProducts
        }
    }
}

// MARK: - Import Errors

enum ImportError: LocalizedError {
    case invalidFormat
    case missingRequiredColumns
    case noValidProducts
    case partialImport(errors: [String], imported: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid CSV format"
        case .missingRequiredColumns:
            return "CSV must contain columns: name, price, department"
        case .noValidProducts:
            return "No valid products found to import"
        case .partialImport(let errors, let imported):
            return "Imported \(imported) products with \(errors.count) errors"
        }
    }
}
