import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import AVFoundation
import CodeScanner
import CoreImage
import CoreImage.CIFilterBuiltins

struct EnhancedStudentDetailView: View {
    let student: Student
    @Environment(\.dismiss) var dismiss
    @State private var comments: [StudentComment] = []
    @State private var voiceMemos: [VoiceMemo] = []
    @State private var pastClasses: [Class] = []
    @State private var showingAddComment = false
    @State private var showingAddVoiceMemo = false
    @State private var selectedClassForComment: Class?
    @State private var selectedClassForVoiceMemo: Class?
    @State private var newComment = ""
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Student Profile Header
                    VStack(spacing: 12) {
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
                        
                        Text(student.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(student.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Booked Classes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Booked Classes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if let bookedClasses = student.bookedClasses, !bookedClasses.isEmpty {
                            ForEach(bookedClasses) { booking in
                                BookedClassInfoCard(booking: booking)
                            }
                        } else if pastClasses.isEmpty {
                            Text("No booked classes yet")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(pastClasses) { classItem in
                                PastClassCard(classItem: classItem) {
                                    selectedClassForComment = classItem
                                    showingAddComment = true
                                } onAddVoiceMemo: {
                                    selectedClassForVoiceMemo = classItem
                                    showingAddVoiceMemo = true
                                }
                            }
                        }
                    }
                    
                    // Past Classes Section if needed
                    if !pastClasses.isEmpty && student.bookedClasses != nil && !student.bookedClasses!.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Past Classes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(pastClasses) { classItem in
                                PastClassCard(classItem: classItem) {
                                    selectedClassForComment = classItem
                                    showingAddComment = true
                                } onAddVoiceMemo: {
                                    selectedClassForVoiceMemo = classItem
                                    showingAddVoiceMemo = true
                                }
                            }
                        }
                    }
                    
                    // Comments Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            Button(action: {
                                showingAddComment = true
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(TailwindColors.violet400)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Quick comment entry
                        VStack {
                            TextField("Add a quick note...", text: $newComment)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            
                            Button(action: {
                                if !newComment.isEmpty {
                                    Task {
                                        await addQuickComment()
                                    }
                                }
                            }) {
                                Text("Add Note")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(newComment.isEmpty ? Color.gray : TailwindColors.violet400)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(newComment.isEmpty)
                            .padding(.bottom)
                        }
                        
                        if comments.isEmpty {
                            Text("No notes yet")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(comments) { comment in
                                CommentCard(comment: comment)
                            }
                        }
                    }
                    
                    // Voice Memos Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Voice Memos")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            Button(action: {
                                showingAddVoiceMemo = true
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(TailwindColors.violet400)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Quick voice memo recorder
                        HStack(spacing: 16) {
                            Button(action: {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }) {
                                VStack {
                                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(isRecording ? .red : TailwindColors.violet400)
                                    Text(isRecording ? "Stop" : "Record")
                                        .font(.caption)
                                        .foregroundColor(isRecording ? .red : TailwindColors.violet400)
                                }
                            }
                            .padding(.horizontal)
                            
                            if isRecording {
                                Text("Recording...")
                                    .foregroundColor(.red)
                                Spacer()
                            } else if audioRecorder != nil {
                                Button(action: {
                                    Task {
                                        await saveQuickVoiceMemo()
                                    }
                                }) {
                                    Text("Save Voice Memo")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(TailwindColors.violet400)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        if voiceMemos.isEmpty {
                            Text("No voice memos yet")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(voiceMemos) { memo in
                                VoiceMemoCard(memo: memo)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Student Details")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .sheet(isPresented: $showingAddComment) {
                AddCommentView(
                    studentId: student.id,
                    classId: selectedClassForComment?.id,
                    onCommentAdded: { comment in
                        comments.append(comment)
                    }
                )
            }
            .sheet(isPresented: $showingAddVoiceMemo) {
                AddVoiceMemoView(
                    studentId: student.id,
                    classId: selectedClassForVoiceMemo?.id,
                    onVoiceMemoAdded: { memo in
                        voiceMemos.append(memo)
                    }
                )
            }
            .task {
                await loadStudentData()
            }
        }
    }
    
    private func loadStudentData() async {
        isLoading = true
        do {
            let db = Firestore.firestore()
            
            // Load past classes
            let classesSnapshot = try await db.collection("classes")
                .whereField("studentId", isEqualTo: student.id)
                .whereField("isFinished", isEqualTo: true)
                .getDocuments()
            
            var loadedClasses: [Class] = []
            for document in classesSnapshot.documents {
                // Get the document reference
                let docRef = db.collection("classes").document(document.documentID)
                let fullDoc = try await docRef.getDocument()
                
                if let classObj = Class.fromFirestore(document: fullDoc) {
                    loadedClasses.append(classObj)
                }
            }
            pastClasses = loadedClasses
            
            // Load comments
            let commentsSnapshot = try await db.collection("student_comments")
                .whereField("studentId", isEqualTo: student.id)
                .getDocuments()
            
            comments = commentsSnapshot.documents.compactMap { document -> StudentComment? in
                let data = document.data()
                return StudentComment(
                    id: document.documentID,
                    text: data["text"] as? String ?? "",
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    coachId: data["coachId"] as? String ?? "",
                    classId: data["classId"] as? String
                )
            }
            
            // Load voice memos
            let memosSnapshot = try await db.collection("voice_memos")
                .whereField("studentId", isEqualTo: student.id)
                .getDocuments()
            
            voiceMemos = memosSnapshot.documents.compactMap { document -> VoiceMemo? in
                let data = document.data()
                return VoiceMemo(
                    id: document.documentID,
                    url: data["url"] as? String ?? "",
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    coachId: data["coachId"] as? String ?? "",
                    classId: data["classId"] as? String
                )
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // Add a new function for quick comment entry
    private func addQuickComment() async {
        do {
            let db = Firestore.firestore()
            guard let coachId = Auth.auth().currentUser?.uid else { return }
            
            var commentData: [String: Any] = [
                "text": newComment,
                "studentId": student.id,
                "coachId": coachId,
                "timestamp": Timestamp()
            ]
            
            let document = try await db.collection("student_comments").addDocument(data: commentData)
            
            let comment = StudentComment(
                id: document.documentID,
                text: newComment,
                timestamp: Date(),
                coachId: coachId,
                classId: nil
            )
            
            await MainActor.run {
                comments.append(comment)
                newComment = ""
            }
        } catch {
            print("Error saving quick comment: \(error)")
        }
    }
    
    // Add these functions for the quick voice memo recording
    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
    
    private func saveQuickVoiceMemo() async {
        guard let audioRecorder = audioRecorder else { return }
        
        do {
            let db = Firestore.firestore()
            guard let coachId = Auth.auth().currentUser?.uid else { return }
            
            // Upload the audio file to Firebase Storage
            let storage = Storage.storage()
            let storageRef = storage.reference()
            let audioRef = storageRef.child("voice_memos/\(UUID().uuidString).m4a")
            
            let audioData = try Data(contentsOf: audioRecorder.url)
            let metadata = StorageMetadata()
            metadata.contentType = "audio/m4a"
            
            _ = try await audioRef.putDataAsync(audioData, metadata: metadata)
            let downloadURL = try await audioRef.downloadURL()
            
            let memoData: [String: Any] = [
                "url": downloadURL.absoluteString,
                "studentId": student.id,
                "coachId": coachId,
                "timestamp": Timestamp()
            ]
            
            let document = try await db.collection("voice_memos").addDocument(data: memoData)
            
            let memo = VoiceMemo(
                id: document.documentID,
                url: downloadURL.absoluteString,
                timestamp: Date(),
                coachId: coachId,
                classId: nil
            )
            
            await MainActor.run {
                voiceMemos.append(memo)
                self.audioRecorder = nil
            }
        } catch {
            print("Error saving voice memo: \(error)")
        }
    }
}

struct PastClassCard: View {
    let classItem: Class
    let onAddComment: () -> Void
    let onAddVoiceMemo: () -> Void
    @State private var showingQRScanner = false
    @State private var scanResult: String?
    @State private var showingScanResult = false
    @State private var scanSuccess = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classItem.classTime)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(classItem.instructorName)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text(classItem.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: onAddComment) {
                        Image(systemName: "text.bubble")
                            .foregroundColor(TailwindColors.violet400)
                    }
                    
                    Button(action: onAddVoiceMemo) {
                        Image(systemName: "mic.circle")
                            .foregroundColor(TailwindColors.violet400)
                    }
                }
            }
            
            if scanResult != nil {
                HStack {
                    Image(systemName: scanSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(scanSuccess ? .green : .red)
                    Text(scanSuccess ? "QR Code Verified ✓" : "Verification Failed ✗")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(scanSuccess ? .green : .red)
                    
                    Spacer()
                    
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        Text("Scan Again")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(TailwindColors.violet600)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(scanSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button(action: {
                    showingQRScanner = true
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(TailwindColors.violet600)
                        Text("Verify QR Code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(TailwindColors.violet600)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(TailwindColors.violet50)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView(onScan: { result in
                self.scanResult = result.string
                // Check if the QR code matches the class ID
                self.scanSuccess = (result.string == classItem.id)
                self.showingQRScanner = false
                self.showingScanResult = true
            })
        }
        .alert(isPresented: $showingScanResult) {
            if scanSuccess {
                return Alert(
                    title: Text("Verification Successful"),
                    message: Text("QR code matches this class. Student attendance confirmed."),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text("Verification Failed"),
                    message: Text("The scanned QR code does not match this class."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct QRScannerView: View {
    var onScan: (ScanResult) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                CodeScannerView(codeTypes: [.qr], simulatedData: "simulated-qr-code", completion: handleScan)
            }
            .navigationTitle("Scan Student QR Code")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
    
    private func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            onScan(result)
        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
            dismiss()
        }
    }
}

struct StudentComment: Identifiable {
    let id: String
    let text: String
    let timestamp: Date
    let coachId: String
    let classId: String?
}

struct VoiceMemo: Identifiable {
    let id: String
    let url: String
    let timestamp: Date
    let coachId: String
    let classId: String?
}

struct CommentCard: View {
    let comment: StudentComment
    @State private var coachName: String = "Untitled"
    @State private var className: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Comment header with coach name and time
            HStack {
                Text("By: \(coachName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(TailwindColors.violet600)
                
                Spacer()
                
                Text(comment.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 4)
            
            // Comment text
            Text(comment.text)
                .font(.body)
            
            // Optional class reference
            if !className.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Class: \(className)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .task {
            await fetchCoachName()
            if let classId = comment.classId {
                await fetchClassName(classId: classId)
            }
        }
    }
    
    private func fetchCoachName() async {
        let db = Firestore.firestore()
        do {
            let coachDoc = try await db.collection("users").document(comment.coachId).getDocument()
            if let coachData = coachDoc.data(),
               let firstName = coachData["firstName"] as? String,
               let lastName = coachData["lastName"] as? String {
                await MainActor.run {
                    coachName = "\(firstName) \(lastName)"
                }
            }
        } catch {
            print("Error fetching coach name: \(error)")
        }
    }
    
    private func fetchClassName(classId: String) async {
        let db = Firestore.firestore()
        do {
            let classDoc = try await db.collection("classes").document(classId).getDocument()
            if let classData = classDoc.data(),
               let classTime = classData["classTime"] as? String {
                await MainActor.run {
                    className = classTime
                }
            }
        } catch {
            print("Error fetching class name: \(error)")
        }
    }
}

struct VoiceMemoCard: View {
    let memo: VoiceMemo
    @State private var coachName: String = "Untitled"
    @State private var className: String = ""
    @State private var isPlaying = false
    private let audioPlayer = AudioPlayer()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with coach name and time
            HStack {
                Text("By: \(coachName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(TailwindColors.violet600)
                
                Spacer()
                
                Text(memo.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 4)
            
            // Play button and title
            HStack {
                Button(action: {
                    if isPlaying {
                        audioPlayer.stop()
                    } else {
                        audioPlayer.play(url: URL(string: memo.url)!)
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(TailwindColors.violet400)
                }
                
                Text("Voice Memo")
                    .font(.subheadline)
                    .foregroundColor(isPlaying ? TailwindColors.violet600 : .primary)
            }
            
            // Optional class reference
            if !className.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Class: \(className)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .task {
            await fetchCoachName()
            if let classId = memo.classId {
                await fetchClassName(classId: classId)
            }
        }
    }
    
    private func fetchCoachName() async {
        let db = Firestore.firestore()
        do {
            let coachDoc = try await db.collection("users").document(memo.coachId).getDocument()
            if let coachData = coachDoc.data(),
               let firstName = coachData["firstName"] as? String,
               let lastName = coachData["lastName"] as? String {
                await MainActor.run {
                    coachName = "\(firstName) \(lastName)"
                }
            }
        } catch {
            print("Error fetching coach name: \(error)")
        }
    }
    
    private func fetchClassName(classId: String) async {
        let db = Firestore.firestore()
        do {
            let classDoc = try await db.collection("classes").document(classId).getDocument()
            if let classData = classDoc.data(),
               let classTime = classData["classTime"] as? String {
                await MainActor.run {
                    className = classTime
                }
            }
        } catch {
            print("Error fetching class name: \(error)")
        }
    }
}

struct AddCommentView: View {
    let studentId: String
    let classId: String?
    let onCommentAdded: (StudentComment) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $commentText)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Add Note")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    Task {
                        await saveComment()
                    }
                }
                .disabled(commentText.isEmpty || isSubmitting)
            )
        }
    }
    
    private func saveComment() async {
        isSubmitting = true
        do {
            let db = Firestore.firestore()
            guard let coachId = Auth.auth().currentUser?.uid else { return }
            
            var commentData: [String: Any] = [
                "text": commentText,
                "studentId": studentId,
                "coachId": coachId,
                "timestamp": Timestamp()
            ]
            
            if let classId = classId {
                commentData["classId"] = classId
            }
            
            let document = try await db.collection("student_comments").addDocument(data: commentData)
            
            let comment = StudentComment(
                id: document.documentID,
                text: commentText,
                timestamp: Date(),
                coachId: coachId,
                classId: classId
            )
            
            await MainActor.run {
                onCommentAdded(comment)
                dismiss()
            }
        } catch {
            print("Error saving comment: \(error)")
        }
        isSubmitting = false
    }
}

struct AddVoiceMemoView: View {
    let studentId: String
    let classId: String?
    let onVoiceMemoAdded: (VoiceMemo) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    VStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 60))
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                    }
                    .foregroundColor(isRecording ? .red : TailwindColors.violet400)
                }
                .padding()
                
                if isRecording {
                    Text("Recording...")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Add Voice Memo")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    Task {
                        await saveVoiceMemo()
                    }
                }
                .disabled(isRecording || isSubmitting)
            )
        }
    }
    
    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
    
    private func saveVoiceMemo() async {
        guard let audioRecorder = audioRecorder else { return }
        isSubmitting = true
        
        do {
            let db = Firestore.firestore()
            guard let coachId = Auth.auth().currentUser?.uid else { return }
            
            // Upload the audio file to Firebase Storage
            let storage = Storage.storage()
            let storageRef = storage.reference()
            let audioRef = storageRef.child("voice_memos/\(UUID().uuidString).m4a")
            
            let audioData = try Data(contentsOf: audioRecorder.url)
            let metadata = StorageMetadata()
            metadata.contentType = "audio/m4a"
            
            _ = try await audioRef.putDataAsync(audioData, metadata: metadata)
            let downloadURL = try await audioRef.downloadURL()
            
            var memoData: [String: Any] = [
                "url": downloadURL.absoluteString,
                "studentId": studentId,
                "coachId": coachId,
                "timestamp": Timestamp()
            ]
            
            if let classId = classId {
                memoData["classId"] = classId
            }
            
            let document = try await db.collection("voice_memos").addDocument(data: memoData)
            
            let memo = VoiceMemo(
                id: document.documentID,
                url: downloadURL.absoluteString,
                timestamp: Date(),
                coachId: coachId,
                classId: classId
            )
            
            await MainActor.run {
                onVoiceMemoAdded(memo)
                dismiss()
            }
        } catch {
            print("Error saving voice memo: \(error)")
        }
        isSubmitting = false
    }
}

class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    
    func play(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    func stop() {
        audioPlayer?.stop()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Handle audio playback completion if needed
    }
}

struct BookedClassInfoCard: View {
    let booking: ClassBookingInfo
    @State private var showingQRScanner = false
    @State private var scanResult: String?
    @State private var showingScanResult = false
    @State private var scanSuccess = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Class Time: \(booking.time)")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("Date: \(booking.date)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(booking.isFinished ? "Completed" : "Upcoming")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(booking.isFinished ? TailwindColors.green100 : TailwindColors.violet100)
                    .foregroundColor(booking.isFinished ? TailwindColors.green700 : TailwindColors.violet700)
                    .cornerRadius(8)
            }
            
            // QR Code Button
            Button(action: {
                showingQRScanner = true
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(TailwindColors.violet600)
                    Text("Scan QR Code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TailwindColors.violet600)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(TailwindColors.violet50)
                .cornerRadius(8)
            }
            
            if scanResult != nil {
                HStack {
                    Image(systemName: scanSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(scanSuccess ? .green : .red)
                    Text(scanSuccess ? "QR Code Verified ✓" : "Verification Failed ✗")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(scanSuccess ? .green : .red)
                    
                    Spacer()
                    
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        Text("Scan Again")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(TailwindColors.violet600)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(scanSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView(onScan: { result in
                self.scanResult = result.string
                // Check if the QR code matches the class ID
                self.scanSuccess = (result.string == booking.id.uuidString)
                self.showingQRScanner = false
                self.showingScanResult = true
            })
        }
        .alert(isPresented: $showingScanResult) {
            if scanSuccess {
                return Alert(
                    title: Text("Verification Successful"),
                    message: Text("QR code matches this class. Student attendance confirmed."),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text("Verification Failed"),
                    message: Text("The scanned QR code does not match this class."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct ClassQRCodeView: View {
    let classId: String
    let classTime: String
    let date: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Class QR Code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 8) {
                    Text(classTime)
                        .font(.headline)
                    
                    Text(date)
                        .foregroundColor(.gray)
                }
                
                // QR Code Image
                Image(uiImage: generateQRCode(from: classId))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .background(Color.white)
                    .padding()
                
                Text("Show this QR code to your coach for verification")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
} 
