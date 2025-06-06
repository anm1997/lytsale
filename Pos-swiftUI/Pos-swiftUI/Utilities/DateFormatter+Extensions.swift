import Foundation

// MARK: - DateFormatter Extensions

extension DateFormatter {
    
    // Shared formatters for performance
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let receiptFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }()
    
    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

// MARK: - Date Extensions

extension Date {
    
    var shortDateString: String {
        DateFormatter.shortDate.string(from: self)
    }
    
    var mediumDateString: String {
        DateFormatter.mediumDate.string(from: self)
    }
    
    var shortTimeString: String {
        DateFormatter.shortTime.string(from: self)
    }
    
    var shortDateTimeString: String {
        DateFormatter.shortDateTime.string(from: self)
    }
    
    var mediumDateTimeString: String {
        DateFormatter.mediumDateTime.string(from: self)
    }
    
    var receiptFormatString: String {
        DateFormatter.receiptFormat.string(from: self)
    }
    
    var dayOfWeekString: String {
        DateFormatter.dayOfWeek.string(from: self)
    }
    
    var timeOnlyString: String {
        DateFormatter.timeOnly.string(from: self)
    }
    
    var iso8601String: String {
        DateFormatter.iso8601Full.string(from: self)
    }
    
    // Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    // Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    // Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    // End of day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    // Start of week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }
    
    // End of week
    var endOfWeek: Date {
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek)!
    }
    
    // Start of month
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }
    
    // End of month
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    
    // Time ago string (e.g., "5 minutes ago")
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - String to Date Extension

extension String {
    var iso8601Date: Date? {
        DateFormatter.iso8601Full.date(from: self)
    }
}
