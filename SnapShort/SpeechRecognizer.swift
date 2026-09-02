//
//  SpeechRecognizer.swift
//  SnapShort
//

import Foundation
import Speech
import AVFoundation
internal import Combine
import SwiftUI

/// Manages live speech-to-text transcription for the search bar.
/// Call `startRecording()` to begin and `stopRecording()` to end.
/// The `transcript` published property updates in real-time as the user speaks.
@MainActor
final class SpeechRecognizer: ObservableObject {
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var permissionDenied: Bool = false
    @Published var errorMessage: String?
    
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        // Use device locale; fall back to en-US
        recognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // MARK: - Public API
    
    func requestPermissions() async -> Bool {
        // Speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            permissionDenied = true
            return false
        }
        
        // Microphone permission (iOS 17+)
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted {
                permissionDenied = true
                return false
            }
        } else {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    continuation.resume(returning: ok)
                }
            }
            if !granted {
                permissionDenied = true
                return false
            }
        }
        
        return true
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        Task {
            let ok = await requestPermissions()
            guard ok else { return }
            beginSession()
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
    
    // MARK: - Private
    
    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available right now."
            return
        }
        
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true  // live updates as you speak
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }
        
        // Tap the microphone input
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            return
        }
        
        self.audioEngine = engine
        self.recognitionRequest = request
        self.isRecording = true
        self.transcript = ""
        self.errorMessage = nil
        
        // Start recognition task — updates `transcript` with each partial result
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            
            // Stop automatically on final result or error
            if result?.isFinal == true || error != nil {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
    }
}
