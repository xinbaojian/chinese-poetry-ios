import Speech
import AVFoundation
import SwiftUI

@Observable
final class SpeechRecognizer {
    var recognizedText = ""
    var isRecording = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var silenceTask: Task<Void, Never>?
    private var lastSpeechTime = Date()

    var isAvailable: Bool {
        return speechRecognizer != nil
    }

    func requestAuthorization() async -> Bool {
        guard speechRecognizer != nil else { return false }

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }

        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        return micGranted
    }

    func start(contextualStrings: [String]) throws {
        guard let speechRecognizer else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.recognizedText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()
                }
            }
        }

        isRecording = true
        lastSpeechTime = Date()
        startSilenceDetection()
    }

    func stop() {
        silenceTask?.cancel()
        silenceTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func startSilenceDetection() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRecording else { return }
                if Date().timeIntervalSince(self.lastSpeechTime) >= 5.0 {
                    self.stop()
                    return
                }
            }
        }
    }
}
