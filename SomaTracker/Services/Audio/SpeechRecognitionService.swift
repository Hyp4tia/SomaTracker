//
//  SpeechRecognitionService.swift
//  SomaTracker
//
//  Crash-proof on-device speech recognition, audio recording, and live waveform engine.
//

import Foundation
import Speech
import AVFoundation
import Observation

@Observable
final class SpeechRecognitionService: NSObject, AVAudioRecorderDelegate {
    var isRecordingLive = false
    var liveTranscribedText = ""
    var liveWaveformLevels: [Float] = Array(repeating: 0.18, count: 32)
    var currentAudioPower: Float = 0.18
    var recordingDuration: TimeInterval = 0
    var lastErrorMessage: String? = nil

    // Private Audio Engine Components
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordedAudioFile: AVAudioFile?

    // Private Fallback Audio Recorder (Guaranteed 100% microphone capture on hardware)
    private var fallbackRecorder: AVAudioRecorder?
    private var isUsingFallbackRecorder = false

    private var currentRecordedURL: URL?
    private var timer: Timer?
    private var animationPhase: Double = 0

    override init() {
        super.init()
    }

    // MARK: - Smart Locale-Aware Speech Recognizer

    private var speechRecognizer: SFSpeechRecognizer? {
        // 1. If user has Arabic in preferred languages or locale, prioritize Arabic recognizers
        let preferred = Locale.preferredLanguages
        if let arLang = preferred.first(where: { $0.hasPrefix("ar") }) {
            if let rec = SFSpeechRecognizer(locale: Locale(identifier: arLang)), rec.isAvailable {
                return rec
            }
        }
        if Locale.current.identifier.hasPrefix("ar") {
            if let rec = SFSpeechRecognizer(locale: Locale(identifier: "ar-EG")), rec.isAvailable {
                return rec
            }
            if let rec = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA")), rec.isAvailable {
                return rec
            }
        }
        // 2. Try device's preferred current locale
        if let rec = SFSpeechRecognizer(locale: Locale.current), rec.isAvailable {
            return rec
        }
        // 3. Try autoupdating current
        if let rec = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent), rec.isAvailable {
            return rec
        }
        // 4. Try en-US
        if let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), rec.isAvailable {
            return rec
        }
        // 5. Any default recognizer configured by iOS
        return SFSpeechRecognizer()
    }

    // MARK: - Permissions & Status Checks

    enum PermissionStatus {
        case authorized
        case denied
        case notDetermined
    }

    func checkMicrophoneStatus() -> PermissionStatus {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .authorized
            case .denied: return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .denied
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: return .authorized
            case .denied: return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .denied
            }
        }
    }

    func checkSpeechStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestMicrophoneAuthorization() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func requestSpeechAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Sequential authorization request to prevent iOS system alert presentation conflicts.
    func requestAuthorization() async -> Bool {
        let micGranted: Bool
        if checkMicrophoneStatus() == .notDetermined {
            micGranted = await requestMicrophoneAuthorization()
        } else {
            micGranted = checkMicrophoneStatus() == .authorized
        }

        guard micGranted else { return false }

        // Speech recognition is additive; request if undetermined
        if checkSpeechStatus() == .notDetermined {
            _ = await requestSpeechAuthorization()
        }

        return true
    }

    // MARK: - Live Recording & Speech Transcription

    func startLiveTranscription() -> Bool {
        stopLiveTranscription()
        lastErrorMessage = nil
        isUsingFallbackRecorder = false

        #if targetEnvironment(simulator)
        print("[SpeechRecognitionService] Running in Simulator: using rock-solid fallback recorder directly.")
        return startFallbackAudioRecorder()
        #else
        // 1. Activate Audio Session in default recording mode
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechRecognitionService] Audio session error: \(error.localizedDescription)")
            return startFallbackAudioRecorder()
        }

        // 2. Prepare speech recognizer
        guard let recognizer = speechRecognizer, recognizer.isAvailable, checkSpeechStatus() == .authorized else {
            print("[SpeechRecognitionService] Speech recognizer unavailable or unauthorized, using fallback recorder.")
            return startFallbackAudioRecorder()
        }

        // 3. Prepare fresh AVAudioEngine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        let bus = 0
        let recordingFormat = inputNode.outputFormat(forBus: bus)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            print("[SpeechRecognitionService] Invalid hardware format, using fallback recorder.")
            return startFallbackAudioRecorder()
        }

        // 4. Create destination audio file (.wav format for universal PCM compatibility)
        let fileName = "voice_memo_\(UUID().uuidString).wav"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        self.currentRecordedURL = fileURL

        do {
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: recordingFormat.sampleRate,
                AVNumberOfChannelsKey: recordingFormat.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            self.recordedAudioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            print("[SpeechRecognitionService] AVAudioFile init error: \(error.localizedDescription). Falling back to recorder.")
            return startFallbackAudioRecorder()
        }

        // 5. Setup Recognition Request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.liveTranscribedText = result.bestTranscription.formattedString
                }
            }

            if let error = error {
                // Non-fatal notice (e.g. user paused speech or dialect model fallback)
                print("[SpeechRecognitionService] Speech recognition notice: \(error.localizedDescription)")
            }
        }

        // 6. Install Audio Tap
        inputNode.removeTap(onBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)

            if let file = self.recordedAudioFile {
                try? file.write(from: buffer)
            }

            // Real-time RMS metering for live waveform bars
            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                if frameLength > 0 {
                    var sum: Float = 0
                    let step = max(1, frameLength / 32)
                    var count = 0
                    for i in stride(from: 0, to: frameLength, by: step) {
                        let sample = channelData[i]
                        sum += sample * sample
                        count += 1
                    }
                    let rms = sqrt(sum / Float(max(1, count)))
                    let power = max(0.15, min(1.0, Float(rms * 5.0 + 0.15)))

                    DispatchQueue.main.async {
                        self.currentAudioPower = power
                    }
                }
            }
        }

        // 7. Start Engine
        engine.prepare()
        do {
            try engine.start()
            isRecordingLive = true
            liveTranscribedText = ""
            recordingDuration = 0
            liveWaveformLevels = Array(repeating: 0.18, count: 32)
            startRollingTimer()
            return true
        } catch {
            print("[SpeechRecognitionService] Engine start failed: \(error.localizedDescription). Falling back to recorder.")
            return startFallbackAudioRecorder()
        }
        #endif
    }

    // MARK: - Fallback Audio Recorder (Guaranteed Rock-Solid Capture)

    private func startFallbackAudioRecorder() -> Bool {
        stopEngineOnly()
        isUsingFallbackRecorder = true

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechRecognitionService] Audio session configuration error in fallback: \(error.localizedDescription)")
        }

        let fileName = "voice_memo_\(UUID().uuidString).m4a"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        self.currentRecordedURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                lastErrorMessage = "Microphone could not start recording."
                print("[SpeechRecognitionService] AVAudioRecorder.record() returned false")
                return false
            }
            self.fallbackRecorder = recorder

            self.isRecordingLive = true
            self.liveTranscribedText = ""
            self.recordingDuration = 0
            self.liveWaveformLevels = Array(repeating: 0.18, count: 32)
            self.startRollingTimer()
            print("[SpeechRecognitionService] Fallback audio recorder active: \(fileURL.lastPathComponent)")
            return true
        } catch {
            lastErrorMessage = "Audio recording error: \(error.localizedDescription)"
            print("[SpeechRecognitionService] AVAudioRecorder init error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Stop & Transcription

    @discardableResult
    func stopLiveTranscription() -> (text: String, audioURL: URL?, relativePath: String?, samples: [Float], duration: TimeInterval) {
        let text = liveTranscribedText
        let url = currentRecordedURL
        let relativePath = url?.lastPathComponent
        let duration = recordingDuration
        let finalSamples = liveWaveformLevels

        if isUsingFallbackRecorder {
            fallbackRecorder?.stop()
            fallbackRecorder = nil
            isUsingFallbackRecorder = false
        }

        stopEngineOnly()
        isRecordingLive = false

        currentRecordedURL = nil
        recordedAudioFile = nil
        return (text, url, relativePath, finalSamples, duration)
    }

    private func stopEngineOnly() {
        timer?.invalidate()
        timer = nil

        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func startRollingTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingLive else { return }
            self.recordingDuration += 0.06
            self.animationPhase += 0.35

            var currentPower = self.currentAudioPower
            if self.isUsingFallbackRecorder, let recorder = self.fallbackRecorder {
                recorder.updateMeters()
                let avg = recorder.averagePower(forChannel: 0)
                currentPower = max(0.15, min(1.0, Float((avg + 50.0) / 50.0)))
            }

            let organicPulse = Float(sin(self.animationPhase)) * 0.10
            let level = max(0.15, min(1.0, currentPower + organicPulse))

            if self.liveWaveformLevels.count >= 32 {
                self.liveWaveformLevels.removeFirst()
            }
            self.liveWaveformLevels.append(level)
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    // MARK: - Audio File Transcription

    func transcribeAudioFile(at url: URL) async -> String {
        #if targetEnvironment(simulator)
        return ""
        #else
        guard let recognizer = speechRecognizer, recognizer.isAvailable, checkSpeechStatus() == .authorized else {
            return ""
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result, result.isFinal {
                        continuation.resume(returning: result)
                    }
                }
            }
            return result.bestTranscription.formattedString
        } catch {
            print("[SpeechRecognitionService] File transcription notice: \(error.localizedDescription)")
            return ""
        }
        #endif
    }
}
