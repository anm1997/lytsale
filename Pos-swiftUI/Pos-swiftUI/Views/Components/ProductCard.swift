import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingCashManagement = false
    @State private var showingAddProduct = false
    @State private var showingAddCashier = false
    @State private var showingStripeSetup = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Actions Grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150))
                ], spacing: 15) {
                    // Cash Management
                    QuickActionCard(
                        icon: "banknote",
                        title: "Cash Drawer",
                        subtitle: "Start/End Day",
                        color: .green
                    ) {
                        showingCashManagement = true
                    }
                    
                    // Add Product
                    if authService.currentUser?.role != .cashier {
                        QuickActionCard(
                            icon: "plus.circle",
                            title: "Add Product",
                            subtitle: "New Item",
                            color: .blue
                        ) {
                            showingAddProduct = true
                        }
                    }
                    
                    // Add Cashier
                    if authService.currentUser?.role == .owner {
                        QuickActionCard(
                            icon: "person.badge.plus",
                            title: "Add Cashier",
                            subtitle: "New User",
                            color: .purple
                        ) {
                            showingAddCashier = true
                        }
                    }
                    
                    // Stripe Setup
                    if authService.currentUser?.role == .owner &&
                       !(authService.currentUser?.business?.stripeConnected ?? false) {
                        QuickActionCard(
                            icon: "creditcard.circle",
                            title: "Setup Payments",
                            subtitle: "Connect Stripe",
                            color: .orange
                        ) {
                            showingStripeSetup = true
                        }
                    }
                    
                    // View Reports
                    if authService.currentUser?.role != .cashier {
                        QuickActionCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Reports",
                            subtitle: "View Analytics",
                            color: .indigo
                        ) {
                            // Navigate to reports
                        }
                    }
                    
                    // Print Test Receipt
                    QuickActionCard(
                        icon: "printer",
                        title: "Test Receipt",
                        subtitle: "Print Test",
                        color: .gray
                    ) {
                        // Print test receipt
                    }
                }
                .padding(.horizontal)
                
                // Recent Activity
                if authService.currentUser?.role != .cashier {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Activity")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 10) {
                            ActivityRow(
                                icon: "cart.circle.fill",
                                title: "Sale completed",
                                subtitle: "2 minutes ago",
                                amount: "$45.99"
                            )
                            
                            ActivityRow(
                                icon: "plus.circle.fill",
                                title: "Product added",
                                subtitle: "15 minutes ago",
                                amount: nil
                            )
                            
                            ActivityRow(
                                icon: "person.circle.fill",
                                title: "Cashier logged in",
                                subtitle: "1 hour ago",
                                amount: nil
                            )
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Quick Actions")
        .sheet(isPresented: $showingCashManagement) {
            CashManagementView()
        }
        .sheet(isPresented: $showingAddProduct) {
            ProductFormView(product: nil)
        }
        .sheet(isPresented: $showingAddCashier) {
            AddCashierView()
        }
        .sheet(isPresented: $showingStripeSetup) {
            StripeSetupView()
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let amount: String?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let amount = amount {
                Text(amount)
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// Placeholder views
struct CashManagementView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Cash Management")
                .navigationTitle("Cash Drawer")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        dismiss()
                    }
                )
        }
    }
}

struct AddCashierView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Add Cashier")
                .navigationTitle("New Cashier")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        dismiss()
                    }
                )
        }
    }
}

struct StripeSetupView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Stripe Setup")
                .navigationTitle("Connect Stripe")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        dismiss()
                    }
                )
        }
    }
}
