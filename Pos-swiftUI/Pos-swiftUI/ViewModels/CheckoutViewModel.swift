import Foundation
import SwiftUI

@MainActor
class CheckoutViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    @Published var departments: [Department] = []
    @Published var selectedDepartment: Department?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let productService = ProductService.shared
    private let departmentService = DepartmentService.shared
    private let checkoutService = CheckoutService.shared
    
    init() {
        // Subscribe to product updates
        productService.$products
            .assign(to: &$products)
        
        departmentService.$departments
            .assign(to: &$departments)
    }
    
    func loadProducts() {
        Task {
            do {
                try await productService.fetchProducts()
                filterProducts()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func loadDepartments() {
        Task {
            do {
                try await departmentService.fetchDepartments()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func filterProducts() {
        if let department = selectedDepartment {
            filteredProducts = products.filter { $0.departmentId == department.id }
        } else {
            filteredProducts = products
        }
    }
    
    func searchProducts(_ searchText: String) {
        if searchText.isEmpty {
            filterProducts()
        } else {
            let searchLower = searchText.lowercased()
            filteredProducts = products.filter { product in
                product.name.lowercased().contains(searchLower) ||
                (product.upc?.contains(searchText) ?? false)
            }
        }
    }
    
    func addToCart(_ product: Product, cart: Cart) {
        // Check time restrictions
        if let timeRestriction = product.department?.timeRestriction,
           !product.department!.isSaleAllowedNow() {
            errorMessage = "This product cannot be sold at this time. Sales restricted between \(timeRestriction.displayString)"
            return
        }
        
        let taxRate = AuthService.shared.currentUser?.business?.taxRate ?? 0
        cart.addItem(product, quantity: 1, taxRate: taxRate)
    }
    
    func scanProduct(upc: String) async throws -> Product {
        return try await productService.getProductByUPC(upc)
    }
}
