
import Foundation

struct Department: Codable, Identifiable {
    let id: UUID
    let businessId: UUID
    let name: String
    let taxable: Bool
    let ageRestriction: Int?
    let timeRestriction: TimeRestriction?
    let system: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case businessId = "business_id"
        case name
        case taxable
        case ageRestriction = "age_restriction"
        case timeRestriction = "time_restriction"
        case system
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Check if sale is allowed at current time
    func isSaleAllowedNow() -> Bool {
        guard let restriction = timeRestriction else { return true }
        
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        if restriction.start <= restriction.end {
            // Normal range (e.g., 2 AM to 6 AM)
            return hour < restriction.start || hour >= restriction.end
        } else {
            // Overnight range (e.g., 12 AM to 6 AM)
            return hour >= restriction.end && hour < restriction.start
        }
    }
    
    var displayName: String {
        var name = self.name
        if ageRestriction != nil {
            name += " 🔞"
        }
        if timeRestriction != nil {
            name += " ⏰"
        }
        return name
    }
}

struct TimeRestriction: Codable {
    let start: Int // Hour (0-23)
    let end: Int   // Hour (0-23)
    
    var displayString: String {
        let startTime = formatHour(start)
        let endTime = formatHour(end)
        return "\(startTime) - \(endTime)"
    }
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
}

// Department creation/update request
struct DepartmentRequest: Codable {
    let name: String
    let taxable: Bool
    let ageRestriction: Int?
    let timeRestriction: TimeRestriction?
    
    enum CodingKeys: String, CodingKey {
        case name
        case taxable
        case ageRestriction = "age_restriction"
        case timeRestriction = "time_restriction"
    }
}
