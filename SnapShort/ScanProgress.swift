//
//  ScanProgress.swift
//  SnapShort
//

import Foundation
import Combine

@MainActor
final class ScanProgress: ObservableObject {
    @Published var processedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var estimatedSecondsRemaining: TimeInterval = 0
    @Published var isScanning: Bool = false
    @Published var currentService: String = ""
    
    var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        return Double(processedCount) / Double(totalCount)
    }
    
    func reset(service: String, total: Int) {
        self.currentService = service
        self.totalCount = total
        self.processedCount = 0
        self.estimatedSecondsRemaining = 0
        self.isScanning = true
    }
    
    func update(processed: Int, estimatedSecondsRemaining: TimeInterval) {
        self.processedCount = processed
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
    }
    
    func finish() {
        self.isScanning = false
        self.processedCount = self.totalCount
        self.estimatedSecondsRemaining = 0
    }
}
