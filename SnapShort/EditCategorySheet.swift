//
//  EditCategorySheet.swift
//  SnapShort
//

import SwiftUI

struct EditCategorySheet: View {
    let category: SmartCategory
    let onSave: (String, String, String, [String]) -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var keywordsText: String
    @Environment(\.dismiss) private var dismiss

    init(category: SmartCategory, onSave: @escaping (String, String, String, [String]) -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.colorHex)
        _keywordsText = State(initialValue: category.ocrKeywords.joined(separator: ", "))
    }

    private let iconOptions: [(symbol: String, label: String)] = [
        ("folder.fill", "Folder"), ("star.fill", "Star"), ("heart.fill", "Heart"),
        ("tag.fill", "Tag"), ("bookmark.fill", "Bookmark"), ("camera.fill", "Camera"),
        ("house.fill", "Home"), ("car.fill", "Car"), ("airplane", "Travel"),
        ("briefcase.fill", "Work"), ("book.closed.fill", "Books"), ("music.note", "Music"),
        ("gamecontroller.fill", "Games"), ("dumbbell.fill", "Fitness"), ("leaf.fill", "Plants"),
        ("gift.fill", "Gift"), ("lock.fill", "Private"), ("map.fill", "Maps"),
        ("cart.fill", "Shopping"), ("creditcard.fill", "Finance"), ("doc.text.fill", "Documents"),
        ("person.fill", "Person"), ("pawprint.fill", "Pets"), ("fork.knife", "Food")
    ]

    private let colorOptions: [String] = [
        "#4A5FE8", "#0A9396", "#E76F51", "#F4A261", "#2A9D8F",
        "#264653", "#E9C46A", "#6D6875", "#D62828", "#7B2FBE",
        "#FF6B35", "#40916C", "#457B9D", "#C77DFF", "#DC2626",
        "#0EA5E9", "#F59E0B", "#1B4332", "#78350F", "#374151"
    ]

    private var parsedKeywords: [String] {
        keywordsText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#F5F5F7").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Preview card
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: selectedColor).opacity(0.8), Color(hex: selectedColor)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 100, height: 100)
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                            Text(name.isEmpty ? "Category Name" : name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1C1C1E"))
                        }
                        .padding(.top, 16)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Category Name", systemImage: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#6B7280"))
                            TextField("Category name…", text: $name)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        }
                        .padding(.horizontal, 20)

                        // Keywords field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Keywords (comma-separated)", systemImage: "text.word.spacing")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#6B7280"))
                            TextField("e.g. receipt, tax, invoice", text: $keywordsText)
                                .font(.system(size: 15))
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            if !parsedKeywords.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(parsedKeywords, id: \.self) { kw in
                                            Text(kw)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color(hex: selectedColor))
                                                .padding(.horizontal, 10).padding(.vertical, 4)
                                                .background(Color(hex: selectedColor).opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Color picker
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Color", systemImage: "paintpalette.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#6B7280"))
                                .padding(.horizontal, 20)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 10) {
                                ForEach(colorOptions, id: \.self) { hex in
                                    EditColorSwatchCell(hex: hex, isSelected: selectedColor == hex)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.2)) { selectedColor = hex }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Icon", systemImage: "square.grid.2x2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#6B7280"))
                                .padding(.horizontal, 20)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(iconOptions, id: \.symbol) { option in
                                    EditIconOptionCell(symbol: option.symbol, isSelected: selectedIcon == option.symbol, accentHex: selectedColor)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.2)) { selectedIcon = option.symbol }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Save button
                        let nameIsEmpty = name.trimmingCharacters(in: .whitespaces).isEmpty
                        Button {
                            guard !nameIsEmpty else { return }
                            onSave(name, selectedIcon, selectedColor, parsedKeywords)
                        } label: {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Group {
                                    if nameIsEmpty {
                                        Color(hex: "#D1D5DB")
                                    } else {
                                        LinearGradient(
                                            colors: [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    }
                                })
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(nameIsEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color(hex: "#4A5FE8"))
                }
            }
        }
    }
}

private struct EditIconOptionCell: View {
    let symbol: String; let isSelected: Bool; let accentHex: String
    private var bg: Color { isSelected ? Color(hex: accentHex).opacity(0.15) : Color.white }
    private var fg: Color { isSelected ? Color(hex: accentHex) : Color(hex: "#6B7280") }
    private var stroke: Color { isSelected ? Color(hex: accentHex) : Color.clear }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(bg).frame(height: 44)
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(fg)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(stroke, lineWidth: 1.5))
    }
}

private struct EditColorSwatchCell: View {
    let hex: String; let isSelected: Bool
    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 0).padding(2))
            .shadow(color: Color(hex: hex).opacity(0.5), radius: isSelected ? 4 : 0)
    }
}
