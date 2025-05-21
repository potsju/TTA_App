import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Mock AuthViewModel for previews
class MockAuthViewModel: AuthViewModel {
    init(role: UserRole) {
        super.init()
        self.userRole = role
        self.isAuthenticated = true
    }
}

struct MockData {
    // Mock Coach Data
    static let coaches: [ManagerCoachesView.Coach] = [
        ManagerCoachesView.Coach(
            id: "1",
            firstName: "John",
            lastName: "Smith",
            email: "john.smith@example.com",
            phoneNumber: "(555) 123-4567",
            profileImageURL: nil,
            totalEarnings: 1250,
            totalHours: 25.5,
            activeStudents: 8
        ),
        ManagerCoachesView.Coach(
            id: "2",
            firstName: "Sarah",
            lastName: "Johnson",
            email: "sarah.j@example.com",
            phoneNumber: "(555) 987-6543",
            profileImageURL: nil,
            totalEarnings: 980,
            totalHours: 19.0,
            activeStudents: 5
        ),
        ManagerCoachesView.Coach(
            id: "3",
            firstName: "Michael",
            lastName: "Chen",
            email: "michael.c@example.com",
            phoneNumber: "(555) 456-7890",
            profileImageURL: nil,
            totalEarnings: 1500,
            totalHours: 32.0,
            activeStudents: 10
        )
    ]
    
    // Mock Student Data
    static let students: [ManagerStudentsView.Student] = [
        ManagerStudentsView.Student(
            id: "1",
            firstName: "Emily",
            lastName: "Davis",
            email: "emily.davis@example.com",
            phoneNumber: "(555) 234-5678",
            joinDate: Date().addingTimeInterval(-5_184_000), // ~2 months ago
            profileImageURL: nil,
            activeClasses: 3,
            totalSpent: 350,
            lastActive: Date().addingTimeInterval(-86_400) // 1 day ago
        ),
        ManagerStudentsView.Student(
            id: "2",
            firstName: "James",
            lastName: "Wilson",
            email: "james.w@example.com",
            phoneNumber: "(555) 876-5432",
            joinDate: Date().addingTimeInterval(-15_552_000), // ~6 months ago
            profileImageURL: nil,
            activeClasses: 1,
            totalSpent: 750,
            lastActive: Date().addingTimeInterval(-259_200) // 3 days ago
        ),
        ManagerStudentsView.Student(
            id: "3",
            firstName: "Sophia",
            lastName: "Garcia",
            email: "sophia.g@example.com",
            phoneNumber: "(555) 345-6789",
            joinDate: Date().addingTimeInterval(-864_000), // 10 days ago
            profileImageURL: nil,
            activeClasses: 2,
            totalSpent: 150,
            lastActive: Date()
        ),
        ManagerStudentsView.Student(
            id: "4",
            firstName: "Daniel",
            lastName: "Kim",
            email: "daniel.k@example.com",
            phoneNumber: "(555) 654-3210",
            joinDate: Date().addingTimeInterval(-7_776_000), // ~3 months ago
            profileImageURL: nil,
            activeClasses: 0,
            totalSpent: 500,
            lastActive: Date().addingTimeInterval(-1_209_600) // 2 weeks ago
        )
    ]
    
    // Mock Dashboard Activities
    static let activities: [ManagerDashboard.RecentActivity] = [
        ManagerDashboard.RecentActivity(
            title: "New Student",
            description: "Emily Davis joined as a student",
            date: Date().addingTimeInterval(-86_400), // Yesterday
            type: .newStudent
        ),
        ManagerDashboard.RecentActivity(
            title: "New Coach",
            description: "Michael Chen joined as a coach",
            date: Date().addingTimeInterval(-172_800), // 2 days ago
            type: .newCoach
        ),
        ManagerDashboard.RecentActivity(
            title: "New Booking",
            description: "James Wilson booked a class with Sarah Johnson",
            date: Date().addingTimeInterval(-259_200), // 3 days ago
            type: .classBooked
        ),
        ManagerDashboard.RecentActivity(
            title: "Payment",
            description: "Sophia Garcia purchased 50 credits",
            date: Date().addingTimeInterval(-345_600), // 4 days ago
            type: .payment
        )
    ]
}

// Helper extension to create formatted date strings for previews
extension Date {
    static func formattedPreviewDate(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
} 