//
//  CleanUpView.swift
//  SnapShort
//

import SwiftUI
import Photos

struct CleanUpView: View {
    @ObservedObject var viewModel: HomeViewModel

    // Category the user tapped → navigates to detail grid
    @State private var activeCategoryType: CleanUpCategoryType?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#F5F5F7").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Subtitle
                        Text("Free up space in seconds")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                            .padding(.horizontal, 24)
                            .padding(.top, 4)

                        // Summary Card
                        SummaryCard(analysis: viewModel.cleanUpAnalysis, isAnalyzing: viewModel.isAnalyzing)
                            .padding(.horizontal, 20)

                        // Analyze button (only before first analysis)
                        if viewModel.cleanUpAnalysis == nil && !viewModel.isAnalyzing {
                            Button {
                                Task { await viewModel.analyzeForCleanUp() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                    Text("Analyze My Library")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 20)
                        }

                        // Review & Clean section
                        if viewModel.cleanUpAnalysis != nil || viewModel.isAnalyzing {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Review & Clean")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: "#1C1C1E"))
                                    .padding(.horizontal, 24)

                                ForEach(CleanUpCategoryType.allCases) { type in
                                    CleanUpCategoryRow(
                                        type: type,
                                        analysis: viewModel.cleanUpAnalysis,
                                        isAnalyzing: viewModel.isAnalyzing
                                    ) {
                                        activeCategoryType = type
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Clean Up")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.cleanUpAnalysis != nil {
                        Button {
                            Task { await viewModel.analyzeForCleanUp() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#4A5FE8"))
                        }
                    }
                }
            }
            .sheet(item: $activeCategoryType) { type in
                CleanUpCategoryView(
                    type: type,
                    identifiers: viewModel.identifiers(for: type),
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let analysis: CleanUpAnalysis?
    let isAnalyzing: Bool

    private var organizedPct: Double {
        guard let a = analysis, a.totalItems > 0 else { return 0 }
        // rough metric: % of library that's "clean"
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let total = max(1, PHAsset.fetchAssets(with: opts).count)
        let messy = Double(a.totalItems)
        return max(0, min(1.0, 1.0 - messy / Double(total)))
    }

    var body: some View {
        HStack(spacing: 20) {
            // Circular ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: organizedPct)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(organizedPct * 100))%")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("ORGANIZED")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 90, height: 90)
            .animation(.spring(response: 0.8), value: organizedPct)

            // Stats
            if isAnalyzing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView().tint(.white).scaleEffect(1.2)
                    Text("Analyzing…").foregroundStyle(.white.opacity(0.9)).font(.system(size: 14))
                }
            } else if let a = analysis {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.reclaimableMB)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("reclaimable")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(a.totalItems) items")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("to review")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tap Analyze to scan\nyour photo library")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#4A5FE8"), Color(hex: "#0A9396")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#4A5FE8").opacity(0.3), radius: 16, y: 6)
    }
}

// MARK: - Category Row

private struct CleanUpCategoryRow: View {
    let type: CleanUpCategoryType
    let analysis: CleanUpAnalysis?
    let isAnalyzing: Bool
    let onTap: () -> Void

    private var count: Int {
        guard let a = analysis else { return 0 }
        return type.identifiers(from: a).count
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Colored left bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(type.accentColor)
                    .frame(width: 4, height: 52)

                // Icon circle
                ZStack {
                    Circle()
                        .fill(type.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(type.accentColor)
                }

                // Title + subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1C1C1E"))
                    if isAnalyzing {
                        Text("Scanning…")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    } else {
                        Text(count == 0 ? "None found" : "\(count) items")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    }
                }

                Spacer()

                // Badge
                if isAnalyzing {
                    ProgressView().scaleEffect(0.7)
                } else if count > 0 {
                    ZStack {
                        Circle()
                            .fill(type.accentColor)
                            .frame(width: 30, height: 30)
                        Text("\(min(count, 99))\(count > 99 ? "+" : "")")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "#34C759"))
                        .font(.system(size: 22))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#D1D5DB"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(count == 0 && !isAnalyzing)
    }
}

// MARK: - Category Types

enum CleanUpCategoryType: String, CaseIterable, Identifiable {
    case duplicates   = "Duplicates"
    case similarShots = "Similar Shots"
    case oldUnused    = "Old & Unused"
    case blurry       = "Blurry"

    var id: String { rawValue }

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .duplicates:   return "doc.on.doc.fill"
        case .similarShots: return "photo.stack.fill"
        case .oldUnused:    return "clock.arrow.circlepath"
        case .blurry:       return "aqi.medium"
        }
    }

    var accentColor: Color {
        switch self {
        case .duplicates:   return Color(hex: "#4A5FE8")
        case .similarShots: return Color(hex: "#A97B53")
        case .oldUnused:    return Color(hex: "#4B5563")
        case .blurry:       return Color(hex: "#DC2626")
        }
    }

    var description: String {
        switch self {
        case .duplicates:   return "Identical copies of the same photo"
        case .similarShots: return "Photos taken within 10 seconds of each other"
        case .oldUnused:    return "Photos older than 2 years"
        case .blurry:       return "Out-of-focus or blurry images"
        }
    }

    func identifiers(from analysis: CleanUpAnalysis) -> [String] {
        switch self {
        case .duplicates:   return analysis.duplicateIdentifiers
        case .similarShots: return analysis.similarShotIdentifiers
        case .oldUnused:    return analysis.oldUnusedIdentifiers
        case .blurry:       return analysis.blurryIdentifiers
        }
    }
}
