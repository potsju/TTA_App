//
//  SessionDetailsView.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct SessionDetailsView: View {
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    BackButton()
                    Text("Coach Hailong 3/22/25 5:30-6:00 pm")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.05))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 56)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 0) {
                        // Comments Section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Comments")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(.black)
                                Spacer()
                                AddButton()
                            }

                            CommentItem(
                                commentText: "Need to work on forehand",
                                author: "Manager Danny",
                                date: "3/25/25 5:42 pm"
                            )

                            CommentItem(
                                commentText: "Work on Footwork, Develop Consistent Serving, Master different Spins",
                                author: "Manager Danny",
                                date: "3/25/25 5:42 pm"
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                        // Voice Memo Section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Voice Memo")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(.black)
                                Spacer()
                                AddButton()
                            }

                            VoiceMemoItem(
                                author: "Manager Danny",
                                date: "3/25/25 5:42 pm"
                            )

                            VoiceMemoItem(
                                author: "Manager Danny",
                                date: "3/25/25 5:42 pm"
                            )

                            Text("Coach Hailong 3/22/25 5:30 pm")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.71))
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 120)
                    }
                }

                Spacer()
            }

            // QR Code Button
            VStack {
                Spacer()
                Button(action: {
                    // Action for QR code button
                }) {
                    Text("View QR Code")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 288, height: 48)
                        .background(Color(red: 0.53, green: 0.12, blue: 0.94))
                        .cornerRadius(999)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
                .padding(.bottom, 67)
            }

            // Bottom Navigation Bar
            VStack {
                Spacer()
                BottomNavBar()
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct SessionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionDetailsView()
    }
}
