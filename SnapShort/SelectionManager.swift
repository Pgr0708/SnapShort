//
//  SelectionManager.swift
//  SnapShort
//

import SwiftUI
internal import Combine

/// Shared multi-select state — injected as @EnvironmentObject into grids
final class SelectionManager: ObservableObject {
    @Published var isSelecting: Bool = false
    @Published var selectedIdentifiers: Set<String> = []

    var selectedCount: Int { selectedIdentifiers.count }
    var hasSelection: Bool { !selectedIdentifiers.isEmpty }

    func toggle(_ id: String) {
        if selectedIdentifiers.contains(id) {
            selectedIdentifiers.remove(id)
        } else {
            selectedIdentifiers.insert(id)
        }
    }

    func isSelected(_ id: String) -> Bool {
        selectedIdentifiers.contains(id)
    }

    func selectAll(_ ids: [String]) {
        selectedIdentifiers = Set(ids)
    }

    func clearSelection() {
        selectedIdentifiers.removeAll()
    }

    func exitSelection() {
        isSelecting = false
        selectedIdentifiers.removeAll()
    }
}
