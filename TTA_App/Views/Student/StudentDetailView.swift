import SwiftUI
import FirebaseFirestore
import Firebase

struct StudentDetailStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
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

struct Student2: Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let joinDate: Date
    let creditBalance: Int
    let activeClasses: Int
    let profileImageURL: String?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

struct ClassDetails: Identifiable {
    let id: String
    let className: String
    let coachName: String
    let date: Date
    let duration: Int
    let status: ClassStatus
    
    enum ClassStatus: String {
        case upcoming = "Upcoming"
        case completed = "Completed"
        case canceled = "Canceled"
    }
}

struct EnhancedStudentDetailView2: View {
    @Environment(\.dismiss) private var dismiss
    @State private var student: Student2?
    @State private var classes: [ClassDetails] = []
    @State private var isLoading = true
    @State private var selectedSegment = 0
    @State private var showingEditProfile = false
    @State private var showingPurchaseCredits = false
    
    let studentId: String
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        ProgressView("Loading student details...")
                            .padding()
                        Spacer()
                    }
                } else if let student = student {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header with profile info
                            VStack(spacing: 16) {
                                // Profile image
                                if let imageURL = student.profileImageURL, !imageURL.isEmpty {
                                    AsyncImage(url: URL(string: imageURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        profileInitials(student: student)
                                    }
                                } else {
                                    profileInitials(student: student)
                                }
                                
                                // Name and contact info
                                VStack(spacing: 8) {
                                    Text(student.fullName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    HStack {
                                        Label(student.email, systemImage: "envelope")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if !student.phoneNumber.isEmpty {
                                        HStack {
                                            Label(student.phoneNumber, systemImage: "phone")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Text("Member since \(dateFormatter.string(from: student.joinDate))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Action buttons
                                HStack(spacing: 16) {
                                    Button {
                                        showingEditProfile = true
                                    } label: {
                                        Label("Edit Profile", systemImage: "pencil")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(TailwindColors.violet100)
                                            .foregroundColor(TailwindColors.violet600)
                                            .cornerRadius(8)
                                    }
                                    
                                    Button {
                                        showingPurchaseCredits = true
                                    } label: {
                                        Label("Buy Credits", systemImage: "plus.circle")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(TailwindColors.green100)
                                            .foregroundColor(TailwindColors.green600)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                            
                            // Student stats
                            HStack(spacing: 12) {
                                // Credit balance
                                StudentDetailStatCard(
                                    title: "Credits",
                                    value: "\(student.creditBalance)",
                                    icon: "creditcard.fill",
                                    color: TailwindColors.green500
                                )
                                
                                // Active classes
                                StudentDetailStatCard(
                                    title: "Active Classes",
                                    value: "\(student.activeClasses)",
                                    icon: "figure.tennis",
                                    color: TailwindColors.blue500
                                )
                            }
                            .padding(.horizontal)
                            
                            // Segment control for classes/history
                            Picker("View", selection: $selectedSegment) {
                                Text("Upcoming").tag(0)
                                Text("History").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            
                            // Classes list
                            VStack(alignment: .leading, spacing: 16) {
                                Text(selectedSegment == 0 ? "Upcoming Classes" : "Past Classes")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                if filteredClasses.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: selectedSegment == 0 ? "calendar.badge.exclamationmark" : "calendar.badge.clock")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        
                                        Text(selectedSegment == 0 ? "No upcoming classes" : "No class history")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                } else {
                                    ForEach(filteredClasses) { classDetail in
                                        classRow(classDetail: classDetail)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .navigationBarTitle("Student Profile", displayMode: .inline)
                    .navigationBarItems(leading: Button("Back") { dismiss() })
                    .sheet(isPresented: $showingEditProfile) {
                        Text("Edit Profile Screen")
                            .navigationTitle("Edit Profile")
                    }
                    .sheet(isPresented: $showingPurchaseCredits) {
                        Text("Purchase Credits Screen")
                            .navigationTitle("Purchase Credits")
                    }
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: selectedSegment) { _ in
                        // Reload classes or trigger animations if needed
                    }
                } else {
                    VStack {
                        Text("Student not found")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
            .onAppear {
                loadStudentData()
            }
        }
    }
    
    private var filteredClasses: [ClassDetails] {
        if selectedSegment == 0 {
            // Upcoming classes
            return classes.filter { $0.status == .upcoming }
        } else {
            // Past classes
            return classes.filter { $0.status != .upcoming }
        }
    }
    
    private func profileInitials(student: Student2) -> some View {
        ZStack {
            Circle()
                .fill(TailwindColors.violet100)
                .frame(width: 100, height: 100)
            
            Text(student.initials)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(TailwindColors.violet600)
        }
    }
    
    private func classRow(classDetail: ClassDetails) -> some View {
        HStack(spacing: 12) {
            // Left icon
            VStack {
                ZStack {
                    Circle()
                        .fill(statusColor(for: classDetail.status).opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 20))
                        .foregroundColor(statusColor(for: classDetail.status))
                }
                
                Spacer()
            }
            .frame(width: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(classDetail.className)
                    .font(.headline)
                
                Text("Coach: \(classDetail.coachName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    
                    Text(dateFormatter.string(from: classDetail.date))
                        .font(.caption)
                    
                    Image(systemName: "clock")
                        .font(.caption)
                    
                    Text("\(classDetail.duration) min")
                        .font(.caption)
                }
                .foregroundColor(.gray)
                
                // Status badge
                Text(classDetail.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(for: classDetail.status).opacity(0.2))
                    .foregroundColor(statusColor(for: classDetail.status))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func statusColor(for status: ClassDetails.ClassStatus) -> Color {
        switch status {
        case .upcoming:
            return TailwindColors.blue500
        case .completed:
            return TailwindColors.green500
        case .canceled:
            return TailwindColors.red500
        }
    }
    
    private func loadStudentData() {
        isLoading = true
        
        // In a real app, fetch the student data from Firestore
        // For this preview, we'll create some sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.student = Student2(
                id: self.studentId,
                firstName: "Emma",
                lastName: "Thompson",
                email: "emma.thompson@example.com",
                phoneNumber: "(555) 123-4567",
                joinDate: Date().addingTimeInterval(-7776000), // 90 days ago
                creditBalance: 25,
                activeClasses: 3,
                profileImageURL: nil
            )
            
            // Sample classes
            self.classes = [
                ClassDetails(
                    id: "class1",
                    className: "Tennis Fundamentals",
                    coachName: "Michael Scott",
                    date: Date().addingTimeInterval(86400 * 2), // 2 days in future
                    duration: 60,
                    status: .upcoming
                ),
                ClassDetails(
                    id: "class2",
                    className: "Advanced Serve Techniques",
                    coachName: "Anna Rodriguez",
                    date: Date().addingTimeInterval(86400 * 5), // 5 days in future
                    duration: 45,
                    status: .upcoming
                ),
                ClassDetails(
                    id: "class3",
                    className: "Backhand Workshop",
                    coachName: "Michael Scott",
                    date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                    duration: 60,
                    status: .completed
                ),
                ClassDetails(
                    id: "class4",
                    className: "Doubles Strategy",
                    coachName: "Sarah Johnson",
                    date: Date().addingTimeInterval(-86400 * 10), // 10 days ago
                    duration: 90,
                    status: .completed
                ),
                ClassDetails(
                    id: "class5",
                    className: "Tournament Prep",
                    coachName: "Michael Scott",
                    date: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                    duration: 120,
                    status: .canceled
                )
            ]
            
            self.isLoading = false
        }
    }
}

struct EnhancedStudentDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            EnhancedStudentDetailView2(studentId: "preview-id")
                .previewDisplayName("Light Mode")
            
            // Dark mode
            EnhancedStudentDetailView2(studentId: "preview-id")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
} 
