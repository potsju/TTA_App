import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    let id: String
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var phoneNumber: String
    var gender: String
    var email: String
    var profileImageURL: String
    var role: String
    
    init(id: String,
         firstName: String = "",
         lastName: String = "",
         dateOfBirth: Date = Date(),
         phoneNumber: String = "",
         gender: String = "",
         email: String = "",
         profileImageURL: String = "",
         role: String = "Student") {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
        self.gender = gender
        self.email = email
        self.profileImageURL = profileImageURL
        self.role = role
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
} 