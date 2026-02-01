//
//  AlarmView.swift
//  puddeuk
//
//  Created by 성현 on 2/1/26.
//

import SwiftUI

struct AlarmView: View {
    let alarm: Alarm
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var vibrationManager = VibrationManager()
    @State private var isDismissed = false
    
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                    .scaleEffect(isDismissed ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: !isDismissed)
                
                Text(alarm.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text(alarm.timeString)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    stopAlarm()
                } label: {
                    Text("끄기")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.pink)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startAlarm()
        }
        .onDisappear {
            stopAlarm()
        }
    }
    
    // MARK: - Private Methods
    
    private func startAlarm() {
        if let audioFileName = alarm.audioFileName {
            audioPlayer.playAlarmSound(fileName: audioFileName)
        } else {
            audioPlayer.playDefaultSound()
        }
        vibrationManager.start()
    }
    
    private func stopAlarm() {
        isDismissed = true
        audioPlayer.stop()
        vibrationManager.stop()
        AlarmManager.shared.dismissAlarm()
    }
}

