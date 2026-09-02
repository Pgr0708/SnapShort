//
//  SplashScreenView.swift
//  GoViral
//
//  Created by Minaxi on 16/08/26.
//

import SwiftUI
import Lottie

struct SplashScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    let homeViewModel: HomeViewModel
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        
        if isActive {
            RootView(homeViewModel: homeViewModel)
        } else {
            ZStack {
                LinearGradient(colors: [Color(hex: "#1A1F36"), Color(hex: "#0D0F1A")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                Image("onboardingBackground")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                
                
                VStack {
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                               color: .white.opacity(0.40),
                               radius: 20,
                        )
                        .padding(40)
                    
                    Text(AppInfo.appName)
                        .foregroundStyle(.white)
                        .font(.system(size: 36, weight: .bold))
                        .padding(.top, 14)
                    
//                    Text(String(localized: "Version \(AppInfo.version)"))
                    Text(L10n.splashScreenSubtitle)
                        .foregroundStyle(Color(hex: "#A0AEC0"))
                        .font(.system(size: 16))
                        .padding(.top, 4)
                }
                .padding()
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1)) {
                        size = 1.0
                        opacity = 1.0
                    }
                }
                
//                VStack(spacing: 8) {
//                    Spacer()
//                    
//                    LottieView(animation: .named("Loading"))
//                        .playing(loopMode: .loop)
//                        .frame(maxWidth: .infinity, maxHeight: 30)
//                    
//                    Text(String(localized: "Version \(AppInfo.version)"))
//                    
//                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            isActive = true
                        }
                    }
//                    for family in UIFont.familyNames.sorted() {
//                        print("Family: \(family)")
//
//                        for font in UIFont.fontNames(forFamilyName: family).sorted() {
//                            print("   \(font)")
//                        }
//                    }
                }
            }
        }
    }
}


