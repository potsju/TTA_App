import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Observation

// Separate time picker view to reduce complexity
struct TimePickerView: View {
    let title: String
    let selection: Binding<Date>
    var minimumDate: Date? = nil
    let onTimeSelected: (Date) -> Void
    
    @State private var showingPicker = false
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: { showingPicker = true }) {
                Text(timeFormatter.string(from: selection.wrappedValue))
                    .foregroundColor(.primary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            TimeSelectionSheet(
                selection: selection,
                minimumDate: minimumDate,
                onTimeSelected: onTimeSelected
            )
        }
    }
}

// Separate sheet for time selection
struct TimeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selection: Binding<Date>
    var minimumDate: Date?
    let onTimeSelected: (Date) -> Void
    @State private var selectedDate: Date
    
    init(selection: Binding<Date>, minimumDate: Date? = nil, onTimeSelected: @escaping (Date) -> Void) {
        self.selection = selection
        self.minimumDate = minimumDate
        self.onTimeSelected = onTimeSelected
        _selectedDate = State(initialValue: selection.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                
                Button("Select") {
                    // Round to nearest 15 minutes
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
                    let minute = components.minute ?? 0
                    let roundedMinute = (minute / 15) * 15
                    
                    var newComponents = components
                    newComponents.minute = roundedMinute
                    if let roundedDate = calendar.date(from: newComponents),
                       minimumDate == nil || roundedDate > minimumDate! {
                        selection.wrappedValue = roundedDate
                        onTimeSelected(roundedDate)
                    }
                    dismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(TailwindColors.violet600)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CreateClassView: View {
    // MARK: - Properties
    let selectedDate: Date
    let instructorName: String
    var onClassCreated: (() -> Void)? = nil
    
    @State private var classService = ClassService()
    @State private var actualInstructorName: String
    @Environment(\.dismiss) var dismiss
    
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later by default
    @State private var creditCost = 10
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Class Creation"
    @State private var isLoading = false
    @State private var isSuccess = false
    @State private var editingInstructorName = false
    
    init(selectedDate: Date, instructorName: String, onClassCreated: (() -> Void)? = nil) {
        self.selectedDate = selectedDate
        self.instructorName = instructorName
        self.onClassCreated = onClassCreated
        
        // Initialize with the provided instructor name
        _actualInstructorName = State(initialValue: instructorName)
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
                                Text(selectedDate, style: .date)
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
                                createClass()
                            } label: {
                                Text("Create Class")
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
                        Text("Creating class...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(10)
                }
            }
            .navigationTitle("Create Class")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if isSuccess {
                            onClassCreated?()
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
        print("DEBUG CreateClassView: Initial instructor name is '\(actualInstructorName)'")
        
        // Try to load the saved instructor name from UserDefaults
        if let savedName = UserDefaults.standard.string(forKey: "savedInstructorName"), !savedName.isEmpty {
            print("DEBUG CreateClassView: Loaded saved instructor name '\(savedName)' from UserDefaults")
            actualInstructorName = savedName
            return
        }
        
        // If no saved name, try to load from UserDefaults profile
        if actualInstructorName.isEmpty || actualInstructorName == "Coach" {
            if let profileData = UserDefaults.standard.data(forKey: "userProfile") {
                do {
                    let userProfile = try JSONDecoder().decode(UserProfile.self, from: profileData)
                    let fullName = "\(userProfile.firstName) \(userProfile.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !fullName.isEmpty {
                        print("DEBUG CreateClassView: Loaded instructor name '\(fullName)' from UserDefaults")
                        actualInstructorName = fullName
                    }
                } catch {
                    print("ERROR CreateClassView: Failed to decode profile from UserDefaults: \(error)")
                }
            }
        }
    }
    
    private func saveInstructorName() {
        let name = actualInstructorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != "Coach" {
            UserDefaults.standard.set(name, forKey: "savedInstructorName")
            print("DEBUG CreateClassView: Saved instructor name '\(name)' to UserDefaults")
        }
    }
    
    // MARK: - Functions
    private func createClass() {
        // Validate
        let trimmedName = actualInstructorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            alertTitle = "Invalid Input"
            alertMessage = "Instructor name cannot be empty"
            showingAlert = true
            return
        }
        
        if endTime <= startTime {
            alertTitle = "Invalid Time"
            alertMessage = "End time must be after start time"
            showingAlert = true
            return
        }
        
        // Save the instructor name for future use
        if trimmedName != "Coach" {
            UserDefaults.standard.set(trimmedName, forKey: "savedInstructorName")
        }
        
        isLoading = true
        print("DEBUG CreateClassView: Starting class creation")
        print("DEBUG CreateClassView: Selected date is \(selectedDate)")
        print("DEBUG CreateClassView: Using instructor name: \(trimmedName)")
        
        // Format time for display
        let startTimeString = timeFormatter.string(from: startTime)
        let endTimeString = timeFormatter.string(from: endTime)
        let timeRangeString = "\(startTimeString) - \(endTimeString)"
        
        // Create the class
        Task {
            do {
                try await classService.createClass(
                    instructorName: trimmedName,
                    classTime: timeRangeString,
                    date: selectedDate,
                    startTime: startTime,
                    endTime: endTime,
                    creditCost: creditCost
                )
                
                print("DEBUG CreateClassView: Class created successfully with instructor: \(trimmedName)")
                
                // Handle UI updates on main thread
                await MainActor.run {
                    isLoading = false
                    isSuccess = true
                    alertTitle = "Success"
                    alertMessage = "Class created successfully!"
                    showingAlert = true
                    
                    // Notify parent immediately
                    onClassCreated?()
                }
            } catch {
                print("ERROR CreateClassView: Failed to create class - \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoading = false
                    alertTitle = "Error"
                    alertMessage = "Failed to create class: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Preview
struct CreateClassView_Previews: PreviewProvider {
    static var previews: some View {
        CreateClassView(selectedDate: Date(), instructorName: "John Doe")
    }
} 