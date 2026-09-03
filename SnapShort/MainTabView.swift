//
//  MainTabView.swift
//  SnapShort
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var settings: SettingsManager
    let homeViewModel: HomeViewModel
    
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1 - Photos
            RootView(homeViewModel: homeViewModel)
                .tabItem {
                    Label("Photos", systemImage: selectedTab == 0 ? "photo.fill.on.rectangle.fill" : "photo.on.rectangle")
                }
                .tag(0)
            
            // Tab 2 - Categories
            CategoriesView(viewModel: homeViewModel)
                .tabItem {
                    Label("Categories", systemImage: selectedTab == 1 ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .tag(1)
            
            // Tab 3 - Settings (reuse SettingsView with environment settings object)
            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(Color(hex: "#4A5FE8"))
    }
}
