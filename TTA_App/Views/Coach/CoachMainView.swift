import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Charts
import Combine
// No need to import StudentComponents as it's part of the same module

// Add a notification publisher for class booking events
extension Notification.Name {
    static let classBookingUpdated = Notification.Name("classBookingUpdated")
}

struct CoachMainView: View {
    @StateObject private var classService = ClassService()
    @State private var selectedTab = 0
    @State private var userName: String = "Coach"
    @State private var isLoading = true
    @State private var students: [Student] = []
    @State private var selectedStudent: Student?
    @State private var showingStudentDetails = false
    @State private var refreshID = UUID()
    @State private var subscriptions = Set<AnyCancellable>()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Dashboard Tab
    
            
            // Classes Tab
            CoachCalendarClassesView()
                .tabItem {
                    Label("Classes", systemImage: "calendar")
                }
                .tag(1)
            
            // Students Tab
            CoachStudentsView()
                .tabItem {
                    Label("Students", systemImage: "person.2")
                }
                .tag(2)
            
            // Profile Tab
            CoachesProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .accentColor(TailwindColors.violet400)
        .onChange(of: selectedTab) { newTab in
            if newTab == 0 {
                refreshID = UUID()
            }
        }
        .onAppear {
            // Set up notification observer for class booking updates
            NotificationCenter.default.publisher(for: .classBookingUpdated)
                .sink { _ in
                    print("DEBUG: Received class booking notification, refreshing dashboard")
                    if selectedTab == 0 {
                        refreshID = UUID() // Refresh immediately if on dashboard
                    }
                }
                .store(in: &subscriptions)
        }
    }
    
    private func getTitle() -> String {
        switch selectedTab {
        case 0:
            return "Dashboard"
        case 1:
            return "Classes"
        case 2:
            return "My Students"
        case 3:
            return "Earnings"
        case 4:
            return "Profile"
        default:
            return "Coach Portal"
        }
    }
    
    // Students Tab
    private var studentsTab: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            if students.isEmpty {
                VStack(spacing: 20) {
                    Text("Your Students")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, 20)
                    
                    Text("Students who book your classes will appear here")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(TailwindColors.violet400)
                        .padding(.vertical, 30)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(students) { student in
                            StudentCard(student: student)
                                .onTapGesture {
                                    selectedStudent = student
                                    showingStudentDetails = true
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }
    
    private func loadStudents() async {
        isLoading = true
        do {
            guard let coachId = Auth.auth().currentUser?.uid else { 
                isLoading = false
                return 
            }
            
            let db = Firestore.firestore()
            
            // Get classes created by this coach that have been booked
            let classesQuery = db.collection("classes")
                .whereField("createdBy", isEqualTo: coachId)
                .whereField("isAvailable", isEqualTo: false)
            
            let classesSnapshot = try await classesQuery.getDocuments()
            
            // Extract unique student IDs
            var studentIds = Set<String>()
            for document in classesSnapshot.documents {
                if let studentId = document.data()["studentId"] as? String, !studentId.isEmpty {
                    studentIds.insert(studentId)
                }
            }
            
            // Get student profiles from Firestore
            var fetchedStudents: [Student] = []
            for studentId in studentIds {
                let userDoc = try await db.collection("users").document(studentId).getDocument()
                
                if let data = userDoc.data(),
                   let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String,
                   let email = data["email"] as? String {
                    
                    let profileImage = data["profileImageURL"] as? String
                    
                    fetchedStudents.append(Student(
                        id: studentId,
                        firstName: firstName,
                        lastName: lastName,
                        email: email,
                        profileImage: profileImage
                    ))
                }
            }
            
            await MainActor.run {
                students = fetchedStudents
                isLoading = false
            }
        } catch {
            print("Error loading students: \(error)")
            isLoading = false
        }
    }
    
    private func loadUserInfo() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                if let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String {
                    await MainActor.run {
                        self.userName = "\(firstName) \(lastName)"
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Error loading user info: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct StudentDetailsView: View {
    let student: Student
    @Environment(\.dismiss) var dismiss
    @State private var bookedClasses: [Class] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Student header
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(TailwindColors.violet100)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(TailwindColors.violet600)
                                    )
                                
                                Text(student.fullName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.top, 20)
                            
                            // Booked classes section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Booked Classes")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                
                                ForEach(bookedClasses) { classItem in
                                    BookedClassItem(classItem: classItem)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .task {
                await loadBookedClasses()
            }
        }
    }
    
    private func loadBookedClasses() async {
        guard let coachId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("classes")
                .whereField("createdBy", isEqualTo: coachId)
                .whereField("studentId", isEqualTo: student.id)
                .whereField("isAvailable", isEqualTo: false)
                .getDocuments()
            
            let classes = snapshot.documents.compactMap { document -> Class? in
                try? document.data(as: Class.self)
            }
            
            await MainActor.run {
                self.bookedClasses = classes
                self.isLoading = false
            }
        } catch {
            print("Error loading booked classes: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct BookedClassItem: View {
    let classItem: Class
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(classItem.classTime)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("\(classItem.creditCost) credits")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("Booked")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(TailwindColors.violet200)
                    .foregroundColor(TailwindColors.violet800)
                    .cornerRadius(8)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Text(classItem.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TailwindColors.zinc700, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct TransactionItem: View {
    let transaction: EarningTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Amount: \(transaction.amount) credits")
                    .font(.headline)
                Spacer()
                Text(transaction.timestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let classTime = transaction.classTime {
                Text("Class Time: \(classTime)")
                    .font(.subheadline)
            }
            
            Text("Student ID: \(transaction.studentId)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let classId = transaction.classId {
                Text("Class ID: \(classId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
        }
        .padding(.vertical, 4)
    }
}

struct StudentProfileCard: View {
    let student: Student
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Image
                    if let profileImage = student.profileImage {
                        AsyncImage(url: URL(string: profileImage)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(TailwindColors.violet400)
                                .overlay(
                                    Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(TailwindColors.violet400)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Student Info
                    VStack(spacing: 8) {
                        Text(student.fullName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(student.email)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    
                    // Additional sections can be added here
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct CoachMainView_Previews: PreviewProvider {
    static var previews: some View {
        CoachMainView()
            .environmentObject(MockAuthViewModel(role: .coach))
    }
} 
