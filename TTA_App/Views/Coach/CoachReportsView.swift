import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import AVFoundation
import FirebaseStorage
import Foundation

// Model for a coaching session report
struct SessionReport: Identifiable {
    let id: String
    let date: Date
    let time: String
    let studentName: String
    let hoursCompleted: Double
    var notes: String
    var voiceMemos: [VoiceMemo]
    let studentId: String
    let coachId: String
    let month: String // Format: "YYYY-MM" for sorting and filtering
}

// VoiceMemo struct is now imported from the shared model file

struct CoachReportsView: View {
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var monthlyReports: [String] = [] // List of months with reports (YYYY-MM format)
    @State private var selectedMonth: String = getCurrentMonth()
    @State private var sessionReports: [SessionReport] = []
    @State private var selectedReport: SessionReport?
    @State private var showingReportDetail = false
    
    private static func getCurrentMonth() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        return dateFormatter.string(from: Date())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Tab selector
                    Picker("Report Type", selection: $selectedTab) {
                        Text("Current Month").tag(0)
                        Text("Past Reports").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if isLoading {
                        ProgressView("Loading reports...")
                            .padding()
                        Spacer()
                    } else {
                        if selectedTab == 0 {
                            // Current month view
                            currentMonthView
                        } else {
                            // Past reports view
                            pastReportsView
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingReportDetail) {
                if let report = selectedReport {
                    SessionReportDetailView(sessionReport: report, onSave: { updatedReport in
                        if let index = sessionReports.firstIndex(where: { $0.id == updatedReport.id }) {
                            sessionReports[index] = updatedReport
                        }
                    })
                }
            }
        }
    }
    
    private var currentMonthView: some View {
        Group {
            if sessionReports.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(TailwindColors.violet300)
                    
                    Text("No sessions for current month")
                        .font(.headline)
                    
                    Text("Completed sessions will appear here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessionReports) { report in
                        Button(action: {
                            selectedReport = report
                            showingReportDetail = true
                        }) {
                            SessionReportRow(report: report)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
    }
    
    private var pastReportsView: some View {
        VStack(spacing: 0) {
            // Month picker
            if !monthlyReports.isEmpty {
                Menu {
                    ForEach(monthlyReports, id: \.self) { month in
                        Button(formatMonth(month)) {
                            selectedMonth = month
                            Task {
                                await loadSessionReports(for: month)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(formatMonth(selectedMonth))
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(TailwindColors.violet600)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(TailwindColors.violet100)
                    .cornerRadius(8)
                }
                .padding()
            }
            
            // Session list
            if sessionReports.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(TailwindColors.violet300)
                    
                    Text("No sessions for \(formatMonth(selectedMonth))")
                        .font(.headline)
                    
                    Text("Select a different month to view other reports")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessionReports) { report in
                        Button(action: {
                            selectedReport = report
                            showingReportDetail = true
                        }) {
                            SessionReportRow(report: report)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
    }
    
    private func formatMonth(_ monthStr: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        
        guard let date = dateFormatter.date(from: monthStr) else {
            return monthStr
        }
        
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }
    
    private func loadData() async {
        isLoading = true
        
        // Get current month
        let currentMonth = Self.getCurrentMonth()
        
        // Load monthly reports
        await loadMonthlyReports()
        
        // Load current month by default
        await loadSessionReports(for: currentMonth)
        
        isLoading = false
    }
    
    private func loadMonthlyReports() async {
        guard let coachId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("sessionReports")
                .whereField("coachId", isEqualTo: coachId)
                .getDocuments()
            
            // Extract unique months from sessions
            var months = Set<String>()
            for document in snapshot.documents {
                if let month = document.data()["month"] as? String {
                    months.insert(month)
                }
            }
            
            // Sort months (newest first)
            let sortedMonths = Array(months).sorted().reversed()
            
            await MainActor.run {
                self.monthlyReports = Array(sortedMonths)
                
                // Set default selected month to current month or newest available
                if let firstMonth = self.monthlyReports.first, !self.monthlyReports.contains(Self.getCurrentMonth()) {
                    self.selectedMonth = firstMonth
                } else {
                    self.selectedMonth = Self.getCurrentMonth()
                }
            }
        } catch {
            print("Error loading monthly reports: \(error)")
        }
    }
    
    private func loadSessionReports(for month: String) async {
        guard let coachId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("sessionReports")
                .whereField("coachId", isEqualTo: coachId)
                .whereField("month", isEqualTo: month)
                .getDocuments()
            
            var reports: [SessionReport] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Extract voice memos array
                var voiceMemos: [VoiceMemo] = []
                if let memoData = data["voiceMemos"] as? [[String: Any]] {
                    for memo in memoData {
                        if let id = memo["id"] as? String,
                           let url = memo["url"] as? String,
                           let duration = memo["duration"] as? TimeInterval,
                           let createdAt = (memo["createdAt"] as? Timestamp)?.dateValue(),
                           let createdBy = memo["createdBy"] as? String {
                            
                            if let studentId = data["studentId"] as? String {
                                voiceMemos.append(VoiceMemo(
                                    id: id,
                                    url: url,
                                    duration: duration,
                                    timestamp: createdAt,
                                    coachId: coachId,
                                    studentId: studentId,
                                    classId: nil,
                                    sessionReportId: document.documentID,
                                    createdBy: createdBy
                                ))
                            }
                        }
                    }
                }
                
                // Create session report
                if let date = (data["date"] as? Timestamp)?.dateValue(),
                   let time = data["time"] as? String,
                   let studentName = data["studentName"] as? String,
                   let hoursCompleted = data["hoursCompleted"] as? Double,
                   let notes = data["notes"] as? String,
                   let studentId = data["studentId"] as? String {
                    
                    reports.append(SessionReport(
                        id: document.documentID,
                        date: date,
                        time: time,
                        studentName: studentName,
                        hoursCompleted: hoursCompleted,
                        notes: notes,
                        voiceMemos: voiceMemos,
                        studentId: studentId,
                        coachId: coachId,
                        month: month
                    ))
                }
            }
            
            // Sort by date (newest first)
            reports.sort { $0.date > $1.date }
            
            await MainActor.run {
                self.sessionReports = reports
            }
        } catch {
            print("Error loading session reports: \(error)")
        }
    }
}

struct SessionReportRow: View {
    let report: SessionReport
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateFormatter.string(from: report.date))
                        .font(.headline)
                    
                    Text(report.time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(report.studentName)
                    .font(.subheadline)
                
                HStack {
                    Text("\(String(format: "%.1f", report.hoursCompleted)) hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !report.notes.isEmpty {
                        Image(systemName: "text.bubble")
                            .font(.caption)
                            .foregroundColor(TailwindColors.violet400)
                    }
                    
                    if !report.voiceMemos.isEmpty {
                        Image(systemName: "mic")
                            .font(.caption)
                            .foregroundColor(TailwindColors.violet400)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
    }
}

struct SessionReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessionReport: SessionReport
    @State private var notes: String
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var selectedMemoURL: URL?
    @State private var isPlaying = false
    @State private var isSaving = false
    
    let onSave: (SessionReport) -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
    
    init(sessionReport: SessionReport, onSave: @escaping (SessionReport) -> Void) {
        self._sessionReport = State(initialValue: sessionReport)
        self._notes = State(initialValue: sessionReport.notes)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(dateFormatter.string(from: sessionReport.date))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(sessionReport.time)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Student")
                        Spacer()
                        Text(sessionReport.studentName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Hours Completed")
                        Spacer()
                        Text(String(format: "%.1f", sessionReport.hoursCompleted))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Voice Memos")) {
                    if sessionReport.voiceMemos.isEmpty {
                        Text("No voice memos")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(sessionReport.voiceMemos) { memo in
                            VoiceMemoRow(
                                memo: memo,
                                isPlaying: Binding(
                                    get: { self.isPlaying && self.selectedMemoURL == URL(string: memo.url) },
                                    set: { _ in }
                                ),
                                onPlay: {
                                    playMemo(memo)
                                },
                                onDelete: {
                                    deleteMemo(memo)
                                }
                            )
                        }
                    }
                    
                    HStack {
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .foregroundColor(isRecording ? .red : TailwindColors.violet600)
                                    .font(.system(size: 24))
                                
                                Text(isRecording ? "Stop Recording" : "Add Voice Memo")
                                    .foregroundColor(isRecording ? .red : TailwindColors.violet600)
                            }
                        }
                        
                        if isRecording {
                            Spacer()
                            Text(formatDuration(recordingDuration))
                                .foregroundColor(.red)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Session Report")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button(action: saveReport) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.white)
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving)
            )
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Create unique filename based on timestamp
            let fileName = "\(UUID().uuidString).m4a"
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            self.recordingURL = fileURL
            
            // Recording settings
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Start recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
            // Start timing
            recordingDuration = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.recordingDuration += 0.1
            }
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    private func stopRecording() {
        // Stop recording
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Upload the recording and create memo
        if let url = recordingURL {
            uploadMemo(fileURL: url, duration: recordingDuration)
        }
        
        isRecording = false
    }
    
    private func uploadMemo(fileURL: URL, duration: TimeInterval) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Upload to Firebase Storage
        let storage = Storage.storage()
        let fileName = fileURL.lastPathComponent
        let storageRef = storage.reference().child("voice_memos").child(fileName)
        
        do {
            let audioData = try Data(contentsOf: fileURL)
            
            // Upload data
            let _ = storageRef.putData(audioData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading voice memo: \(error)")
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    guard let downloadURL = url else {
                        print("Error getting download URL: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    // Create new memo with shared model
                    let newMemo = VoiceMemo(
                        id: UUID().uuidString,
                        url: downloadURL.absoluteString,
                        duration: duration,
                        timestamp: Date(),
                        coachId: userId,
                        studentId: sessionReport.studentId,
                        classId: nil,
                        sessionReportId: sessionReport.id,
                        createdBy: "coach"
                    )
                    
                    // Also save to the voice_memos collection for direct access by students
                    let db = Firestore.firestore()
                    db.collection("voice_memos").addDocument(data: newMemo.toFirestoreData()) { error in
                        if let error = error {
                            print("Error saving voice memo to collection: \(error)")
                        }
                    }
                    
                    var updatedMemos = sessionReport.voiceMemos
                    updatedMemos.append(newMemo)
                    
                    // Update report with new memo
                    DispatchQueue.main.async {
                        self.sessionReport.voiceMemos = updatedMemos
                    }
                }
            }
        } catch {
            print("Error reading audio data: \(error)")
        }
    }
    
    private func playMemo(_ memo: VoiceMemo) {
        guard let url = URL(string: memo.url) else { return }
        
        if isPlaying && selectedMemoURL == url {
            // Stop current playback
            AudioPlayerManager.shared.stop()
            isPlaying = false
            selectedMemoURL = nil
            return
        }
        
        // Stop any current playback if different URL
        if isPlaying {
            AudioPlayerManager.shared.stop()
        }
        
        // Start new playback
        selectedMemoURL = url
        isPlaying = true
        
        AudioPlayerManager.shared.play(url: url) {
            DispatchQueue.main.async {
                self.isPlaying = false
                self.selectedMemoURL = nil
            }
        }
    }
    
    private func deleteMemo(_ memo: VoiceMemo) {
        // Stop playback if this memo is playing
        if isPlaying && selectedMemoURL == URL(string: memo.url) {
            AudioPlayerManager.shared.stop()
            isPlaying = false
            selectedMemoURL = nil
        }
        
        // Remove memo from list
        sessionReport.voiceMemos.removeAll { $0.id == memo.id }
        
        // Delete from voice_memos collection as well
        let db = Firestore.firestore()
        let query = db.collection("voice_memos")
            .whereField("url", isEqualTo: memo.url)
        
        // Run the query and delete matching documents
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error finding voice memo in collection: \(error)")
                return
            }
            
            for document in snapshot?.documents ?? [] {
                document.reference.delete { error in
                    if let error = error {
                        print("Error deleting voice memo from collection: \(error)")
                    }
                }
            }
        }
        
        // Optional: Delete from storage
        if let url = URL(string: memo.url) {
            Storage.storage().reference(forURL: url.absoluteString).delete { error in
                if let error = error {
                    print("Error deleting memo from storage: \(error)")
                }
            }
        }
    }
    
    private func saveReport() {
        isSaving = true
        
        // Update session report with notes
        sessionReport.notes = notes
        
        // Update in Firestore
        let db = Firestore.firestore()
        
        // Convert voice memos to Firestore format
        let memoData = sessionReport.voiceMemos.map { memo -> [String: Any] in
            return [
                "id": memo.id,
                "url": memo.url,
                "duration": memo.duration,
                "createdAt": Timestamp(date: memo.timestamp),
                "createdBy": memo.createdBy
            ]
        }
        
        // Create update data
        let updateData: [String: Any] = [
            "notes": sessionReport.notes,
            "voiceMemos": memoData,
            "lastUpdated": Timestamp(date: Date())
        ]
        
        // First, ensure all voice memos are also in the voice_memos collection for student access
        for memo in sessionReport.voiceMemos {
            // Check if the memo is already in voice_memos collection
            let memoQuery = db.collection("voice_memos")
                .whereField("url", isEqualTo: memo.url)
                .limit(to: 1)
            
            memoQuery.getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking voice memo existence: \(error)")
                    return
                }
                
                // If the memo is not found in the collection, add it
                if snapshot?.documents.isEmpty ?? true {
                    db.collection("voice_memos").addDocument(data: memo.toFirestoreData()) { error in
                        if let error = error {
                            print("Error adding voice memo to collection: \(error)")
                        }
                    }
                }
            }
        }
        
        // Now update the session report
        db.collection("sessionReports").document(sessionReport.id).updateData(updateData) { error in
            DispatchQueue.main.async {
                self.isSaving = false
                
                if let error = error {
                    print("Error updating session report: \(error)")
                    // Show error alert
                    return
                }
                
                // Call save callback and dismiss
                self.onSave(self.sessionReport)
                self.dismiss()
            }
        }
    }
}

struct VoiceMemoRow: View {
    let memo: VoiceMemo
    @Binding var isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack {
            Button(action: onPlay) {
                HStack {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(TailwindColors.violet600)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDuration(memo.duration))
                            .font(.headline)
                        
                        Text(dateFormatter.string(from: memo.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

struct CoachReportsView_Previews: PreviewProvider {
    static var previews: some View {
        CoachReportsView()
    }
} 