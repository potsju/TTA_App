import SwiftUI

struct PreviewStudentDetail: View {
    var body: some View {
        EnhancedStudentDetailView2(studentId: "preview-id")
    }
}

struct PreviewStudentDetail_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard light mode preview
            PreviewStudentDetail()
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            PreviewStudentDetail()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // iPhone SE preview for smaller screens
            PreviewStudentDetail()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            // iPad preview
            PreviewStudentDetail()
                .previewDevice("iPad Pro (11-inch) (4th generation)")
                .previewDisplayName("iPad Pro 11")
        }
    }
} 