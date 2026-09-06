//
//  AudioRecordingService.swift
//  SomaTracker
//
//  Manages voice recording with real-time audio meter waveform capture.
//

import Foundation
import AVFoundation
import Observation

@Observable
final class AudioRecordingService: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var elapsedTime: TimeInterval = 0
    var waveformSamples: [Float] = []

    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentRecordingURL: URL?

    override init() {
        super.init()
    }

    func requestPermission() async -> Bool {
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

    func startRecording() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            return false
        }

        let fileName = "voice_note_\(UUID().uuidString).m4a"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        self.currentRecordingURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            elapsedTime = 0
            waveformSamples = []

            startMetering()
            return true
        } catch {
            return false
        }
    }

    func stopRecording() -> (url: URL, relativePath: String, samples: [Float], duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        stopMetering()
        let duration = recorder.currentTime
        recorder.stop()
        isRecording = false

        guard let url = currentRecordingURL else { return nil }
        let relativePath = url.lastPathComponent

        // Normalize waveform samples to exactly ~35-45 bars for sleek visual rendering
        let finalSamples = downsample(waveformSamples, targetCount: 36)

        return (url, relativePath, finalSamples, duration)
    }

    func cancelRecording() {
        stopMetering()
        audioRecorder?.stop()
        isRecording = false
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
        waveformSamples = []
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder, self.isRecording else { return }
            recorder.updateMeters()
            self.elapsedTime = recorder.currentTime

            let power = recorder.averagePower(forChannel: 0)
            // Power ranges from -160 to 0 dB. Convert to normalized 0.15 ... 1.0
            let normalized = max(0.15, min(1.0, Float((power + 50.0) / 50.0)))
            self.waveformSamples.append(normalized)
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func downsample(_ samples: [Float], targetCount: Int) -> [Float] {
        guard !samples.isEmpty else {
            // Provide aesthetic varied default bars if too few samples
            return (0..<targetCount).map { i in
                0.25 + 0.65 * abs(sin(Float(i) * 0.45))
            }
        }
        if samples.count <= targetCount {
            var padded = samples
            while padded.count < targetCount {
                padded.append(padded.last ?? 0.3)
            }
            return padded
        }

        var result: [Float] = []
        let chunkSize = Double(samples.count) / Double(targetCount)
        for i in 0..<targetCount {
            let start = Int(Double(i) * chunkSize)
            let end = min(samples.count, Int(Double(i + 1) * chunkSize))
            let slice = samples[start..<max(start + 1, end)]
            let avg = slice.reduce(0, +) / Float(slice.count)
            result.append(avg)
        }
        return result
    }
}
