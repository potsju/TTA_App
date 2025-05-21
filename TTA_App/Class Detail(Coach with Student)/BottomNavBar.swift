//
//  BottomNavBar.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct BottomNavBar: View {
    @State private var selectedTab = 0

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            // Home Tab
            VStack(spacing: 6) {
                HomeIcon()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.07))

                Text("Home")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.07))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .onTapGesture {
                selectedTab = 0
            }

            Spacer()

            // Wallet Tab
            VStack(spacing: 6) {
                WalletIcon()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(red: 0.62, green: 0.7, blue: 0.81))

                Text("")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .onTapGesture {
                selectedTab = 1
            }

            Spacer()

            // Stats Tab
            VStack(spacing: 6) {
                StatsIcon()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(red: 0.62, green: 0.7, blue: 0.81))

                Text("")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .onTapGesture {
                selectedTab = 2
            }

            Spacer()

            // Profile Tab
            VStack(spacing: 6) {
                ProfileIcon()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(red: 0.62, green: 0.7, blue: 0.81))

                Text("")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .onTapGesture {
                selectedTab = 3
            }

            Spacer()
        }
        .frame(height: 47)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
    }
}

struct HomeIcon: View {
    var body: some View {
        Image(systemName: "house.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct WalletIcon: View {
    var body: some View {
        Image(systemName: "creditcard")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct StatsIcon: View {
    var body: some View {
        Image(systemName: "chart.pie")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct ProfileIcon: View {
    var body: some View {
        Image(systemName: "person")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct BottomNavBar_Previews: PreviewProvider {
    static var previews: some View {
        BottomNavBar()
            .previewLayout(.sizeThatFits)
    }
}
