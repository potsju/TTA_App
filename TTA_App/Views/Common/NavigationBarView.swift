//
//  NavigationBarView.swift
//  TTA_App
//
//  Created by Darren Choe on 3/25/25.
//

import SwiftUI

struct NavigationBarView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: getIconName(for: index))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            Text(getTabName(for: index))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selectedTab == index ? TailwindColors.violet400 : TailwindColors.gray400)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .background(Color.white)
    }

    private func getIconName(for index: Int) -> String {
        switch index {
        case 0:
            return "house.fill"
        case 1:
            return "calendar"
        case 2:
            return "wallet.pass.fill"
        case 3:
            return "person.crop.circle"
        default:
            return "questionmark"
        }
    }

    private func getTabName(for index: Int) -> String {
        switch index {
        case 0:
            return "Home"
        case 1:
            return "Class"
        case 2:
            return "Balance"
        case 3:
            return "Profile"
        default:
            return ""
        }
    }
}

struct NavigationBarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBarView()
            .previewLayout(.sizeThatFits)
    }
}
