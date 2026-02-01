//
//  AudioPlayer.swift
//  puddeuk
//
//  Created by 성현 on 2/1/26.
//

import Foundation
import AVFoundation
import AudioToolbox
import Combine

class AudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?
    
    func playAlarmSound(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try setupAudioSession()
            player = try AVAudioPlayer(contentsOf: audioURL)
            configurePlayer()
            player?.play()
            print("✅ 알람 소리 재생 시작: \(fileName)")
        } catch {
            print("❌ 알람 소리 재생 실패: \(error)")
            playDefaultSound()
        }
    }
    
    func playDefaultSound() {
        if let soundURL = Bundle.main.url(forResource: "default_alarm", withExtension: "mp3") {
            do {
                try setupAudioSession()
                player = try AVAudioPlayer(contentsOf: soundURL)
                configurePlayer()
                player?.play()
            } catch {
                print("❌ 기본 소리 재생 실패: \(error)")
                playSystemSound()
            }
        } else {
            playSystemSound()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        deactivateAudioSession()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func configurePlayer() {
        player?.numberOfLoops = -1 // 무한 반복
        player?.volume = 1.0
    }
    
    private func playSystemSound() {
        AudioServicesPlaySystemSound(1005) // 시스템 알람 사운드 ID
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("오디오 세션 비활성화 실패: \(error)")
        }
    }
}

