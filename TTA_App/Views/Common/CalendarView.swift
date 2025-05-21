import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Observation

struct CalendarView: View {
    @Binding var selectedDate: Int
    @Binding var currentMonth: String
    @State private var classService = ClassService()
    @State private var currentDate = Date()
    @State private var showingClassList = false
    @State private var showingCreateClass = false
    @State private var isCoach = false
    @State private var userName = ""
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let title = formatter.string(from: currentDate)
        
        // Update the binding to keep it in sync
        if title != currentMonth {
            DispatchQueue.main.async {
                currentMonth = title
            }
        }
        
        return title
    }
    
    private var daysInMonth: Int {
        let range = calendar.range(of: .day, in: .month, for: currentDate)!
        return range.count
    }
    
    private var firstWeekday: Int {
        let components = calendar.dateComponents([.year, .month], from: currentDate)
        let firstDay = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstDay) - 1
    }
    
    var body: some View {
        VStack {
            // Calendar header
            HStack {
                Button(action: moveToPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(monthTitle)
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: moveToNextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 20)
            
            // Days of week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 10)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 35)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    DayCell(
                        day: day,
                        isSelected: selectedDate == day,
                        hasClasses: hasClassesOnDay(day),
                        onTap: {
                            selectedDate = day
                            if isCoach {
                                showingCreateClass = true
                            } else {
                                showingClassList = true
                            }
                        }
                    )
                }
            }
        }
        .task {
            await checkUserRole()
            await classService.loadAllClasses()
        }
        .sheet(isPresented: $showingClassList) {
            ClassListView(date: getSelectedDate())
        }
        .sheet(isPresented: $showingCreateClass) {
            CreateClassView(
                selectedDate: getSelectedDate(), 
                instructorName: userName.isEmpty ? "Coach" : userName,
                onClassCreated: {
                    print("DEBUG CalendarView: Class created, will reload classes")
                    Task {
                        await classService.loadAllClasses()
                    }
                }
            )
        }
    }
    
    private func checkUserRole() async {
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("DEBUG CalendarView: No user ID found")
            return 
        }
        
        print("DEBUG CalendarView: Checking user role and getting name for user ID: \(userId)")
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                if let role = document.data()?["role"] as? String {
                    await MainActor.run {
                        self.isCoach = role == "Coach"
                        print("DEBUG CalendarView: User role is \(role)")
                    }
                }
                
                if let firstName = document.data()?["firstName"] as? String,
                   let lastName = document.data()?["lastName"] as? String {
                    await MainActor.run {
                        self.userName = "\(firstName) \(lastName)"
                        print("DEBUG CalendarView: Set instructor name to full name: \(self.userName)")
                    }
                } else {
                    print("DEBUG CalendarView: Could not find user's first and last name")
                }
            } else {
                print("DEBUG CalendarView: User document does not exist")
            }
        } catch {
            print("ERROR CalendarView: Error checking user role: \(error)")
        }
    }
    
    private func moveToPreviousMonth() {
        withAnimation {
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
            updateCurrentMonthTitle()
        }
    }
    
    private func moveToNextMonth() {
        withAnimation {
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            updateCurrentMonthTitle()
        }
    }
    
    private func updateCurrentMonthTitle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        currentMonth = formatter.string(from: currentDate)
    }
    
    private func hasClassesOnDay(_ day: Int) -> Bool {
        let date = getDateForDay(day)
        let classes = classService.getClassesForDate(date)
        return !classes.isEmpty
    }
    
    private func getDateForDay(_ day: Int) -> Date {
        let components = calendar.dateComponents([.year, .month], from: currentDate)
        return calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) ?? currentDate
    }
    
    private func getSelectedDate() -> Date {
        return getDateForDay(selectedDate)
    }
}

struct DayCell: View {
    let day: Int
    let isSelected: Bool
    let hasClasses: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? TailwindColors.violet500 : Color.clear)
                    .frame(width: 35, height: 35)
                
                Text("\(day)")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if hasClasses {
                    Circle()
                        .fill(TailwindColors.violet500)
                        .frame(width: 4, height: 4)
                        .offset(y: 12)
                }
            }
            .frame(height: 35)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ClassListView: View {
    let date: Date
    @State private var classService = ClassService()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(classService.getClassesForDate(date)) { classItem in
                ClassItemView(
                    instructorName: classItem.instructorName,
                    classTime: classItem.classTime,
                    creditCost: classItem.creditCost,
                    startTime: classItem.startTime,
                    endTime: classItem.endTime
                )
            }
            .navigationTitle(date.formatted(date: .long, time: .omitted))
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .onAppear {
            Task {
                await classService.loadAllClasses()
            }
        }
    }
}

// Model for classes
struct ClassModel: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let instructor: String
    let date: Date
}

struct CalendarPreviewContainer: View {
    @State private var selectedDate: Int = 19
    @State private var currentMonth: String = "March 2025"
    
    var body: some View {
        CalendarView(
            selectedDate: $selectedDate,
            currentMonth: $currentMonth
        )
    }
}

#Preview {
    CalendarPreviewContainer()
        .padding()
}
