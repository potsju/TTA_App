import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ManagerStudentsView: View {
    @State private var students: [Student] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedStudent: Student?
    @State private var showingStudentDetails = false
    @State private var showingAddStudent = false
    @State private var sortOption = SortOption.nameAsc
    @State private var selectedFilter = FilterOption.all
    
    // Preview-only initializer
    init(previewData: [Student]? = nil, isLoading: Bool = true) {
        if let previewData = previewData {
            _students = State(initialValue: previewData)
            _isLoading = State(initialValue: isLoading)
        }
    }
    
    struct Student: Identifiable {
        let id: String
        let firstName: String
        let lastName: String
        let email: String
        let phoneNumber: String
        let joinDate: Date
        let profileImageURL: String?
        let activeClasses: Int
        let totalSpent: Int
        let lastActive: Date?
        
        var fullName: String {
            "\(firstName) \(lastName)"
        }
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case newest = "Newest First"
        case oldest = "Oldest First"
        case mostActive = "Most Active"
        case highestSpending = "Highest Spending"
        
        var id: String { rawValue }
    }
    
    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All Students"
        case active = "Active Students"
        case inactive = "Inactive Students"
        case new = "New (Last 30 Days)"
        
        var id: String { rawValue }
    }
    
    var filteredStudents: [Student] {
        var result = students
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { student in
                student.firstName.lowercased().contains(searchText.lowercased()) ||
                student.lastName.lowercased().contains(searchText.lowercased()) ||
                student.email.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .active:
            result = result.filter { $0.activeClasses > 0 }
        case .inactive:
            result = result.filter { $0.activeClasses == 0 }
        case .new:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            result = result.filter { $0.joinDate > thirtyDaysAgo }
        case .all:
            break
        }
        
        // Apply sorting
        switch sortOption {
        case .nameAsc:
            result.sort { $0.lastName < $1.lastName }
        case .nameDesc:
            result.sort { $0.lastName > $1.lastName }
        case .newest:
            result.sort { $0.joinDate > $1.joinDate }
        case .oldest:
            result.sort { $0.joinDate < $1.joinDate }
        case .mostActive:
            result.sort { $0.activeClasses > $1.activeClasses }
        case .highestSpending:
            result.sort { $0.totalSpent > $1.totalSpent }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Search and filter bar
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search students", text: $searchText)
                                .disableAutocorrection(true)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(InlinePickerStyle())
                            
                            Divider()
                            
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(FilterOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(InlinePickerStyle())
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading students...")
                        Spacer()
                    } else if students.isEmpty {
                        Spacer()
                        VStack(spacing: 15) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No students found")
                                .font(.headline)
                                .padding(.top)
                                
                            Button(action: {
                                showingAddStudent = true
                            }) {
                                Text("Add a Student")
                                    .padding()
                                    .background(TailwindColors.violet500)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        Spacer()
                    } else {
                        // Student list
                        List {
                            ForEach(filteredStudents) { student in
                                StudentRow(student: student)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedStudent = student
                                        showingStudentDetails = true
                                    }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                // FAB for adding a student
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddStudent = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(TailwindColors.violet500)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Students")
            .navigationBarItems(trailing: Button(action: {
                loadStudents()
            }) {
                Image(systemName: "arrow.clockwise")
            })
            .onAppear {
                loadStudents()
            }
            .sheet(isPresented: $showingStudentDetails) {
                if let student = selectedStudent {
                    StudentDetailView2(student: student)
                }
            }
            .sheet(isPresented: $showingAddStudent) {
                AddStudentView(onStudentAdded: {
                    loadStudents()
                })
            }
        }
    }
    
    private func loadStudents() {
        isLoading = true
        students = []
        
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("role", isEqualTo: "Student")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading students: \(error)")
                    isLoading = false
                    return
                }
                
                let group = DispatchGroup()
                var loadedStudents: [Student] = []
                
                for document in snapshot?.documents ?? [] {
                    group.enter()
                    
                    let studentId = document.documentID
                    let data = document.data()
                    
                    let firstName = data["firstName"] as? String ?? ""
                    let lastName = data["lastName"] as? String ?? ""
                    let email = data["email"] as? String ?? ""
                    let phoneNumber = data["phoneNumber"] as? String ?? "Not provided"
                    let profileImageURL = data["profileImageURL"] as? String
                    let joinDate = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Get active classes count
                    group.enter()
                    db.collection("classes")
                        .whereField("studentId", isEqualTo: studentId)
                        .whereField("isAvailable", isEqualTo: false)
                        .whereField("completed", isEqualTo: false)
                        .getDocuments { snapshot, error in
                            defer { group.leave() }
                            
                            let activeClasses = snapshot?.documents.count ?? 0
                            
                            // Get total spent
                            group.enter()
                            db.collection("bookings")
                                .whereField("studentId", isEqualTo: studentId)
                                .getDocuments { snapshot, error in
                                    defer { group.leave() }
                                    
                                    var totalSpent = 0
                                    
                                    for document in snapshot?.documents ?? [] {
                                        let data = document.data()
                                        if let cost = data["cost"] as? Int {
                                            totalSpent += cost
                                        } else if let credits = data["credits"] as? Int {
                                            totalSpent += credits
                                        }
                                    }
                                    
                                    // Get last activity timestamp
                                    group.enter()
                                    db.collection("classes")
                                        .whereField("studentId", isEqualTo: studentId)
                                        .order(by: "date", descending: true)
                                        .limit(to: 1)
                                        .getDocuments { snapshot, error in
                                            defer { group.leave() }
                                            
                                            let lastActive = snapshot?.documents.first.flatMap { 
                                                ($0.data()["date"] as? Timestamp)?.dateValue() 
                                            }
                                            
                                            let student = Student(
                                                id: studentId,
                                                firstName: firstName,
                                                lastName: lastName,
                                                email: email,
                                                phoneNumber: phoneNumber,
                                                joinDate: joinDate,
                                                profileImageURL: profileImageURL,
                                                activeClasses: activeClasses,
                                                totalSpent: totalSpent,
                                                lastActive: lastActive
                                            )
                                            
                                            loadedStudents.append(student)
                                            group.leave() // Leave main enter
                                        }
                                }
                        }
                }
                
                group.notify(queue: .main) {
                    self.students = loadedStudents
                    self.isLoading = false
                }
            }
    }
}

struct StudentRow: View {
    let student: ManagerStudentsView.Student
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile image or initials
            ZStack {
                Circle()
                    .fill(TailwindColors.violet100)
                    .frame(width: 50, height: 50)
                
                Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(TailwindColors.violet600)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(student.fullName)
                    .font(.headline)
                
                Text(student.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(student.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("\(student.activeClasses) classes")
                        .font(.caption)
                }
                .foregroundColor(.gray)
                
                Text("\(student.totalSpent) spent")
                    .font(.caption)
                    .foregroundColor(TailwindColors.green600)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StudentDetailView2: View {
    let student: ManagerStudentsView.Student
    @State private var isLoading = true
    @State private var bookedClasses = 0
    @State private var completedClasses = 0
    @State private var favoriteTutors: [String] = []
    @State private var recentClasses: [StudentClass] = []
    
    struct StudentClass: Identifiable {
        let id: String
        let coachName: String
        let date: Date
        let classTime: String
        let className: String
        let status: String
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Student header
                    VStack {
                        // Profile image or initials
                        ZStack {
                            Circle()
                                .fill(TailwindColors.violet100)
                                .frame(width: 100, height: 100)
                            
                            Text(student.firstName.prefix(1) + student.lastName.prefix(1))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(TailwindColors.violet600)
                        }
                        
                        Text(student.fullName)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 10)
                        
                        Text(student.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text(student.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                        
                        Text("Member since \(student.joinDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding()
                    
                    if isLoading {
                        ProgressView("Loading details...")
                            .padding()
                    } else {
                        // Stats cards
                        HStack(spacing: 12) {
                            StatisticCard(title: "Total Spent", value: "\(student.totalSpent) credits", icon: "dollarsign.circle.fill", color: .green)
                            StatisticCard(title: "Active Classes", value: "\(student.activeClasses)", icon: "calendar.badge.clock", color: .blue)
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            StatisticCard(title: "Booked Classes", value: "\(bookedClasses)", icon: "ticket.fill", color: .orange)
                            StatisticCard(title: "Completed", value: "\(completedClasses)", icon: "checkmark.circle.fill", color: .green)
                        }
                        .padding(.horizontal)
                        
                        // Last activity
                        if let lastActive = student.lastActive {
                            InfoCard(title: "Last Activity", content: {
                                Text("\(lastActive.formatted(date: .long, time: .shortened))")
                                    .font(.subheadline)
                            })
                            .padding(.horizontal)
                        }
                        
                        // Favorite tutors
                        if !favoriteTutors.isEmpty {
                            InfoCard(title: "Favorite Tutors", content: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(favoriteTutors, id: \.self) { tutor in
                                        Text(tutor)
                                            .font(.subheadline)
                                    }
                                }
                            })
                            .padding(.horizontal)
                        }
                        
                        // Recent classes
                        InfoCard(title: "Recent Classes", content: {
                            if recentClasses.isEmpty {
                                Text("No recent classes found")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(recentClasses) { studentClass in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(studentClass.className)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                
                                                Text("with \(studentClass.coachName)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                
                                                HStack {
                                                    Image(systemName: "calendar")
                                                        .font(.caption2)
                                                    Text(studentClass.date.formatted(date: .abbreviated, time: .omitted))
                                                        .font(.caption2)
                                                    
                                                    Image(systemName: "clock")
                                                        .font(.caption2)
                                                    Text(studentClass.classTime)
                                                        .font(.caption2)
                                                }
                                                .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(studentClass.status)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    statusColor(for: studentClass.status)
                                                        .opacity(0.2)
                                                )
                                                .foregroundColor(statusColor(for: studentClass.status))
                                                .cornerRadius(8)
                                        }
                                        .padding(.vertical, 4)
                                        
                                        if recentClasses.last?.id != studentClass.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        })
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Student Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                // This sheet will be dismissed by the presentationMode
            })
            .onAppear {
                loadStudentDetails()
            }
        }
    }
    
    private func loadStudentDetails() {
        isLoading = true
        
        let db = Firestore.firestore()
        let group = DispatchGroup()
        
        // Get booked classes count
        group.enter()
        db.collection("bookings")
            .whereField("studentId", isEqualTo: student.id)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                bookedClasses = snapshot?.documents.count ?? 0
            }
        
        // Get completed classes count
        group.enter()
        db.collection("classes")
            .whereField("studentId", isEqualTo: student.id)
            .whereField("completed", isEqualTo: true)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                completedClasses = snapshot?.documents.count ?? 0
            }
        
        // Get favorite tutors
        group.enter()
        db.collection("classes")
            .whereField("studentId", isEqualTo: student.id)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                var tutorCounts: [String: Int] = [:]
                var tutorNames: [String: String] = [:]
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    if let tutorId = data["coachId"] as? String,
                       let tutorName = data["coachName"] as? String {
                        tutorCounts[tutorId, default: 0] += 1
                        tutorNames[tutorId] = tutorName
                    }
                }
                
                let sortedTutors = tutorCounts.sorted { $0.value > $1.value }
                favoriteTutors = sortedTutors.prefix(3).compactMap { tutorNames[$0.key] }
            }
        
        // Get recent classes
        group.enter()
        db.collection("classes")
            .whereField("studentId", isEqualTo: student.id)
            .order(by: "date", descending: true)
            .limit(to: 5)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                var classes: [StudentClass] = []
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    
                    guard let date = (data["date"] as? Timestamp)?.dateValue(),
                          let coachName = data["coachName"] as? String,
                          let classTime = data["classTime"] as? String else {
                        continue
                    }
                    
                    let className = data["className"] as? String ?? "Music Lesson"
                    let completed = data["completed"] as? Bool ?? false
                    let status = completed ? "Completed" : "Upcoming"
                    
                    classes.append(StudentClass(
                        id: document.documentID,
                        coachName: coachName,
                        date: date,
                        classTime: classTime,
                        className: className,
                        status: status
                    ))
                }
                
                recentClasses = classes
            }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Completed":
            return .green
        case "Upcoming":
            return .blue
        case "Cancelled":
            return .red
        default:
            return .gray
        }
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
            
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct ManagerStudentsView_Previews: PreviewProvider {
    static var previews: some View {
        ManagerStudentsView(
            previewData: MockData.students,
            isLoading: false
        )
        .environmentObject(MockAuthViewModel(role: .manager))
    }
}

struct AddStudentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var onStudentAdded: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Student Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    SecureField("Password", text: $password)
                }
                
                Section {
                    Button(action: createStudent) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create Student Account")
                        }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || email.isEmpty || phoneNumber.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle("Add Student")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func createStudent() {
        isLoading = true
        
        // Create user account
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isLoading = false
                }
                return
            }
            
            guard let userId = result?.user.uid else {
                DispatchQueue.main.async {
                    alertMessage = "Error creating user account"
                    showAlert = true
                    isLoading = false
                }
                return
            }
            
            // Add user profile to database
            let db = Firestore.firestore()
            db.collection("users").document(userId).setData([
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "phoneNumber": phoneNumber,
                "role": "Student",
                "createdAt": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        alertMessage = "Error saving user data: \(error.localizedDescription)"
                        showAlert = true
                        isLoading = false
                        return
                    }
                    
                    // Success - dismiss and refresh
                    isLoading = false
                    onStudentAdded()
                    dismiss()
                }
            }
        }
    }
}

struct AddStudentView_Previews: PreviewProvider {
    static var previews: some View {
        AddStudentView(onStudentAdded: {})
            .environmentObject(MockAuthViewModel(role: .manager))
    }
} 
