//
//  IndexingBanner.swift
//  SnapShort
//
//  Slim non-blocking banner docked right above the bottom TabBar
//  while background OCR / Vision tagging is running.
//

import SwiftUI

struct IndexingBanner: View {
    let message: String
    let progress: Double     // 0…1
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated indicator
            if progress < 1.0 {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(.white)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#34C759"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#818CF8"))
                        .monospacedDigit()
                }
                
                // Slim sleek progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#4A5FE8"), Color(hex: "#06B6D4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(progress)), height: 4)
                            .animation(.spring(response: 0.3), value: progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#1E1E2E").opacity(0.96))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        )
    }
}
