import SwiftUI

struct OTPVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    
    let email: String
    @State private var otpCode = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    // For the 6 digit inputs
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 20) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Verify Your Email")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("We've sent a verification code to")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(email)
                        .font(.title3)
                        .fontWeight(.medium)
                }
                .padding(.top, 60)
                
                // OTP Input Fields
                HStack(spacing: 15) {
                    ForEach(0..<6, id: \.self) { index in
                        TextField("", text: $digits[index])
                            .frame(width: 60, height: 70)
                            .font(.system(size: 32, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == index ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .focused($focusedField, equals: index)
                            .onChange(of: digits[index]) { newValue in
                                // Limit to 1 character
                                if newValue.count > 1 {
                                    digits[index] = String(newValue.prefix(1))
                                }
                                
                                // Auto-advance to next field
                                if !newValue.isEmpty && index < 5 {
                                    focusedField = index + 1
                                } else if newValue.isEmpty && index > 0 {
                                    focusedField = index - 1
                                }
                                
                                // Update the combined code
                                otpCode = digits.joined()
                            }
                    }
                }
                
                // Verify Button
                Button(action: verifyOTP) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verify Email")
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 300, height: 50)
                .background(otpCode.count == 6 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(otpCode.count != 6 || isLoading)
                
                // Resend Code
                VStack(spacing: 10) {
                    Text("Didn't receive the code?")
                        .foregroundColor(.secondary)
                    
                    Button("Resend Code") {
                        resendCode()
                    }
                    .font(.headline)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
            .navigationBarItems(
                leading: Button("Back") {
                    dismiss()
                }
            )
            .onAppear {
                // Focus first field
                focusedField = 0
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Email verified successfully! You can now complete Stripe setup.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func verifyOTP() {
        isLoading = true
        
        Task {
            do {
                try await authService.verifyOTP(email: email, token: otpCode)
                
                await MainActor.run {
                    showingSuccess = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                    // Clear the fields
                    digits = Array(repeating: "", count: 6)
                    otpCode = ""
                    focusedField = 0
                }
            }
        }
    }
    
    private func resendCode() {
        Task {
            do {
                try await authService.resendOTP(email: email)
                
                await MainActor.run {
                    // Show success message
                    errorMessage = "Verification code sent!"
                    showingError = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
