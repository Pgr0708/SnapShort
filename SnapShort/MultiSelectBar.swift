//
//  MultiSelectBar.swift
//  SnapShort
//

import SwiftUI

/// Bottom action bar shown when multi-select mode is active.
/// Used in both ContentView and CategoryDetailView.
struct MultiSelectBar: View {
    @ObservedObject var selectionManager: SelectionManager
    let onDeleteSelected: () -> Void
    let onSelectAll: () -> Void
    let onSaveAlbum: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                // Select All
                BarButton(
                    icon: "checkmark.circle.fill",
                    label: "All",
                    color: Color(hex: "#4A5FE8"),
                    action: onSelectAll
                )

                // Save as Album
                BarButton(
                    icon: "photo.on.rectangle.angled",
                    label: "Album",
                    color: Color(hex: "#34C759"),
                    action: onSaveAlbum
                )
                .disabled(!selectionManager.hasSelection)
                .opacity(selectionManager.hasSelection ? 1 : 0.4)

                // Delete selected
                BarButton(
                    icon: "trash.fill",
                    label: "Delete",
                    color: .red,
                    action: onDeleteSelected
                )
                .disabled(!selectionManager.hasSelection)
                .opacity(selectionManager.hasSelection ? 1 : 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 24)
            .background(.regularMaterial)
        }
    }
}

private struct BarButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
