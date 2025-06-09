import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todaySales: Int = 0
    @Published var transactionCount: Int = 0
    @Published var productCount: Int = 0
    @Published var userCount: Int = 0
    @Published var recentTransactions: [Transaction] = []
    @Published var isLoading = false
    @Published var salesTrend: Double = 0.0
    
    private let api = APIClient.shared
    
    var averageSale: Int {
        guard transactionCount > 0 else { return 0 }
        return todaySales / transactionCount
    }
    
    func loadDashboard() {
        Task {
            isLoading = true
            
            do {
                let response = try await api.get("/business/dashboard", responseType: DashboardResponse.self)
                
                todaySales = response.dashboard.todaySales
                transactionCount = response.dashboard.transactionCount
                productCount = response.dashboard.productCount
                userCount = response.dashboard.userCount
                recentTransactions = response.dashboard.recentTransactions
                
                // Calculate trend (mock for now)
                salesTrend = Double.random(in: -10...20)
                
                isLoading = false
            } catch {
                print("Failed to load dashboard: \(error)")
                isLoading = false
            }
        }
    }
    
    func refreshDashboard() async {
        loadDashboard()
    }
}

// Response type
struct DashboardResponse: Codable {
    let dashboard: DashboardStats
}
