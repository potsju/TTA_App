import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Charts

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Spacer()
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct ManagerDashboard: View {
    @State private var userName: String = "Manager"
    @State private var isLoading = true
    @State private var totalStudents: Int = 0
    @State private var totalCoaches: Int = 0
    @State private var monthlyRevenue: Int = 0
    @State private var recentActivities: [RecentActivity] = []
    
    struct RecentActivity: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let date: Date
        let type: ActivityType
        
        enum ActivityType {
            case newStudent
            case newCoach
            case payment
            case classBooked
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text(userName)
                                .font(.system(size: 24, weight: .bold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Stats Section
                    HStack(spacing: 10) {
                        // Students Card
                        DashboardStatCard(
                            title: "Students",
                            value: isLoading ? "-" : "\(totalStudents)",
                            icon: "person.2.fill",
                            color: .blue
                        )
                        
                        // Coaches Card
                        DashboardStatCard(
                            title: "Coaches", 
                            value: isLoading ? "-" : "\(totalCoaches)",
                            icon: "person.3.fill", 
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 10) {
                        // Revenue Card
                        DashboardStatCard(
                            title: "Monthly Revenue",
                            value: isLoading ? "-" : "\(monthlyRevenue) credits",
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        
                        // Navigate to Reports
                        NavigationLink(destination: ManagerReportsView()) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("View Reports")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(TailwindColors.violet500)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(height: 100)
                    }
                    .padding(.horizontal)
                    
                    // Recent Activity Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if recentActivities.isEmpty {
                            Text("No recent activity")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(recentActivities) { activity in
                                ActivityRow(activity: activity)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadDashboardData()
            }
            .refreshable {
                loadDashboardData()
            }
        }
    }
    
    private func loadDashboardData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        
        // Load user info
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let firstName = data["firstName"] as? String,
               let lastName = data["lastName"] as? String {
                self.userName = "\(firstName) \(lastName)"
            }
        }
        
        // Count students
        db.collection("users").whereField("role", isEqualTo: "Student").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting students: \(error)")
                return
            }
            
            self.totalStudents = snapshot?.documents.count ?? 0
        }
        
        // Count coaches
        db.collection("users").whereField("role", isEqualTo: "Coach").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting coaches: \(error)")
                return
            }
            
            self.totalCoaches = snapshot?.documents.count ?? 0
        }
        
        // Calculate monthly revenue (based on bookings)
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        db.collection("bookings")
            .whereField("timestamp", isGreaterThan: startOfMonth)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting monthly revenue: \(error)")
                    return
                }
                
                var revenue = 0
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    if let amount = data["credits"] as? Int {
                        revenue += amount
                    } else if let amount = data["cost"] as? Int {
                        revenue += amount
                    } else if let amount = data["amount"] as? Int {
                        revenue += amount
                    }
                }
                
                self.monthlyRevenue = revenue
                
                // After all data is loaded, set loading to false
                self.isLoading = false
            }
        
        // Load recent activities
        loadRecentActivities()
    }
    
    private func loadRecentActivities() {
        let db = Firestore.firestore()
        var activities: [RecentActivity] = []
        
        // Get recent user signups
        db.collection("users")
            .order(by: "createdAt", descending: true)
            .limit(to: 5)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading recent users: \(error)")
                    return
                }
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    if let createdAt = data["createdAt"] as? Timestamp,
                       let firstName = data["firstName"] as? String,
                       let lastName = data["lastName"] as? String,
                       let role = data["role"] as? String {
                        
                        let date = createdAt.dateValue()
                        
                        if role == "Student" {
                            activities.append(RecentActivity(
                                title: "New Student",
                                description: "\(firstName) \(lastName) joined as a student",
                                date: date,
                                type: .newStudent
                            ))
                        } else if role == "Coach" {
                            activities.append(RecentActivity(
                                title: "New Coach",
                                description: "\(firstName) \(lastName) joined as a coach",
                                date: date,
                                type: .newCoach
                            ))
                        }
                    }
                }
                
                // Get recent bookings
                db.collection("bookings")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 5)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error loading recent bookings: \(error)")
                            return
                        }
                        
                        for document in snapshot?.documents ?? [] {
                            let data = document.data()
                            if let timestamp = data["timestamp"] as? Timestamp,
                               let studentName = data["studentName"] as? String,
                               let coachName = data["coachName"] as? String {
                                
                                activities.append(RecentActivity(
                                    title: "New Booking",
                                    description: "\(studentName) booked a class with \(coachName)",
                                    date: timestamp.dateValue(),
                                    type: .classBooked
                                ))
                            }
                        }
                        
                        // Sort all activities by date and update the UI
                        self.recentActivities = activities.sorted(by: { $0.date > $1.date }).prefix(10).map { $0 }
                    }
            }
    }
}

struct ActivityRow: View {
    let activity: ManagerDashboard.RecentActivity
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.headline)
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(activity.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch activity.type {
        case .newStudent:
            return "person.fill.badge.plus"
        case .newCoach:
            return "person.3.fill"
        case .payment:
            return "dollarsign.circle.fill"
        case .classBooked:
            return "calendar.badge.clock"
        }
    }
    
    private var iconBackgroundColor: Color {
        switch activity.type {
        case .newStudent:
            return Color.blue.opacity(0.2)
        case .newCoach:
            return Color.purple.opacity(0.2)
        case .payment:
            return Color.green.opacity(0.2)
        case .classBooked:
            return Color.orange.opacity(0.2)
        }
    }
    
    private var iconColor: Color {
        switch activity.type {
        case .newStudent:
            return .blue
        case .newCoach:
            return .purple
        case .payment:
            return .green
        case .classBooked:
            return .orange
        }
    }
}

struct ManagerDashboard_Previews: PreviewProvider {
    static var previews: some View {
        ManagerDashboard()
    }
} 
