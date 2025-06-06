import Foundation

// MARK: - Currency Formatter

struct CurrencyFormatter {
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private static let inputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // Format cents to currency string
    static func format(cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
    }
    
    // Format double to currency string
    static func format(dollars: Double) -> String {
        return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
    }
    
    // Parse currency string to cents
    static func parseCents(from string: String) -> Int? {
        let cleanString = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard let number = inputFormatter.number(from: cleanString) else {
            return nil
        }
        
        return Int(number.doubleValue * 100)
    }
    
    // Parse currency string to dollars
    static func parseDollars(from string: String) -> Double? {
        let cleanString = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return inputFormatter.number(from: cleanString)?.doubleValue
    }
    
    // Format for display in text field (no currency symbol)
    static func formatForInput(cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return inputFormatter.string(from: NSNumber(value: dollars)) ?? "0"
    }
    
    // Calculate change
    static func calculateChange(received: Int, total: Int) -> Int {
        return received - total
    }
    
    // Format change with label
    static func formatChange(cents: Int) -> String {
        if cents == 0 {
            return "No change"
        } else if cents > 0 {
            return "Change: \(format(cents: cents))"
        } else {
            return "Amount due: \(format(cents: abs(cents)))"
        }
    }
}

// MARK: - Extensions

extension Int {
    var asCurrency: String {
        CurrencyFormatter.format(cents: self)
    }
}

extension Double {
    var asCurrency: String {
        CurrencyFormatter.format(dollars: self)
    }
    
    var asCents: Int {
        Int(self * 100)
    }
}

extension String {
    var asCents: Int? {
        CurrencyFormatter.parseCents(from: self)
    }
    
    var asDollars: Double? {
        CurrencyFormatter.parseDollars(from: self)
    }
}
