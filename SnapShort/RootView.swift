//
//  AppRoot.swift
//  GoViral
//
//  Created by Minaxi on 16/08/26.
//

import SwiftUI

enum AppFlow {
    case splash
    case language
    case onboarding
    case paywall
    case notification
    case customization
    case home
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsManager
    let homeViewModel: HomeViewModel
    
    var currentFlow: AppFlow {
        if !settings.hasSeenLanguage {
            return .language
        } else {
            return .home
        }
    }
    
    var body: some View {
        switch currentFlow {
        case .language:
            LanguageScreenView()
            
        case .onboarding:
            OnBoardingScreenView()
            
        case .paywall:
            PaywallScreenView()
            
        case .notification:
            NotificationScreenView()
            
        case .customization:
            CustomizationScreenView()
            
        case .home:
            ContentView(viewModel: homeViewModel)
            
        default:
            SplashScreenView()
        }
    }
}
