import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Charts

// Feature card for dashboard main view
struct ManagerFeatureCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
    @State private var isManager: Bool = true
    @State private var isSuperManager: Bool = false
    
    // Navigation states
    @State private var showingCoachSchedule = false
    @State private var showingStudentCredits = false
    @State private var showingMonthlyReports = false
    
    // Preview-only initializer
    init(previewData: (userName: String, students: Int, coaches: Int, revenue: Int, activities: [RecentActivity])? = nil) {
        if let data = previewData {
            _userName = State(initialValue: data.userName)
            _isLoading = State(initialValue: false)
            _totalStudents = State(initialValue: data.students)
            _totalCoaches = State(initialValue: data.coaches)
            _monthlyRevenue = State(initialValue: data.revenue)
            _recentActivities = State(initialValue: data.activities)
        }
    }
    
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
                VStack(spacing: 24) {
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
                    
                    
                    // Main features
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Coach Schedule feature
                        ManagerFeatureCard(
                            title: "View Coach Schedules",
                            icon: "calendar.badge.clock",
                            color: TailwindColors.violet500
                        ) {
                            showingCoachSchedule = true
                        }
                        .padding(.horizontal)
                        
                        // Student Credits feature
                        ManagerFeatureCard(
                            title: "Student Credits",
                            icon: "creditcard.fill",
                            color: TailwindColors.blue500
                        ) {
                            showingStudentCredits = true
                        }
                        .padding(.horizontal)
                        
                        // Monthly Reports feature (only for super managers)
                
                        ManagerFeatureCard(
                            title: "View Monthly Reports",
                            icon: "chart.bar.doc.horizontal",
                            color: TailwindColors.green500
                        ) {
                            showingMonthlyReports = true
                        }
                        .padding(.horizontal)
                        
                    }
                
                }
               
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
            .sheet(isPresented: $showingCoachSchedule) {
                CoachScheduleView()
            }
            .sheet(isPresented: $showingStudentCredits) {
                StudentCreditsView()
            }
            .sheet(isPresented: $showingMonthlyReports) {
                MonthlyReportsView()
            }
        }
    }
    
    private func loadDashboardData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        
        // Load user info
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                if let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String {
                    self.userName = "\(firstName) \(lastName)"
                }
                
                // Check if the user is a super manager
                if let role = data["role"] as? String {
                    self.isSuperManager = role == "SuperManager"
                }
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

// Coach Schedule View
struct CoachScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coaches: [Coach] = []
    @State private var isLoading = true
    @State private var selectedCoach: Coach?
    
    struct Coach: Identifiable {
        let id: String
        let name: String
        let email: String
        
        var initials: String {
            let components = name.components(separatedBy: " ")
            if components.count >= 2,
               let first = components.first?.first,
               let last = components.last?.first {
                return "\(first)\(last)"
            }
            return name.prefix(2).uppercased()
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading coaches...")
                } else if coaches.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No coaches available")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                } else {
                    List {
                        ForEach(coaches) { coach in
                            Button(action: {
                                selectedCoach = coach
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(TailwindColors.violet100)
                                            .frame(width: 50, height: 50)
                                        
                                        Text(coach.initials)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(TailwindColors.violet600)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(coach.name)
                                            .font(.headline)
                                        
                                        Text(coach.email)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Coach Schedules")
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Text("Close")
            })
            .sheet(item: $selectedCoach) { coach in
                CoachCalendarView(coach: coach)
            }
            .onAppear {
                loadCoaches()
            }
        }
    }
    
    private func loadCoaches() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("role", isEqualTo: "Coach")
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    print("Error loading coaches: \(error)")
                    return
                }
                
                coaches = snapshot?.documents.compactMap { document -> Coach? in
                    let data = document.data()
                    guard let firstName = data["firstName"] as? String,
                          let lastName = data["lastName"] as? String,
                          let email = data["email"] as? String else {
                        return nil
                    }
                    
                    return Coach(
                        id: document.documentID,
                        name: "\(firstName) \(lastName)",
                        email: email
                    )
                } ?? []
            }
    }
}

// Coach Calendar View
struct CoachCalendarView: View {
    let coach: CoachScheduleView.Coach
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var classes: [ClassEvent] = []
    @State private var isLoading = true
    @State private var showingAddEvent = false
    
    struct ClassEvent: Identifiable {
        let id: String
        let title: String
        let time: String
        let studentName: String
        let date: Date
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Calendar view
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                if isLoading {
                    ProgressView("Loading schedule...")
                    Spacer()
                } else {
                    // Classes for selected date
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Classes on \(selectedDate, formatter: dateFormatter)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if filterClassesForSelectedDate().isEmpty {
                            VStack {
                                Text("No classes scheduled for this date")
                                    .foregroundColor(.gray)
                                    .padding()
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(filterClassesForSelectedDate()) { classEvent in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(classEvent.title)
                                            .font(.headline)
                                        
                                        HStack {
                                            Image(systemName: "clock")
                                            Text(classEvent.time)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "person")
                                            Text(classEvent.studentName)
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
            }
            .navigationTitle("\(coach.name)'s Schedule")
            .navigationBarItems(
                leading: Button("Close") { dismiss() },
                trailing: Button(action: {
                    showingAddEvent = true
                }) {
                    Label("Add Event", systemImage: "plus")
                }
            )
            .onChange(of: selectedDate) { _ in
                // Will trigger reload if needed
            }
            .onAppear {
                loadCoachClasses()
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(coach: coach, date: selectedDate)
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func filterClassesForSelectedDate() -> [ClassEvent] {
        return classes.filter { isSameDay(date1: $0.date, date2: selectedDate) }
    }
    
    private func isSameDay(date1: Date, date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    private func loadCoachClasses() {
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("classes")
            .whereField("coachId", isEqualTo: coach.id)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    print("Error loading coach classes: \(error)")
                    return
                }
                
                classes = snapshot?.documents.compactMap { document -> ClassEvent? in
                    let data = document.data()
                    guard let title = data["className"] as? String,
                          let time = data["classTime"] as? String,
                          let studentName = data["studentName"] as? String,
                          let timestamp = data["date"] as? Timestamp else {
                        return nil
                    }
                    
                    return ClassEvent(
                        id: document.documentID,
                        title: title,
                        time: time,
                        studentName: studentName,
                        date: timestamp.dateValue()
                    )
                } ?? []
            }
    }
}

// Add Event View (placeholder)
struct AddEventView: View {
    let coach: CoachScheduleView.Coach
    let date: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Add event UI goes here")
                .navigationTitle("Add Class")
                .navigationBarItems(leading: Button("Cancel") {
                    dismiss()
                })
        }
    }
}

// Student Credits View
struct StudentCreditsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var students: [Student] = []
    @State private var isLoading = true
    @State private var selectedStudent: Student?
    @State private var searchText = ""
    
    struct Student: Identifiable {
        let id: String
        let name: String
        let email: String
        let creditBalance: Int
        
        var initials: String {
            let components = name.components(separatedBy: " ")
            if components.count >= 2,
               let first = components.first?.first,
               let last = components.last?.first {
                return "\(first)\(last)"
            }
            return name.prefix(2).uppercased()
        }
    }
    
    var filteredStudents: [Student] {
        if searchText.isEmpty {
            return students
        } else {
            return students.filter { student in
                student.name.lowercased().contains(searchText.lowercased()) ||
                student.email.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search students", text: $searchText)
                        .disableAutocorrection(true)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading students...")
                    Spacer()
                } else if students.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No students found")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredStudents) { student in
                            Button(action: {
                                selectedStudent = student
                            }) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(TailwindColors.blue100)
                                            .frame(width: 50, height: 50)
                                        
                                        Text(student.initials)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(TailwindColors.blue600)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(student.name)
                                            .font(.headline)
                                        
                                        Text(student.email)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("\(student.creditBalance)")
                                            .font(.headline)
                                            .foregroundColor(student.creditBalance > 0 ? .green : .red)
                                        
                                        Text("credits")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Student Credits")
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Text("Close")
            })
            .sheet(item: $selectedStudent) { student in
                StudentDetailView3(student: student)
            }
            .onAppear {
                loadStudents()
            }
        }
    }
    
    private func loadStudents() {
        isLoading = true
        
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
                    let studentId = document.documentID
                    let data = document.data()
                    
                    guard let firstName = data["firstName"] as? String,
                          let lastName = data["lastName"] as? String,
                          let email = data["email"] as? String else {
                        continue
                    }
                    
                    group.enter()
                    // Get credit balance
                    db.collection("credits")
                        .whereField("studentId", isEqualTo: studentId)
                        .getDocuments { snapshot, error in
                            defer { group.leave() }
                            
                            var totalCredits = 0
                            for document in snapshot?.documents ?? [] {
                                if let credits = document.data()["amount"] as? Int {
                                    totalCredits += credits
                                }
                            }
                            
                            loadedStudents.append(Student(
                                id: studentId,
                                name: "\(firstName) \(lastName)",
                                email: email,
                                creditBalance: totalCredits
                            ))
                        }
                }
                
                group.notify(queue: .main) {
                    self.students = loadedStudents.sorted(by: { $0.name < $1.name })
                    self.isLoading = false
                }
            }
    }
}

// Student Detail View
struct StudentDetailView3: View {
    let student: StudentCreditsView.Student
    @Environment(\.dismiss) private var dismiss
    @State private var primaryCoach: String = "Not assigned"
    @State private var scheduledClasses: [ClassType] = []
    @State private var hoursPerWeek: Double = 0.0
    @State private var showingAddCredit = false
    
    struct ClassType: Identifiable {
        let id = UUID()
        let type: String
        let count: Int
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Student header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(TailwindColors.blue100)
                                .frame(width: 80, height: 80)
                            
                            Text(student.initials)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(TailwindColors.blue600)
                        }
                        
                        Text(student.name)
                            .font(.system(size: 24, weight: .bold))
                        
                        Text(student.email)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical)
                    
                    // Detail cards
                    VStack(spacing: 16) {
                        DetailRow(label: "Primary Coach", value: primaryCoach)
                        DetailRow(label: "Hours per week", value: String(format: "%.1f", hoursPerWeek))
                        
                        // Credit balance card
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Credit Balance")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Text("\(student.creditBalance)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(student.creditBalance > 0 ? .green : .red)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingAddCredit = true
                            }) {
                                Text("Add Credits")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(TailwindColors.green500)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    
                    // Scheduled class types
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Scheduled Classes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(scheduledClasses) { classType in
                            HStack {
                                Text(classType.type)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(classType.count)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Student Details")
            .navigationBarItems(leading: Button("Close") {
                dismiss()
            })
            .onAppear {
                loadStudentDetails()
            }
            .sheet(isPresented: $showingAddCredit) {
                AddCreditView(student: student)
            }
        }
    }
    
    private func loadStudentDetails() {
        // Placeholder for loading student details
        // In a real app, you would fetch this from Firestore
        
        // Example data
        primaryCoach = "Sarah Johnson"
        scheduledClasses = [
            ClassType(type: "Private Lessons", count: 2),
            ClassType(type: "Group Classes", count: 1),
            ClassType(type: "Camp", count: 0)
        ]
        hoursPerWeek = 1.5
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// Add Credit View
struct AddCreditView: View {
    let student: StudentCreditsView.Student
    @Environment(\.dismiss) private var dismiss
    @State private var creditAmount = ""
    @State private var paymentMethod = 0
    @State private var checkNumber = ""
    @State private var isLoading = false
    
    let paymentMethods = ["Cash", "Check", "Credit Card"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Credits")) {
                    TextField("Amount", text: $creditAmount)
                        .keyboardType(.numberPad)
                    
                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(0..<paymentMethods.count, id: \.self) { index in
                            Text(paymentMethods[index])
                        }
                    }
                    
                    if paymentMethod == 1 { // Check
                        TextField("Check Number", text: $checkNumber)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section {
                    Button(action: addCredits) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Add Credits")
                        }
                    }
                }
            }
            .navigationTitle("Add Credits")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    private func addCredits() {
        guard let amount = Int(creditAmount), amount > 0 else {
            return
        }
        
        isLoading = true
        
        // Add to Firestore
        let db = Firestore.firestore()
        let creditData: [String: Any] = [
            "studentId": student.id,
            "studentName": student.name,
            "amount": amount,
            "paymentMethod": paymentMethods[paymentMethod],
            "checkNumber": paymentMethod == 1 ? checkNumber : "",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("credits").addDocument(data: creditData) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("Error adding credits: \(error)")
                    return
                }
                
                dismiss()
            }
        }
    }
}

// Monthly Reports View (placeholder - only for SuperManager)
struct MonthlyReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reports: [MonthlyReport] = []
    @State private var isLoading = true
    @State private var selectedReport: MonthlyReport?
    
    struct MonthlyReport: Identifiable {
        let id = UUID()
        let month: String
        let year: Int
        let studentIncome: Int
        let coachPayments: Int
        let grossRevenue: Int
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading reports...")
                    Spacer()
                } else if reports.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No monthly reports available")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(reports) { report in
                            Button(action: {
                                selectedReport = report
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(report.month) \(report.year)")
                                            .font(.headline)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("$\(report.grossRevenue)")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Monthly Reports")
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Text("Close")
            })
            .sheet(item: $selectedReport) { report in
                MonthlyReportDetailView(report: report)
            }
            .onAppear {
                loadReports()
            }
        }
    }
    
    private func loadReports() {
        // Placeholder - would load from Firebase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.reports = [
                MonthlyReport(month: "January", year: 2023, studentIncome: 5000, coachPayments: 3500, grossRevenue: 1500),
                MonthlyReport(month: "February", year: 2023, studentIncome: 5500, coachPayments: 3800, grossRevenue: 1700),
                MonthlyReport(month: "March", year: 2023, studentIncome: 6000, coachPayments: 4200, grossRevenue: 1800)
            ]
            self.isLoading = false
        }
    }
}

// Monthly Report Detail View (placeholder)
struct MonthlyReportDetailView: View {
    let report: MonthlyReportsView.MonthlyReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Monthly report detail goes here")
                .navigationTitle("\(report.month) \(report.year)")
                .navigationBarItems(leading: Button("Close") {
                    dismiss()
                })
        }
    }
}

struct ManagerDashboard_Previews: PreviewProvider {
    static var previews: some View {
        ManagerDashboard(
            previewData: (
                userName: "John Manager",
                students: 24,
                coaches: 8,
                revenue: 3500,
                activities: MockData.activities
            )
        )
        .environmentObject(MockAuthViewModel(role: .manager))
    }
} 
