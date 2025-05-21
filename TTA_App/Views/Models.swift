import Foundation
import FirebaseFirestore

struct ClassBookingInfo: Identifiable {
    let id = UUID()
    let classId: String
    let time: String
    let date: String
    let isFinished: Bool
}

struct Student: Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let profileImage: String?
    let bookedClasses: [ClassBookingInfo]?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    init(id: String, firstName: String, lastName: String, email: String, profileImage: String?, bookedClasses: [ClassBookingInfo]? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.profileImage = profileImage
        self.bookedClasses = bookedClasses
    }
}

// EarningTransaction moved to Transaction.swift for centralization

struct MonthlyReport: Identifiable {
    let id: String // Using month as ID
    let month: String
    var total: Double
    var transactions: [EarningTransaction]
}

struct YearlyReport: Identifiable {
    let id: String // Using year as ID
    let year: String
    var total: Double
    var monthlyReports: [MonthlyReport]
}

// Removing duplicate Class model definition 