//
//  CategoriesView.swift
//  SnapShort
//

import SwiftUI
import Photos

struct CategoriesView: View {
    @ObservedObject var viewModel: HomeViewModel

    @State private var searchText: String = ""
    @State private var selectedGroup: CategoryGroup = .all
    @State private var showOnlyWithPhotos: Bool = false
    @State private var showAddCategory: Bool = false
    @State private var isCategorizing: Bool = false
    
    // Edit / Delete state
    @State private var categoryToEdit: SmartCategory?
    @State private var categoryToDelete: SmartCategory?
    @State private var showDeleteConfirm: Bool = false

    private var filteredCategories: [SmartCategory] {
        let base = viewModel.allCategories
        var result = selectedGroup == .all ? base : base.filter { $0.group == selectedGroup }
        
        // Always filter out sparse categories (< minimum threshold) UNLESS the user opts to see all,
        // OR the category is custom (user-created always shows).
        if !showOnlyWithPhotos {
            result = result.filter {
                $0.isCustom || $0.photoCount >= SmartCategory.minimumPhotosToDisplay
            }
        } else {
            // "Show all" mode: still hide categories with zero photos (but show 1-2)
            result = result.filter { $0.isCustom || $0.photoCount > 0 }
        }
        
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.group.rawValue.lowercased().contains(q) ||
                $0.ocrKeywords.contains { $0.contains(q) } ||
                $0.visionTags.contains { $0.contains(q) }
            }
        }
        return result.sorted { $0.photoCount > $1.photoCount } // Most photos first
    }

    private var groups: [CategoryGroup] {
        [.all, .documents, .screenshots, .lifestyle, .people, .nature, .custom]
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#F5F5F7").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                            .font(.system(size: 15))
                        TextField("Search categories…", text: $searchText)
                            .font(.system(size: 15))
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color(hex: "#9CA3AF"))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Overview Banner & "With Photos" Toggle
                    let totalCategorized = viewModel.allCategories.reduce(0) { $0 + $1.photoCount }
                    let activeCount = viewModel.allCategories.filter { $0.photoCount > 0 }.count
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            if isCategorizing {
                                ProgressView().scaleEffect(0.7).tint(Color(hex: "#4A5FE8"))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: "#4A5FE8"))
                            }
                            Text(totalCategorized > 0
                                 ? "\(totalCategorized) photo\(totalCategorized == 1 ? "" : "s") in \(activeCount) categories"
                                 : "Auto-categorizing photos…")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "#4B5563"))
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                showOnlyWithPhotos.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showOnlyWithPhotos ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                Text(showOnlyWithPhotos ? "1+ Photos" : "3+ Photos")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(showOnlyWithPhotos ? Color(hex: "#F59E0B") : Color(hex: "#4A5FE8"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                showOnlyWithPhotos
                                    ? Color(hex: "#F59E0B").opacity(0.12)
                                    : Color(hex: "#4A5FE8").opacity(0.10)
                            )
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Group filter carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(groups) { group in
                                GroupChip(group: group, isSelected: selectedGroup == group) {
                                    withAnimation(.spring(response: 0.3)) { selectedGroup = group }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }

                    // Category grid
                    ScrollView {
                        if filteredCategories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color(hex: "#D1D5DB"))
                                Text(searchText.isEmpty
                                     ? (showOnlyWithPhotos ? "No categories with 1+ photos" : "No categories with 3+ photos yet")
                                     : "No results for \"\(searchText)\"")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(hex: "#9CA3AF"))
                                    .multilineTextAlignment(.center)
                                if searchText.isEmpty {
                                    Button(showOnlyWithPhotos ? "Raise threshold to 3+" : "Show 1-2 photo categories") {
                                        withAnimation { showOnlyWithPhotos.toggle() }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#4A5FE8"))
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(filteredCategories) { category in
                                    NavigationLink(destination: CategoryDetailView(category: category, viewModel: viewModel)) {
                                        CategoryCard(category: category)
                                    }
                                    .buttonStyle(.plain)
                                    // Long-press context menu
                                    .contextMenu {
                                        // Save as Album — available for all categories
                                        Button {
                                            Task { await viewModel.saveAsAlbum(category: category) }
                                        } label: {
                                            Label("Save as Album in Photos", systemImage: "photo.on.rectangle.angled")
                                        }
                                        
                                        // Edit — only custom categories
                                        if category.isCustom {
                                            Button {
                                                categoryToEdit = category
                                            } label: {
                                                Label("Edit Category", systemImage: "pencil")
                                            }
                                        }
                                        
                                        // Delete — only custom categories
                                        if category.isCustom {
                                            Divider()
                                            Button(role: .destructive) {
                                                categoryToDelete = category
                                                showDeleteConfirm = true
                                            } label: {
                                                Label("Delete Category", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                    .refreshable {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isCategorizing = true
                        await viewModel.buildCategoryIndex()
                        isCategorizing = false
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: "#4A5FE8"))
                    }
                }
            }
            // Add new custom category sheet
            .sheet(isPresented: $showAddCategory) {
                AddCustomCategorySheet { name, icon, color, keywords in
                    Task {
                        await viewModel.addCustomCategory(name: name, icon: icon, colorHex: color, keywords: keywords)
                        showAddCategory = false
                    }
                }
            }
            // Edit existing custom category sheet
            .sheet(item: $categoryToEdit) { cat in
                EditCategorySheet(category: cat) { name, icon, color, keywords in
                    Task {
                        await viewModel.editCustomCategory(id: cat.id, name: name, icon: icon, colorHex: color, keywords: keywords)
                        categoryToEdit = nil
                    }
                }
            }
            // Delete confirmation alert
            .alert("Delete \"\(categoryToDelete?.name ?? "")\"?",
                   isPresented: $showDeleteConfirm,
                   presenting: categoryToDelete) { cat in
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteCustomCategory(id: cat.id)
                        categoryToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { categoryToDelete = nil }
            } message: { cat in
                Text("This will remove the \"\(cat.name)\" category from SnapShort. Photos in your library will not be deleted.")
            }
            // Result alert (save album confirmation)
            .alert("Done", isPresented: Binding(
                get: { viewModel.scanError != nil },
                set: { if !$0 { viewModel.scanError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.scanError ?? "")
            }
            // Automatic background categorization
            .task {
                if viewModel.allCategories.isEmpty {
                    await viewModel.loadCategories()
                }
                // Automatically build index if counts are 0
                if viewModel.allCategories.allSatisfy({ $0.photoCount == 0 }) {
                    isCategorizing = true
                    await viewModel.buildCategoryIndex()
                    isCategorizing = false
                }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

// MARK: - Group Chip

private struct GroupChip: View {
    let group: CategoryGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: group.icon).font(.system(size: 11, weight: .semibold))
                Text(group.rawValue).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Color(hex: "#6B7280"))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color(hex: "#4A5FE8") : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.05), radius: 4, y: 2)
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: SmartCategory
    
    private var isAlbumSavedInPhotos: Bool {
        let albumTitle = "\(category.emoji) \(category.name)"
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", albumTitle)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        return collections.count > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let uiImage = UIImage(named: "cat_\(category.id)") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 94)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                } else {
                    // Background linear gradient fallback
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: category.gradientColors,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(height: 94)
                        // Glass shine highlight overlay
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .shadow(color: category.gradientColors.first?.opacity(0.32) ?? Color.black.opacity(0.08), radius: 6, y: 3)

                    if category.isCustom {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 50, height: 50)
                            Image(systemName: category.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Emoji floating with subtle depth shadow
                        Text(category.emoji)
                            .font(.system(size: 38))
                            .shadow(color: Color.black.opacity(0.18), radius: 3, y: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    }
                }

                // Photo count pill (top trailing)
                if category.photoCount > 0 {
                    Text("\(category.photoCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                        .padding(8)
                }

                // In Photos Saved badge (top leading)
                if isAlbumSavedInPhotos {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("In Photos")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#10B981").opacity(0.9))
                    .clipShape(Capsule())
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if category.isCustom {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(category.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1C1C1E"))
                        .lineLimit(1)
                    
                    if isAlbumSavedInPhotos {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }
                
                Text(category.photoCount == 0 ? "No photos yet" : "\(category.photoCount) photo\(category.photoCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}
