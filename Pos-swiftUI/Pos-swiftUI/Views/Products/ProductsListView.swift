import SwiftUI

struct ProductsListView: View {
    @StateObject private var viewModel = ProductsViewModel()
    @State private var showingAddProduct = false
    @State private var showingEditProduct = false
    @State private var selectedProduct: Product?
    @State private var searchText = ""
    @State private var showingImport = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters
            VStack(spacing: 15) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search products...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                // Department Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(
                            title: "All",
                            count: viewModel.products.count,
                            isSelected: viewModel.selectedDepartment == nil
                        ) {
                            viewModel.selectedDepartment = nil
                        }
                        
                        ForEach(viewModel.departments) { department in
                            FilterChip(
                                title: department.name,
                                count: viewModel.products.filter { $0.departmentId == department.id }.count,
                                isSelected: viewModel.selectedDepartment?.id == department.id
                            ) {
                                viewModel.selectedDepartment = department
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            // Products List
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading products...")
                Spacer()
            } else if viewModel.filteredProducts.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "cube.box",
                    title: searchText.isEmpty ? "No products yet" : "No products found",
                    subtitle: searchText.isEmpty ? "Add your first product to get started" : "Try a different search term",
                    actionTitle: searchText.isEmpty ? "Add Product" : nil,
                    action: searchText.isEmpty ? { showingAddProduct = true } : nil
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredProducts) { product in
                        ProductRow(product: product)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProduct = product
                                showingEditProduct = true
                            }
                    }
                    .onDelete(perform: deleteProducts)
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddProduct = true }) {
                        Label("Add Product", systemImage: "plus")
                    }
                    
                    Button(action: { showingImport = true }) {
                        Label("Import Products", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProduct) {
            ProductFormView(product: nil)
        }
        .sheet(isPresented: $showingEditProduct) {
            if let product = selectedProduct {
                ProductFormView(product: product)
            }
        }
        .sheet(isPresented: $showingImport) {
            // Import view
        }
        .onChange(of: searchText) { _ in
            viewModel.filterProducts(searchText: searchText)
        }
        .onAppear {
            viewModel.loadData()
        }
    }
    
    private func deleteProducts(at offsets: IndexSet) {
        for offset in offsets {
            let product = viewModel.filteredProducts[offset]
            Task {
                try? await viewModel.deleteProduct(product)
            }
        }
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 15) {
            // Product Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "cube.box")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    if let upc = product.upc {
                        Text(upc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(product.department?.name ?? "No Department")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Price and Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                if let margin = product.calculatedMargin {
                    Text("\(Int(margin))% margin")
                        .font(.caption)
                        .foregroundColor(margin > 30 ? .green : margin > 15 ? .orange : .red)
                }
            }
            
            // Active Status
            Circle()
                .fill(product.active ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                }
            }
        }
        .padding(40)
    }
}
