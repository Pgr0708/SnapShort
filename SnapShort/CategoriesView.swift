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
    @State private var showAddCategory: Bool = false
    @State private var isIndexing: Bool = false
    
    // Edit / Delete state
    @State private var categoryToEdit: SmartCategory?
    @State private var categoryToDelete: SmartCategory?
    @State private var showDeleteConfirm: Bool = false

    private var filteredCategories: [SmartCategory] {
        let base = viewModel.allCategories
        let groupFiltered = selectedGroup == .all ? base : base.filter { $0.group == selectedGroup }
        if searchText.isEmpty { return groupFiltered }
        let q = searchText.lowercased()
        return groupFiltered.filter {
            $0.name.lowercased().contains(q) ||
            $0.group.rawValue.lowercased().contains(q) ||
            $0.ocrKeywords.contains { $0.contains(q) } ||
            $0.visionTags.contains { $0.contains(q) }
        }
    }

    private var groups: [CategoryGroup] {
        [.all, .documents, .screenshots, .food, .people, .animals, .travel, .nature, .work, .vehicles, .fitness, .home, .custom]
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
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

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
                        .padding(.vertical, 12)
                    }

                    // Categorize button (only if no counts yet)
                    if viewModel.allCategories.allSatisfy({ $0.photoCount == 0 }) {
                        Button {
                            Task {
                                isIndexing = true
                                await viewModel.buildCategoryIndex()
                                isIndexing = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isIndexing {
                                    ProgressView().scaleEffect(0.8).tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isIndexing ? "Categorizing…" : "Categorize My Photos")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    // Category grid
                    ScrollView {
                        if filteredCategories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color(hex: "#D1D5DB"))
                                Text(searchText.isEmpty ? "No categories yet" : "No results for \"\(searchText)\"")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(hex: "#9CA3AF"))
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
            // Add new category
            .sheet(isPresented: $showAddCategory) {
                AddCustomCategorySheet { name, icon, color, keywords in
                    Task {
                        await viewModel.addCustomCategory(name: name, icon: icon, colorHex: color, keywords: keywords)
                        showAddCategory = false
                    }
                }
            }
            // Edit existing custom category
            .sheet(item: $categoryToEdit) { cat in
                EditCategorySheet(category: cat) { name, icon, color, keywords in
                    Task {
                        await viewModel.editCustomCategory(id: cat.id, name: name, icon: icon, colorHex: color, keywords: keywords)
                        categoryToEdit = nil
                    }
                }
            }
            // Delete confirmation
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
            // Result alerts (save album, errors)
            .alert("Done", isPresented: Binding(
                get: { viewModel.scanError != nil },
                set: { if !$0 { viewModel.scanError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.scanError ?? "")
            }
            .task {
                if viewModel.allCategories.isEmpty { await viewModel.loadCategories() }
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [Color(hex: category.colorHex).opacity(0.85), Color(hex: category.colorHex)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(height: 80)

                Text(category.emoji)
                    .font(.system(size: 36))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()

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

                if category.isCustom {
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
                Text(category.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1C1C1E"))
                    .lineLimit(1)
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
