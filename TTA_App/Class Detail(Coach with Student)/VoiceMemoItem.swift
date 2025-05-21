import SwiftUI
struct VoiceMemoItem: View {
    let author: String
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Use the microphone image from assets
            Image("Microphone")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 63)
                .cornerRadius(4)
                
            Text("\(author) \(date)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.71))
        }
    }
}
