import Foundation
import UIKit
import SwiftUI
import FirebaseAuth

class ProfileService: ObservableObject {
    private let defaults = UserDefaults.standard
    
    private func getProfileKey(for userId: String) -> String {
        return "userProfile_\(userId)"
    }
    
    private func getProfileImageKey(for userId: String) -> String {
        return "profileImage_\(userId)"
    }
    
    func saveProfile(_ profile: UserProfile, image: UIImage?) async throws {
        // Save profile data
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        defaults.set(data, forKey: getProfileKey(for: profile.id))
        
        // Save profile image if provided
        if let image = image {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                defaults.set(imageData, forKey: getProfileImageKey(for: profile.id))
            }
        }
    }
    
    func loadProfile(userId: String) async throws -> UserProfile {
        guard let data = defaults.data(forKey: getProfileKey(for: userId)) else {
            // Return default profile if no data exists
            return UserProfile(
                id: userId,
                firstName: "",
                lastName: "",
                dateOfBirth: Date(),
                phoneNumber: "",
                gender: "Male",
                email: ""
            )
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(UserProfile.self, from: data)
    }
    
    func loadProfileImage(userId: String) -> UIImage? {
        guard let imageData = defaults.data(forKey: getProfileImageKey(for: userId)),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image
    }
} 