//
//  StudentProfileView.swift
//  TTA_App
//
//  Created by Darren Choe on 5/21/25.
//

import SwiftUI
import FirebaseAuth
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

struct StudentProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var profileService = ProfileService()
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var phoneNumber = ""
    @State private var gender = "Male"
    @State private var email = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var displayImage: Image?
    @State private var profileImageURL = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSignOutConfirmation = false
    @State private var isEditing = false
    @State private var isLoading = true
    @State private var userRole: String = "Student"
    @State private var profile: UserProfile?
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    let genderOptions = ["Male", "Female", "Other", "Prefer not to say"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Image
                            ZStack {
                                Circle()
                                    .fill(userRole == "Coach" ? TailwindColors.violet400 : Color(red: 251/255, green: 146/255, blue: 60/255))
                                    .frame(width: 120, height: 120)
                                
                                if let image = profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } else if !profileImageURL.isEmpty {
                                    AsyncImage(url: URL(string: profileImageURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Text(firstName.prefix(1) + lastName.prefix(1))
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                } else {
                                    Text(firstName.prefix(1) + lastName.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                if isEditing {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    }
                                    .onChange(of: selectedItem) { newItem in
                                        Task {
                                            if let newItem = newItem {
                                                print("DEBUG: Selected new photo")
                                                do {
                                                    let data = try await newItem.loadTransferable(type: Data.self)
                                                    print("DEBUG: Successfully loaded image data: \(data?.count ?? 0) bytes")
                                                    
                                                    if let data = data, let uiImage = UIImage(data: data) {
                                                        print("DEBUG: Successfully converted to UIImage")
                                                        await MainActor.run {
                                                            self.profileImage = uiImage
                                                            self.displayImage = Image(uiImage: uiImage)
                                                            print("DEBUG: Updated profileImage and displayImage")
                                                        }
                                                    } else {
                                                        print("DEBUG: Failed to convert data to UIImage")
                                                    }
                                                } catch {
                                                    print("DEBUG: Error loading image data: \(error.localizedDescription)")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 24)
                            
                            // Name
                            if isEditing {
                                VStack(alignment: .leading, spacing: 20) {
                                    // First Name
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("First Name")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(TailwindColors.gray500)
                                        
                                        TextField("First Name", text: $firstName)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(TailwindColors.zinc400, lineWidth: 1)
                                            )
                                    }
                                    
                                    // Last Name
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Last Name")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(TailwindColors.gray500)
                                        
                                        TextField("Last Name", text: $lastName)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(TailwindColors.zinc400, lineWidth: 1)
                                            )
                                    }
                                    
                                    // Email
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Email")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(TailwindColors.gray500)
                                        
                                        TextField("Email", text: $email)
                                            .keyboardType(.emailAddress)
                                            .autocapitalization(.none)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(TailwindColors.zinc400, lineWidth: 1)
                                            )
                                    }
                                    
                                    // Phone Number
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Phone Number")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(TailwindColors.gray500)
                                        
                                        TextField("Phone Number", text: $phoneNumber)
                                            .keyboardType(.phonePad)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(TailwindColors.zinc400, lineWidth: 1)
                                            )
                                    }
                                    
                                    // Gender
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Gender")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(TailwindColors.gray500)
                                        
                                        Picker("Gender", selection: $gender) {
                                            ForEach(genderOptions, id: \.self) { option in
                                                Text(option).tag(option)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(TailwindColors.zinc400, lineWidth: 1)
                                        )
                                    }
                                    
                                    // Date of Birth
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Date of Birth")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(TailwindColors.gray500)
                                        
                                        DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                            .labelsHidden()
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(TailwindColors.zinc400, lineWidth: 1)
                                            )
                                    }
                                    
                                    // Save Button
                                    Button(action: saveProfile) {
                                        ZStack {
                                            Rectangle()
                                                .fill(userRole == "Coach" ? TailwindColors.violet600 : Color(red: 251/255, green: 146/255, blue: 60/255))
                                                .cornerRadius(8)
                                                .frame(height: 50)
                                            
                                            if isSaving {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.2)
                                            } else {
                                                Text("Save Changes")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .disabled(isSaving)
                                    .padding(.top, 10)
                                    
                                    // Cancel Button
                                    Button(action: {
                                        // Reset to original values
                                        if let profile = profile {
                                            firstName = profile.firstName
                                            lastName = profile.lastName
                                            email = profile.email
                                            gender = profile.gender
                                            phoneNumber = profile.phoneNumber
                                            dateOfBirth = profile.dateOfBirth
                                        }
                                        isEditing = false
                                    }) {
                                        Text("Cancel")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(TailwindColors.gray600)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(TailwindColors.gray400, lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else {
                                // Display view (non-editing mode)
                                VStack(spacing: 8) {
                                    Text("\(firstName) \(lastName)")
                                        .font(.system(size: 24, weight: .bold))
                                    
                                    Text(userRole == "Coach" ? "Coach" : "Student")
                                        .font(.system(size: 16))
                                        .foregroundColor(userRole == "Coach" ? TailwindColors.violet600 : Color(red: 251/255, green: 146/255, blue: 60/255))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(userRole == "Coach" ? TailwindColors.violet100 : Color(red: 255/255, green: 237/255, blue: 213/255))
                                        .cornerRadius(16)
                                }
                                
                                // Profile Information
                                VStack(spacing: 20) {
                                    ProfileInfoRow(icon: "envelope.fill", title: "Email", value: email, userRole: userRole)
                                    ProfileInfoRow(icon: "phone.fill", title: "Phone", value: phoneNumber.isEmpty ? "Not provided" : phoneNumber, userRole: userRole)
                                    ProfileInfoRow(icon: "calendar", title: "Date of Birth", value: formatDate(dateOfBirth), userRole: userRole)
                                    ProfileInfoRow(icon: "person.fill", title: "Gender", value: gender, userRole: userRole)
                                }
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                
                                // Edit Profile Button
                                Button(action: {
                                    isEditing = true
                                }) {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Edit Profile")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(userRole == "Coach" ? TailwindColors.violet600 : Color(red: 251/255, green: 146/255, blue: 60/255))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                
                                // Sign Out Button
                                Button(action: {
                                    showSignOutConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Sign Out")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(TailwindColors.gray600)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(TailwindColors.gray400, lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Success", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your profile has been updated successfully!")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadProfile()
            }
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        print("DEBUG: Starting to load profile for user: \(user.uid)")
        
        // Try to load profile from Firestore
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(user.uid).getDocument()
            
            if document.exists, let data = document.data() {
                print("DEBUG: Found profile document in Firestore: \(data)")
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                // Extract date of birth
                var dob = Date()
                if let dobTimestamp = data["dateOfBirth"] as? Timestamp {
                    dob = dobTimestamp.dateValue()
                } else if let dobString = data["dateOfBirth"] as? String {
                    dob = dateFormatter.date(from: dobString) ?? Date()
                }
                
                // Get the user's role from Firestore, default to current role if not found
                let userRole = data["role"] as? String ?? self.userRole
                
                // Get profile image URL
                let profileImageURL = data["profileImageURL"] as? String ?? ""
                print("DEBUG: Found profileImageURL: \(profileImageURL)")
                
                // Create the user profile
                let profile = UserProfile(
                    id: user.uid,
                    firstName: data["firstName"] as? String ?? "",
                    lastName: data["lastName"] as? String ?? "",
                    dateOfBirth: dob,
                    phoneNumber: data["phoneNumber"] as? String ?? "",
                    gender: data["gender"] as? String ?? "Male",
                    email: data["email"] as? String ?? user.email ?? "",
                    profileImageURL: profileImageURL,
                    role: userRole
                )
                
                // Update the state variables
                await MainActor.run {
                    self.profile = profile
                    self.firstName = profile.firstName
                    self.lastName = profile.lastName
                    self.email = profile.email
                    self.gender = profile.gender
                    self.phoneNumber = profile.phoneNumber
                    self.dateOfBirth = profile.dateOfBirth
                    self.userRole = userRole // Use the role from Firestore or current role
                    self.profileImageURL = profile.profileImageURL
                    print("DEBUG: Set profileImageURL to: \(profile.profileImageURL)")
                    
                    // Load profile image if available
                    if !profile.profileImageURL.isEmpty {
                        print("DEBUG: Attempting to load profile image from URL: \(profile.profileImageURL)")
                        loadProfileImage(from: profile.profileImageURL)
                    } else {
                        print("DEBUG: No profile image URL available")
                    }
                    
                    self.isLoading = false
                }
            } else {
                print("DEBUG: No profile document found, creating default profile")
                // If no document exists, create a default profile with the current role
                let defaultProfile = UserProfile(
                    id: user.uid,
                    firstName: "",
                    lastName: "",
                    email: user.email ?? "",
                    role: self.userRole // Preserve the current role
                )
                
                await MainActor.run {
                    self.profile = defaultProfile
                    self.email = defaultProfile.email
                    self.isLoading = false
                }
            }
        } catch {
            print("ERROR: Failed to load profile: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                self.showingError = true
                self.isLoading = false
            }
        }
    }
    
    private func loadProfileImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("DEBUG: Invalid URL format: \(urlString)")
            return
        }
        
        Task {
            do {
                print("DEBUG: Starting image download from: \(url)")
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: Image download status: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        print("DEBUG: Failed to download image, status: \(httpResponse.statusCode)")
                        return
                    }
                }
                
                guard let uiImage = UIImage(data: data) else {
                    print("DEBUG: Downloaded data could not be converted to image")
                    return
                }
                
                print("DEBUG: Successfully loaded image, size: \(data.count) bytes")
                
                await MainActor.run {
                    self.profileImage = uiImage
                    self.displayImage = Image(uiImage: uiImage)
                    print("DEBUG: Updated profile image in UI")
                }
            } catch {
                print("DEBUG: Error loading image: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveProfile() {
        guard let user = Auth.auth().currentUser, let profile = profile else {
            errorMessage = "User not found"
            showingError = true
            return
        }
        
        isSaving = true
        
        // Start the save process
        Task {
            do {
                // Basic profile data first (without image URL)
                var profileData: [String: Any] = [
                    "firstName": firstName,
                    "lastName": lastName,
                    "dateOfBirth": dateOfBirth,
                    "phoneNumber": phoneNumber,
                    "gender": gender,
                    "email": email,
                    "role": userRole
                ]
                
                // Update Firestore first with basic profile data
                print("DEBUG: Saving basic profile data to Firestore")
                let db = Firestore.firestore()
                try await db.collection("users").document(user.uid).setData(profileData, merge: true)
                print("DEBUG: Basic profile data saved successfully")
                
                // If we have a new profile image, upload it separately after basic profile is saved
                if let profileImage = profileImage {
                    print("DEBUG: Starting image upload process")
                    
                    // Use very simple filename at the root level for maximum permissions
                    let imageName = "\(user.uid).jpg"
                    print("DEBUG: Using image name: \(imageName)")
                    
                    // Convert image to data with moderate compression
                    guard let imageData = profileImage.jpegData(compressionQuality: 0.7) else {
                        throw NSError(domain: "ProfileView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
                    }
                    print("DEBUG: Successfully converted image to data: \(imageData.count) bytes")
                    
                    do {
                        // Get storage reference at the root level
                        let storageRef = Storage.storage().reference().child(imageName)
                        print("DEBUG: Created storage reference at root: \(storageRef.fullPath)")
                        
                        // Upload the image with put data
                        _ = try await storageRef.putData(imageData)
                        print("DEBUG: Image upload completed successfully")
                        
                        // Get download URL
                        let downloadURL = try await storageRef.downloadURL()
                        print("DEBUG: Got download URL: \(downloadURL.absoluteString)")
                        
                        // Update profileImageURL in Firestore separately
                        try await db.collection("users").document(user.uid).updateData([
                            "profileImageURL": downloadURL.absoluteString
                        ])
                        print("DEBUG: Profile image URL updated in Firestore")
                        
                        // Update local state
                        self.profileImageURL = downloadURL.absoluteString
                    } catch {
                        print("DEBUG: Error during image upload: \(error.localizedDescription)")
                        print("DEBUG: Continuing with profile save without image")
                    }
                }
                
                // Verify the profile data was saved, including the image URL if there was one
                do {
                    let userDoc = try await db.collection("users").document(user.uid).getDocument()
                    if let userData = userDoc.data() {
                        print("DEBUG: Final saved profile data: \(userData)")
                    } else {
                        print("DEBUG: Warning: Couldn't verify user data after save")
                    }
                } catch {
                    print("DEBUG: Error verifying saved data: \(error.localizedDescription)")
                }
                
                // Create updated profile object
                let updatedProfile = UserProfile(
                    id: user.uid,
                    firstName: firstName,
                    lastName: lastName,
                    dateOfBirth: dateOfBirth,
                    phoneNumber: phoneNumber,
                    gender: gender,
                    email: email,
                    profileImageURL: profileImageURL,
                    role: userRole
                )
                
                // Update local profile
                await MainActor.run {
                    self.profile = updatedProfile
                    isSaving = false
                    isEditing = false
                    showingSaveSuccess = true
                }
                
                print("DEBUG: Profile update completed successfully")
            } catch {
                print("DEBUG: Error saving profile: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            // The AuthViewModel will handle the auth state change
        } catch {
            alertMessage = "Failed to sign out: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let userRole: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(userRole == "Coach" ? TailwindColors.violet600 : Color(red: 251/255, green: 146/255, blue: 60/255))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct StudentProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StudentProfileView()
                .environmentObject(MockAuthViewModel(role: .student))
                .previewDisplayName("Student Profile")
            
            
        }
    }
}
