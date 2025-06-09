import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSplash = true
    
    var body: some View {
        Group {
            if showingSplash {
                SplashView()
                    .onAppear {
                        // Check session after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showingSplash = false
                            }
                        }
                    }
            } else if authService.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "cart.circle.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("Lytsale")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Point of Sale")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            NavigationView {
                DashboardView()
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .tag(0)
            
            // Checkout
            NavigationView {
                CheckoutView()
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .tabItem {
                Label("Checkout", systemImage: "cart")
            }
            .tag(1)
            
            // Products (if manager/owner)
            if authService.currentUser?.role != .cashier {
                NavigationView {
                    ProductsListView()
                }
                .navigationViewStyle(DoubleColumnNavigationViewStyle())
                .tabItem {
                    Label("Products", systemImage: "cube.box")
                }
                .tag(2)
            }
            
            // Reports (if manager/owner)
            if authService.currentUser?.role != .cashier {
                NavigationView {
                    ReportsView()
                }
                .navigationViewStyle(DoubleColumnNavigationViewStyle())
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
                .tag(3)
            }
            
            // Settings
            NavigationView {
                SettingsView()
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - Placeholder Views (to be replaced with actual views)

struct ReportsView: View {
    var body: some View {
        Text("Reports")
            .font(.largeTitle)
            .navigationTitle("Reports")
    }
}

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("User")
                    Spacer()
                    Text(authService.currentUser?.name ?? "")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Role")
                    Spacer()
                    Text(authService.currentUser?.role.displayName ?? "")
                        .foregroundColor(.secondary)
                }
                
                Button("Logout") {
                    Task {
                        try? await authService.logout()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
    }
}
