import SwiftUI

struct NumericKeypad: View {
    @Binding var value: String
    let maxDigits: Int
    let allowDecimal: Bool
    var onSubmit: (() -> Void)?
    
    private let buttons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { button in
                        NumericKeypadButton(
                            title: button,
                            action: {
                                handleButtonTap(button)
                            },
                            isEnabled: isButtonEnabled(button)
                        )
                    }
                }
            }
            
            if onSubmit != nil {
                Button(action: {
                    onSubmit?()
                }) {
                    Text("Enter")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(value.isEmpty)
            }
        }
        .padding()
    }
    
    private func handleButtonTap(_ button: String) {
        switch button {
        case "⌫":
            if !value.isEmpty {
                value.removeLast()
            }
        case ".":
            if allowDecimal && !value.contains(".") {
                if value.isEmpty {
                    value = "0."
                } else {
                    value += "."
                }
            }
        default:
            // Check max digits (excluding decimal point)
            let digitCount = value.replacingOccurrences(of: ".", with: "").count
            if digitCount < maxDigits {
                // Don't allow leading zeros
                if value == "0" && button != "." {
                    value = button
                } else {
                    value += button
                }
            }
        }
    }
    
    private func isButtonEnabled(_ button: String) -> Bool {
        switch button {
        case ".":
            return allowDecimal && !value.contains(".")
        case "⌫":
            return !value.isEmpty
        default:
            let digitCount = value.replacingOccurrences(of: ".", with: "").count
            return digitCount < maxDigits
        }
    }
}

struct NumericKeypadButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .frame(height: 60)
                
                if title == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .foregroundColor(foregroundColor)
                } else {
                    Text(title)
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(foregroundColor)
                }
            }
        }
        .disabled(!isEnabled)
    }
    
    private var backgroundColor: Color {
        if !isEnabled {
            return Color.gray.opacity(0.3)
        } else if title == "⌫" {
            return Color.red.opacity(0.2)
        } else {
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return Color.gray
        } else if title == "⌫" {
            return Color.red
        } else {
            return Color.primary
        }
    }
}

// Numeric input field with keypad
struct NumericInputField: View {
    let title: String
    @Binding var value: String
    let placeholder: String
    let maxDigits: Int
    let allowDecimal: Bool
    let prefix: String?
    
    @State private var showingKeypad = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                if let prefix = prefix {
                    Text(prefix)
                        .font(.title3)
                }
                
                Text(value.isEmpty ? placeholder : value)
                    .font(.title3)
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "number.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .onTapGesture {
                showingKeypad = true
            }
        }
        .sheet(isPresented: $showingKeypad) {
            NavigationView {
                VStack {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    HStack {
                        if let prefix = prefix {
                            Text(prefix)
                                .font(.system(size: 48))
                        }
                        
                        Text(value.isEmpty ? "0" : value)
                            .font(.system(size: 48))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    
                    Spacer()
                    
                    NumericKeypad(
                        value: $value,
                        maxDigits: maxDigits,
                        allowDecimal: allowDecimal,
                        onSubmit: {
                            showingKeypad = false
                        }
                    )
                }
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingKeypad = false
                    },
                    trailing: Button("Done") {
                        showingKeypad = false
                    }
                    .fontWeight(.semibold)
                )
            }
        }
    }
}
