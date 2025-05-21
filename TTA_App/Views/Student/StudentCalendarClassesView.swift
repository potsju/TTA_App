import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Observation

struct StudentCalendarClassesView: View {
    @State private var selectedDate: Int = 19
    @State private var currentMonth: String = "September 2021"
    @State private var classService = ClassService()
    @State private var balanceService = BalanceService()
    @State private var showingBookAlert = false
    @State private var alertMessage = ""
    @State private var selectedFilter: ClassFilter = .all
    @State private var isLoading = false
    @State private var userName = ""
    
    enum ClassFilter {
        case all, open, booked
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
                                Text("Open Classes").tag(ClassFilter.open)
                                Text("Booked Classes").tag(ClassFilter.booked)
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
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Header with instructor and status
                                            HStack(alignment: .top) {
                                                // Instructor info
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(classItem.instructorName)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.black)
                                                    
                                                    HStack(spacing: 8) {
                                                        // Credit cost badge
                                                        Text("\(classItem.creditCost) credits")
                                                            .font(.system(size: 12, weight: .medium))
                                                            .foregroundColor(TailwindColors.violet600)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(TailwindColors.violet100)
                                                            .cornerRadius(6)
                                                        
                                                        // Duration badge
                                                        let duration = getDurationInMinutes(start: classItem.startTime, end: classItem.endTime)
                                                        Text("\(duration) min")
                                                            .font(.system(size: 12, weight: .medium))
                                                            .foregroundColor(TailwindColors.gray600)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(TailwindColors.gray100)
                                                            .cornerRadius(6)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                // Time and status
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text(classItem.classTime)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.black)
                                                    
                                                    if !classItem.isAvailable {
                                                        Text("Booked")
                                                            .font(.system(size: 12, weight: .medium))
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(TailwindColors.violet200)
                                                            .foregroundColor(TailwindColors.violet800)
                                                            .cornerRadius(8)
                                                    }
                                                }
                                            }
                                            
                                            // Divider
                                            Divider()
                                                .padding(.vertical, 4)
                                            
                                            // Footer with booking button
                                            HStack {
                                                // Date display
                                                Text(classItem.date.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                                
                                                Spacer()
                                                
                                                if classItem.isAvailable {
                                                    Button(action: {
                                                        Task {
                                                            await bookClass(classItem)
                                                        }
                                                    }) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 14))
                                                            Text("Book Now")
                                                                .font(.system(size: 14, weight: .semibold))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 8)
                                                        .background(TailwindColors.violet600)
                                                        .cornerRadius(20)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(16)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(classItem.isAvailable ? TailwindColors.violet100 : TailwindColors.violet200, lineWidth: 1)
                                        )
                                    }
                                }
                                .frame(maxWidth: 328)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .task {
                // Check role first
                await checkUserRole()
                // Then load classes
                await refreshClasses()
            }
            .alert("Booking Status", isPresented: $showingBookAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: selectedDate) { _ in
                Task {
                    await refreshClasses()
                }
            }
        }
    }
    
    private func checkUserRole() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                if let firstName = document.data()?["firstName"] as? String,
                   let lastName = document.data()?["lastName"] as? String {
                    await MainActor.run {
                        self.userName = "\(firstName) \(lastName)"
                    }
                }
            }
        } catch {
            print("Error checking user role: \(error)")
        }
    }
    
    private func refreshClasses() async {
        print("DEBUG: StudentCalendarClassesView refreshing classes")
        isLoading = true
        
        // Check user info if needed
        if userName.isEmpty {
            await checkUserRole()
        }
        
        // Use the ClassService's loadAllClasses method to refresh
        await classService.loadAllClasses()
        
        // Update UI
        await MainActor.run {
            isLoading = false
            
            // Check what we have after filtering
            let filteredClasses = getFilteredClasses()
            print("DEBUG: StudentCalendarClassesView has \(filteredClasses.count) classes after filtering")
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
            return "All Classes"
        case .open:
            return "Open Classes"
        case .booked:
            return "Your Classes"
        }
    }
    
    private func getFilteredClasses() -> [Class] {
        let date = getSelectedDate()
        print("DEBUG: StudentCalendarClassesView filtering for date: \(date)")
        
        // Get classes for the selected date
        let dateClasses = classService.getClassesForDate(date)
        print("DEBUG: StudentCalendarClassesView found \(dateClasses.count) classes for date \(date)")
        
        // For debugging, log the classes we found
        if dateClasses.isEmpty {
            print("DEBUG: No classes found for date \(date)")
        } else {
            for (index, classItem) in dateClasses.enumerated() {
                print("DEBUG: Class \(index): \(classItem.id) - \(classItem.instructorName) - \(classItem.formattedDate)")
            }
        }
        
        // Apply filter based on class availability
        switch selectedFilter {
        case .all:
            return dateClasses
        case .open:
            return dateClasses.filter { $0.isAvailable }
        case .booked:
            return dateClasses.filter { !$0.isAvailable }
        }
    }
    
    private func bookClass(_ classItem: Class) async {
        do {
            // Try to book the class
            try await classService.bookClass(classItem)
            
            // Refresh the balance
            await balanceService.loadBalance()
            
            // Show success message
            alertMessage = "Successfully booked class!"
            showingBookAlert = true
            
        } catch let error as NSError {
            if error.domain == "BalanceService" && error.code == 101 {
                alertMessage = "Insufficient credits to book this class"
            } else {
                alertMessage = "Failed to book class: \(error.localizedDescription)"
            }
            showingBookAlert = true
        } catch {
            alertMessage = "Failed to book class: \(error.localizedDescription)"
            showingBookAlert = true
        }
    }
    

    private func getDurationInMinutes(start: Date, end: Date) -> Int {
        return Int(end.timeIntervalSince(start) / 60)
    }
}

struct StudentCalendarClassesView_Previews: PreviewProvider {
    static var previews: some View {
        StudentCalendarClassesView()
    }
}
