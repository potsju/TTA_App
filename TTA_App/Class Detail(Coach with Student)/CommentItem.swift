//
//  CommentItem.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct CommentItem: View {
    let commentText: String
    let author: String
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commentText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.05))
                .padding(.bottom, 1)

            Text("\(author) \(date)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.71))
        }
    }
}

struct CommentItem_Previews: PreviewProvider {
    static var previews: some View {
        CommentItem(
            commentText: "Need to work on forehand",
            author: "Manager Danny",
            date: "3/25/25 5:42 pm"
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.white)
    }
}
