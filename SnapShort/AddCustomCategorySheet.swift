//
//  AddCustomCategorySheet.swift
//  SnapShort
//

import SwiftUI

struct AddCustomCategorySheet: View {
    let onSave: (String, String, String, [String]) -> Void
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColor: String = "#4A5FE8"
    @State private var keywordsText: String = ""
    @Environment(\.dismiss) private var dismiss
    
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
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: selectedColor).opacity(0.8), Color(hex: selectedColor)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
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
                            
                            TextField("e.g. My Taxes, Wedding 2026…", text: $name)
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
                            
                            TextField("e.g. receipt, tax, invoice, deduction", text: $keywordsText)
                                .font(.system(size: 15))
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            
                            // Keyword pill preview
                            if !parsedKeywords.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(parsedKeywords, id: \.self) { kw in
                                            Text(kw)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color(hex: selectedColor))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color(hex: selectedColor).opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            Text("Photos containing these words (in OCR text or notes) will be automatically added to this category.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
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
                                    ColorSwatchCell(hex: hex, isSelected: selectedColor == hex)
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
                                    IconOptionCell(
                                        symbol: option.symbol,
                                        isSelected: selectedIcon == option.symbol,
                                        accentHex: selectedColor
                                    )
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
                            Text("Create Category")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Group {
                                        if nameIsEmpty {
                                            Color(hex: "#D1D5DB")
                                        } else {
                                            LinearGradient(
                                                colors: [Color(hex: "#4A5FE8"), Color(hex: "#7B5EA7")],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        }
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(nameIsEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#4A5FE8"))
                }
            }
        }
    }
}

// MARK: - Icon Option Cell

private struct IconOptionCell: View {
    let symbol: String
    let isSelected: Bool
    let accentHex: String
    
    private var bgColor: Color { isSelected ? Color(hex: accentHex).opacity(0.15) : Color.white }
    private var fgColor: Color { isSelected ? Color(hex: accentHex) : Color(hex: "#6B7280") }
    private var strokeColor: Color { isSelected ? Color(hex: accentHex) : Color.clear }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(bgColor).frame(height: 44)
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(fgColor)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(strokeColor, lineWidth: 1.5))
    }
}

// MARK: - Color Swatch Cell

private struct ColorSwatchCell: View {
    let hex: String
    let isSelected: Bool
    
    private var strokeWidth: CGFloat { isSelected ? 3 : 0 }
    private var shadowRadius: CGFloat { isSelected ? 4 : 0 }
    private var baseColor: Color { Color(hex: hex) }
    
    var body: some View {
        Circle()
            .fill(baseColor)
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(.white, lineWidth: strokeWidth).padding(2))
            .shadow(color: baseColor.opacity(0.5), radius: shadowRadius)
    }
}
