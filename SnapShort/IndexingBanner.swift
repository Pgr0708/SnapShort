//
//  IndexingBanner.swift
//  SnapShort
//
//  Non-intrusive animated banner shown at the bottom of the photo grid
//  while background OCR / Vision tagging is running.
//

import SwiftUI

struct IndexingBanner: View {
    let message: String
    let progress: Double     // 0…1
    
    @State private var shimmer: Bool = false
    @State private var dotCount: Int = 1
    
    private let bannerColor = Color(hex: "#1C1C2E")
    private let accentColor = Color(hex: "#4A5FE8")
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Animated wand icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.pulse, options: .repeating)
                
                // Message + animated dots
                Text(message + dots)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Percentage
                if progress < 1.0 {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "#34C759"))
                        .font(.system(size: 14))
                }
            }
            
            // Progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)
                    
                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, Color(hex: "#0A9396")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * progress), height: 4)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                    
                    // Shimmer overlay on fill
                    if progress < 1.0 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear,
                                             Color.white.opacity(shimmer ? 0.3 : 0),
                                             .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * progress), height: 4)
                    }
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(bannerColor.opacity(0.95))
                .shadow(color: accentColor.opacity(0.25), radius: 10, y: 4)
        )
        .padding(.horizontal, 16)
        .onAppear {
            // Shimmer loop
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmer = true
            }
            // Animated dots
            Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { t in
                dotCount = (dotCount % 3) + 1
                if !shimmer { t.invalidate() }
            }
        }
    }
    
    private var dots: String {
        guard progress < 1.0 else { return "" }
        return String(repeating: ".", count: dotCount)
    }
}

// MARK: - Modifier

extension View {
    /// Overlays the indexing banner above the tab bar when background indexing is active.
    func indexingBannerOverlay(viewModel: HomeViewModel) -> some View {
        self.overlay(alignment: .bottom) {
            if viewModel.isBackgroundIndexing {
                IndexingBanner(
                    message: viewModel.backgroundIndexMessage,
                    progress: viewModel.backgroundIndexProgress
                )
                .padding(.bottom, 90)   // sit above tab bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.45), value: viewModel.isBackgroundIndexing)
            }
        }
    }
}
