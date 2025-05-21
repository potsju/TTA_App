import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Observation

struct CoachCalendarClassesView: View {
    @State private var selectedDate: Int = 19
    @State private var currentMonth: String = "September 2021"
    @State private var classService = ClassService()
    @State private var showingCreateClass = false
    @State private var selectedFilter: ClassFilter = .all
    @State private var isLoading = false
    @State private var userName: String = "Coach"
    @State private var showingDeleteAlert = false
    @State private var showingEditClass = false
    @State private var classToDelete: Class?
    @State private var classToEdit: Class?
    private let calendar = Calendar.current
    
    enum ClassFilter {
        case all, available, booked
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            // Calendar section
                            VStack(alignment: .center, spacing: 0) {
                                CalendarView(
                                    selectedDate: $selectedDate,
                                    currentMonth: $currentMonth
                                )
                                .padding(.horizontal, 24)
                                .padding(.top, 64)
                            }
                            .frame(maxWidth: 306)

                            // Filter Picker
                            Picker("Filter", selection: $selectedFilter) {
                                Text("All Classes").tag(ClassFilter.all)
                                Text("Available").tag(ClassFilter.available)
                                Text("Booked").tag(ClassFilter.booked)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 8)

                            // Classes section
                            HStack {
                                Text(getSectionTitle())
                                    .font(.system(size: 30, weight: .bold))
                                
                                Spacer()
                                
                                // Create Class button
                                Button {
                                    print("DEBUG: Creating class with instructor name: \(userName)")
                                    // Print user ID for debugging
                                    if let userId = Auth.auth().currentUser?.uid {
                                        print("DEBUG: Current user ID (for createdBy field): \(userId)")
                                    }
                                    showingCreateClass = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16))
                                        Text("Create Class")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(TailwindColors.violet600)
                                    .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 28)
                            .padding(.bottom, 8)

                            if isLoading {
                                ProgressView()
                                    .padding()
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(getFilteredClasses()) { classItem in
                                        CoachClassItem(classItem: classItem, onDelete: {
                                            classToDelete = classItem
                                            showingDeleteAlert = true
                                        }, onEdit: {
                                            // Print debug info about the class being edited
                                            print("DEBUG: Editing class with ID: \(classItem.id)")
                                            print("DEBUG: Class creator ID: \(classItem.createdBy ?? "nil")")
                                            print("DEBUG: Current user ID: \(Auth.auth().currentUser?.uid ?? "nil")")
                                            print("DEBUG: Instructor name on class: \(classItem.instructorName)")
                                            
                                            classToEdit = classItem
                                            showingEditClass = true
                                        })
                                    }
                                }
                                .frame(maxWidth: 328)
                                .padding(.bottom, 20)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .task {
                print("DEBUG: Starting initial tasks in CoachCalendarClassesView")
                // First load user info
                await loadUserInfo()
                print("DEBUG: After loadUserInfo, userName is: \(userName)")
                
                // Then refresh classes in a separate task to prevent blocking
                Task {
                    print("DEBUG: Starting initial class refresh")
                    await refreshClasses()
                    print("DEBUG: Completed initial class refresh")
                }
            }
            .sheet(isPresented: $showingCreateClass) {
                CreateClassView(
                    selectedDate: getSelectedDate(), 
                    instructorName: userName.isEmpty ? "Coach" : userName,
                    onClassCreated: {
                        handleClassCreated()
                    }
                )
            }
            .sheet(isPresented: $showingEditClass) {
                if let classItem = classToEdit {
                    EditClassView(classItem: classItem, instructorName: userName) { updatedClass in
                        handleClassEdited()
                    }
                }
            }
            .onChange(of: selectedDate) { _ in
                Task {
                    await refreshClasses()
                }
            }
            .alert("Delete Class", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let classItem = classToDelete {
                        Task {
                            await deleteClass(classItem)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this class? This action cannot be undone.")
            }
        }
    }
    
    private func loadUserInfo() async {
        print("DEBUG: Starting loadUserInfo()")
        
        // Try local storage first with a timeout
        let localLoadTask = Task {
            if let profileData = UserDefaults.standard.data(forKey: "userProfile") {
                print("DEBUG: Found profile data in UserDefaults, size: \(profileData.count) bytes")
                
                do {
                    let userProfile = try JSONDecoder().decode(UserProfile.self, from: profileData)
                    print("DEBUG: Successfully decoded profile, firstName: \(userProfile.firstName), lastName: \(userProfile.lastName)")
                    
                    await MainActor.run {
                        self.userName = "\(userProfile.firstName) \(userProfile.lastName)"
                        print("DEBUG: Loaded name from profile: \(self.userName)")
                    }
                    return true
                } catch {
                    print("Error decoding profile: \(error)")
                    // Try to inspect the data that failed to decode
                    if let profileString = String(data: profileData, encoding: .utf8) {
                        print("DEBUG: Profile data content: \(profileString)")
                    }
                }
            } else {
                print("DEBUG: No userProfile data found in UserDefaults")
            }
            return false
        }
        
        // Use a timeout for the local load
        let localSuccess: Bool
        do {
            let result = try await localLoadTask.result.get()
            localSuccess = result
        } catch {
            print("DEBUG: Local profile load timed out or failed: \(error)")
            localSuccess = false
        }
        
        if localSuccess {
            print("DEBUG: Successfully loaded user info from local storage")
            return
        }
        
        // If local load failed, try Firestore
        print("DEBUG: Trying Firestore for user info")
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("DEBUG: No user ID found")
            return 
        }

        do {
            print("DEBUG: Trying to load user data from Firestore for ID: \(userId)")
            let db = Firestore.firestore()
            
            // Add a timeout for the Firestore request
            let firestoreTask = Task {
                return try await db.collection("users").document(userId).getDocument()
            }
            
            // Wait for Firestore data with timeout
            let document: DocumentSnapshot
            do {
                document = try await firestoreTask.value
            } catch {
                print("DEBUG: Firestore request timed out or failed: \(error)")
                return
            }
            
            if document.exists, let data = document.data() {
                print("DEBUG: User document found in Firestore with data: \(data)")
                
                if let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String {
                    // Save profile data to UserDefaults for future use
                    let userProfile = UserProfile(
                        id: userId,
                        firstName: firstName,
                        lastName: lastName,
                        role: data["role"] as? String ?? "Coach"
                        // Add other fields as needed
                    )
                    
                    do {
                        let encodedData = try JSONEncoder().encode(userProfile)
                        UserDefaults.standard.set(encodedData, forKey: "userProfile")
                        print("DEBUG: Saved profile to UserDefaults: \(firstName) \(lastName)")
                    } catch {
                        print("DEBUG: Failed to encode user profile: \(error)")
                    }
                    
                    await MainActor.run {
                        self.userName = "\(firstName) \(lastName)"
                        print("DEBUG: Set userName from Firestore: \(self.userName)")
                    }
                } else {
                    print("DEBUG: No firstName or lastName found in Firestore document")
                }
            } else {
                print("DEBUG: User document not found in Firestore")
            }
        } catch {
            print("Error loading user info from Firestore: \(error)")
        }
        
        print("DEBUG: Completed loadUserInfo()")
    }
    
    private func refreshClasses() async {
        print("DEBUG: CoachCalendarClassesView refreshing classes")
        isLoading = true
        
        // Load user info if needed
        if userName.isEmpty {
            await loadUserInfo()
        }
        
        // Use the ClassService's loadAllClasses method to refresh
        await classService.loadAllClasses()
        
        // Update UI
        await MainActor.run {
            isLoading = false
            
            // Check what we have after filtering
            let filteredClasses = getFilteredClasses()
            print("DEBUG: CoachCalendarClassesView has \(filteredClasses.count) classes after filtering")
        }
    }
    
    private func getSelectedDate() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = calendar.component(.year, from: Date())
        components.month = calendar.component(.month, from: Date())
        components.day = selectedDate
        
        let date = calendar.date(from: components) ?? Date()
        print("DEBUG: Selected date is \(date) with day \(selectedDate)")
        return date
    }
    
    private func getSectionTitle() -> String {
        switch selectedFilter {
        case .all:
            return "All Your Classes"
        case .available:
            return "Available Classes"
        case .booked:
            return "Booked Classes"
        }
    }
    
    private func getFilteredClasses() -> [Class] {
        let date = getSelectedDate()
        print("DEBUG: CoachCalendarClassesView filtering for date: \(date)")
        
        // Get classes for the selected date
        let dateClasses = classService.getClassesForDate(date)
        print("DEBUG: CoachCalendarClassesView found \(dateClasses.count) classes for date \(date)")
        
        // For debugging, log the classes we found
        if dateClasses.isEmpty {
            print("DEBUG: No classes found for date \(date)")
        } else {
            for (index, classItem) in dateClasses.enumerated() {
                print("DEBUG: Class \(index): \(classItem.id) - \(classItem.instructorName) - \(classItem.formattedDate)")
            }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            return dateClasses
        case .available:
            return dateClasses.filter { $0.isAvailable }
        case .booked:
            return dateClasses.filter { !$0.isAvailable }
        }
    }
    
    private func deleteClass(_ classItem: Class) async {
        do {
            try await classService.deleteClass(classItem)
            await refreshClasses()
        } catch {
            print("ERROR: Failed to delete class: \(error)")
        }
    }
    
    private func handleClassCreated() {
        print("DEBUG: CoachCalendarClassesView - class created, refreshing view")
        Task {
            await refreshClasses()
        }
    }
    
    private func handleClassEdited() {
        print("DEBUG: CoachCalendarClassesView - class edited, refreshing view")
        Task {
            await refreshClasses()
        }
    }
}

struct CoachClassItem: View {
    let classItem: Class
    let onDelete: () -> Void
    var onEdit: () -> Void
    @State private var displayName: String = ""
    @State private var studentName: String = ""
    @State private var showingStudentProfile = false
    @State private var showingFinishConfirmation = false
    @State private var isMarkingFinished = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Time
                VStack(alignment: .leading) {
                    Text(classItem.classTime)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Show the appropriate name
                    Text(getDisplayName())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        
                    Text("\(classItem.creditCost) credits")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status badge
                Text(classItem.status)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(getStatusColor(for: classItem.status))
                    .foregroundColor(getStatusTextColor(for: classItem.status))
                    .cornerRadius(8)
            }
            
            // Divider
            Divider()
                .padding(.vertical, 4)
            
            // Student info for booked classes
            if !classItem.isAvailable && !classItem.isFinished, let studentId = classItem.studentId {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(TailwindColors.violet600)
                        
                        Text("Student:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(studentName.isEmpty ? "Loading..." : studentName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(TailwindColors.violet800)
                        
                        Spacer()
                        
                        Button {
                            showingStudentProfile = true
                        } label: {
                            Text("View Profile")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(TailwindColors.violet600)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
            
            // Student info for finished classes
            if classItem.isFinished, let studentId = classItem.studentId {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(TailwindColors.green600)
                        
                        Text("Completed with:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(studentName.isEmpty ? "Loading..." : studentName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(TailwindColors.green800)
                        
                        Spacer()
                        
                        Button {
                            showingStudentProfile = true
                        } label: {
                            Text("View Profile")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(TailwindColors.green600)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
            
            // Footer with date and action buttons
            HStack {
                Text(classItem.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Mark as Complete button (only for booked, not finished classes)
                if !classItem.isAvailable && !classItem.isFinished {
                    Button(action: {
                        showingFinishConfirmation = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                            Text("Complete")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(TailwindColors.green600)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(TailwindColors.green100)
                        .cornerRadius(12)
                    }
                    .padding(.trailing, 8)
                }
                
                // Edit button (only for available or booked classes)
                if !classItem.isFinished {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(TailwindColors.violet600)
                    }
                    .padding(.trailing, 12)
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getBorderColor(), lineWidth: 1)
        )
        .task {
            await loadDisplayName()
            if !classItem.isAvailable, let studentId = classItem.studentId {
                await loadStudentName(studentId: studentId)
            }
        }
        .sheet(isPresented: $showingStudentProfile) {
            if let studentId = classItem.studentId {
                StudentDetailView(studentId: studentId)
            }
        }
        .alert("Mark Class as Completed", isPresented: $showingFinishConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete") {
                Task {
                    await markClassAsFinished()
                }
            }
        } message: {
            Text("Are you sure you want to mark this class as completed? This will transfer \(classItem.creditCost) credits to your balance.")
        }
        .overlay(
            Group {
                if isMarkingFinished {
                    ZStack {
                        Color.black.opacity(0.3)
                            .cornerRadius(12)
                        
                        ProgressView()
                            .tint(.white)
                    }
                }
                
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(8)
                    }
                    .transition(.move(edge: .bottom))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                errorMessage = nil
                            }
                        }
                    }
                }
            }
        )
    }
    
    private func markClassAsFinished() async {
        guard !isMarkingFinished else { return }
        
        isMarkingFinished = true
        do {
            let classService = ClassService()
            try await classService.markClassAsFinished(classItem)
            isMarkingFinished = false
        } catch {
            isMarkingFinished = false
            errorMessage = "Failed to mark class as completed: \(error.localizedDescription)"
        }
    }
    
    // Helper function to get the right name to display
    private func getDisplayName() -> String {
        if !displayName.isEmpty {
            return displayName
        }
        
        if classItem.instructorName != "Coach" && !classItem.instructorName.isEmpty {
            return classItem.instructorName
        }
        
        // Fallback to N/A instead of hardcoded name
        return "N/A"
    }
    
    private func getBorderColor() -> Color {
        if classItem.isFinished {
            return TailwindColors.green400
        } else if !classItem.isAvailable {
            return TailwindColors.violet400
        } else {
            return TailwindColors.zinc700
        }
    }
    
    private func getStatusColor(for status: String) -> Color {
        switch status {
        case "Available":
            return TailwindColors.gray200
        case "Booked":
            return TailwindColors.violet200
        case "Completed":
            return TailwindColors.green200
        default:
            return TailwindColors.gray200
        }
    }
    
    private func getStatusTextColor(for status: String) -> Color {
        switch status {
        case "Available":
            return TailwindColors.gray700
        case "Booked":
            return TailwindColors.violet800
        case "Completed":
            return TailwindColors.green800
        default:
            return TailwindColors.gray700
        }
    }
    
    private func loadDisplayName() async {
        if classItem.instructorName == "Coach" || classItem.instructorName.isEmpty {
            // Try to get the profile from local storage
            if let profileData = UserDefaults.standard.data(forKey: "userProfile") {
                do {
                    let userProfile = try JSONDecoder().decode(UserProfile.self, from: profileData)
                    displayName = "\(userProfile.firstName) \(userProfile.lastName)"
                    print("DEBUG: Using name from profile: \(displayName)")
                } catch {
                    print("Error decoding profile: \(error)")
                    displayName = "N/A"
                }
            } else {
                displayName = "N/A"
            }
        }
    }
    
    private func loadStudentName(studentId: String) async {
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(studentId).getDocument()
            
            if document.exists, let data = document.data() {
                if let firstName = data["firstName"] as? String,
                   let lastName = data["lastName"] as? String {
                    await MainActor.run {
                        self.studentName = "\(firstName) \(lastName)"
                    }
                } else {
                    await MainActor.run {
                        self.studentName = "Unknown Student"
                    }
                }
            } else {
                await MainActor.run {
                    self.studentName = "Unknown Student"
                }
            }
        } catch {
            print("ERROR: Failed to load student info: \(error.localizedDescription)")
            await MainActor.run {
                self.studentName = "Error Loading"
            }
        }
    }
}

struct EditClassView: View {
    // MARK: - Properties
    let classItem: Class
    let instructorName: String
    var onClassEdited: ((Class) -> Void)? = nil
    
    @State private var classService = ClassService()
    @State private var actualInstructorName: String
    @Environment(\.dismiss) var dismiss
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var creditCost: Int
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Class Update"
    @State private var isLoading = false
    @State private var isSuccess = false
    @State private var editingInstructorName = false
    
    init(classItem: Class, instructorName: String, onClassEdited: ((Class) -> Void)? = nil) {
        self.classItem = classItem
        self.instructorName = instructorName
        self.onClassEdited = onClassEdited
        
        // Initialize state with existing values
        _startTime = State(initialValue: classItem.startTime)
        _endTime = State(initialValue: classItem.endTime)
        _creditCost = State(initialValue: classItem.creditCost)
        
        // For instructor name, prioritize the existing class's instructor name
        let existingName = classItem.instructorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existingName.isEmpty && existingName != "Coach" {
            _actualInstructorName = State(initialValue: existingName)
        } else {
            _actualInstructorName = State(initialValue: instructorName)
        }
    }
    
    // MARK: - Time Formatting
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Form {
                        Section(header: Text("Class Details")) {
                            // Instructor name with edit option
                            HStack {
                                Text("Instructor:")
                                    .font(.system(size: 16))
                                Spacer()
                                
                                if editingInstructorName {
                                    TextField("Enter your name", text: $actualInstructorName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .autocapitalization(.words)
                                        .disableAutocorrection(true)
                                } else {
                                    Text(actualInstructorName)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Button(action: {
                                    withAnimation {
                                        if editingInstructorName {
                                            // Save the edited name to UserDefaults when done
                                            saveInstructorName()
                                        }
                                        editingInstructorName.toggle()
                                    }
                                }) {
                                    Image(systemName: editingInstructorName ? "checkmark.circle.fill" : "pencil")
                                        .foregroundColor(TailwindColors.violet600)
                                        .padding(.leading, 5)
                                }
                            }
                            
                            HStack {
                                Text("Date:")
                                    .font(.system(size: 16))
                                Spacer()
                                Text(classItem.date, style: .date)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                                .onChange(of: startTime) { newValue in
                                    // If end time is before start time, update it
                                    if endTime < newValue.addingTimeInterval(900) { // At least 15 min later
                                        endTime = newValue.addingTimeInterval(3600) // 1 hour later
                                    }
                                }
                            
                            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                                .onChange(of: endTime) { newValue in
                                    // Ensure end time is after start time
                                    if newValue <= startTime {
                                        endTime = startTime.addingTimeInterval(3600) // 1 hour later
                                    }
                                }
                            
                            // Credit picker with 0 and intervals of 10 up to 150
                            VStack(alignment: .leading) {
                                Text("Credits: \(creditCost)")
                                    .font(.system(size: 16))
                                
                                Picker("Credits", selection: $creditCost) {
                                    ForEach(Array(stride(from: 0, through: 150, by: 10)), id: \.self) { value in
                                        Text("\(value)")
                                    }
                                }
                                .pickerStyle(.wheel)
                            }
                        }
                        
                        Section {
                            Button {
                                updateClass()
                            } label: {
                                Text("Update Class")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .background(isLoading ? Color.gray : Color.blue)
                                    .cornerRadius(8)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .disabled(isLoading)
                }
                
                if isLoading {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Updating class...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(10)
                }
            }
            .navigationTitle("Edit Class")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            }, trailing: Button("Save") {
                updateClass()
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if isSuccess {
                            if let onClassEdited = onClassEdited {
                                onClassEdited(classItem)
                            }
                            dismiss()
                        }
                    }
                )
            }
            .task {
                await loadSavedInstructorName()
            }
        }
    }
    
    private func loadSavedInstructorName() async {
        print("DEBUG EditClassView: Initial instructor name is '\(actualInstructorName)'")
        
        // If using the class's instructor name, we don't need to load from UserDefaults
        if actualInstructorName == classItem.instructorName && !actualInstructorName.isEmpty && actualInstructorName != "Coach" {
            return
        }
        
        // Try to load the saved instructor name from UserDefaults
        if let savedName = UserDefaults.standard.string(forKey: "savedInstructorName"), !savedName.isEmpty {
            print("DEBUG EditClassView: Loaded saved instructor name '\(savedName)' from UserDefaults")
            actualInstructorName = savedName
        }
    }
    
    private func saveInstructorName() {
        let name = actualInstructorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != "Coach" {
            UserDefaults.standard.set(name, forKey: "savedInstructorName")
            print("DEBUG EditClassView: Saved instructor name '\(name)' to UserDefaults")
        }
    }
    
    private func updateClass() {
        isLoading = true
        
        // Trim the instructor name
        let trimmedName = actualInstructorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            alertTitle = "Invalid Input"
            alertMessage = "Instructor name cannot be empty"
            showingAlert = true
            isLoading = false
            return
        }
        
        // Save the instructor name for future use
        if trimmedName != "Coach" {
            UserDefaults.standard.set(trimmedName, forKey: "savedInstructorName")
        }
        
        Task {
            do {
                print("DEBUG EditClassView: Updating class with instructor name: \(trimmedName)")
                print("DEBUG EditClassView: Class creator ID: \(classItem.createdBy ?? "nil")")
                print("DEBUG EditClassView: Current user ID: \(Auth.auth().currentUser?.uid ?? "nil")")
                
                // Print the class details for debugging
                print("DEBUG EditClassView: Class ID: \(classItem.id)")
                print("DEBUG EditClassView: Original instructor name: \(classItem.instructorName)")
                print("DEBUG EditClassView: New instructor name: \(trimmedName)")
                                
                try await classService.updateClass(
                    classItem,
                    newInstructorName: trimmedName,
                    newStartTime: startTime,
                    newEndTime: endTime,
                    newCreditCost: creditCost
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                    isSuccess = true
                    alertTitle = "Success"
                    alertMessage = "Class updated successfully!"
                    showingAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    isSuccess = false
                    alertTitle = "Error"
                    alertMessage = "Failed to update class: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

struct CoachCalendarClassesView_Previews: PreviewProvider {
    static var previews: some View {
        CoachCalendarClassesView()
    }
} 
