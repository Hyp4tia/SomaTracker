//
//  AudioPlaybackService.swift
//  SomaTracker
//
//  Manages voice note playback, progress tracking, and remaining time calculation.
//

import Foundation
import AVFoundation
import Observation

@Observable
final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0.0

    private var player: AVAudioPlayer?
    private var displayLinkTimer: Timer?
    private var currentURL: URL?

    /// Formatted time display matching the mockup: e.g. "-0:28"
    var timeRemainingString: String {
        guard duration > 0 else { return "0:00" }
        let remaining = max(0, duration - currentTime)
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        return String(format: "-%d:%02d", mins, secs)
    }

    func loadAudio(url: URL) {
        guard currentURL != url else { return }
        stop()
        self.currentURL = url

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
            progress = 0
        } catch {
            player = nil
        }
    }

    func loadAudio(relativePath: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(relativePath)
        loadAudio(url: fileURL)
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopTimer()
        currentTime = 0
        progress = 0
    }

    func seek(to percentage: Double) {
        guard let player = player else { return }
        let clamped = max(0.0, min(1.0, percentage))
        let targetTime = clamped * duration
        player.currentTime = targetTime
        currentTime = targetTime
        progress = clamped
    }

    private func startTimer() {
        displayLinkTimer?.invalidate()
        displayLinkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player, self.isPlaying else { return }
            self.currentTime = player.currentTime
            if self.duration > 0 {
                self.progress = min(1.0, player.currentTime / self.duration)
            }
        }
    }

    private func stopTimer() {
        displayLinkTimer?.invalidate()
        displayLinkTimer = nil
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
        progress = 0
    }
}
