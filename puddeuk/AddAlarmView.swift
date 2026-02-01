//
//  AddAlarmView.swift
//  puddeuk
//
//  Created by 성현 on 2/1/26.
//

import SwiftUI
import SwiftData
import AVFoundation

struct AddAlarmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var title: String = "알람"
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var isAM: Bool = true
    @State private var repeatDays: Set<Int> = []
    @State private var audioFileName: String?
    @State private var showingDeleteAlert = false
    
    let alarm: Alarm?
    let isEditing: Bool
    
    init(alarm: Alarm? = nil) {
        self.alarm = alarm
        self.isEditing = alarm != nil
        
        if let alarm = alarm {
            _title = State(initialValue: alarm.title)
            _selectedHour = State(initialValue: alarm.hour == 0 ? 12 : (alarm.hour > 12 ? alarm.hour - 12 : alarm.hour))
            _selectedMinute = State(initialValue: alarm.minute)
            _isAM = State(initialValue: alarm.hour < 12)
            _repeatDays = State(initialValue: Set(alarm.repeatDays))
            _audioFileName = State(initialValue: alarm.audioFileName)
        }
    }
    
    private let dayNames = ["일", "월", "화", "수", "목", "금", "토"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 시간 선택
                        VStack(spacing: 16) {
                            Text("시간 설정")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                // 오전/오후 선택
                                Picker("오전/오후", selection: $isAM) {
                                    Text("오전").tag(true)
                                    Text("오후").tag(false)
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70, height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 40)
                                        .offset(y: 0)
                                )
                                
                                // 시 선택
                                Picker("시", selection: $selectedHour) {
                                    ForEach(1...12, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70, height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 40)
                                        .offset(y: 0)
                                )
                                
                                Text(":")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.top, 20)
                                
                                // 분 선택
                                Picker("분", selection: $selectedMinute) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text(String(format: "%02d", minute)).tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70, height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 40)
                                        .offset(y: 0)
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        
                        // 제목 입력
                        VStack(alignment: .leading, spacing: 8) {
                            Text("제목")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("알람 이름", text: $title)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        
                        // 반복 요일 선택
                        VStack(alignment: .leading, spacing: 12) {
                            Text("반복 요일")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<7) { dayIndex in
                                    Button {
                                        if repeatDays.contains(dayIndex) {
                                            repeatDays.remove(dayIndex)
                                        } else {
                                            repeatDays.insert(dayIndex)
                                        }
                                    } label: {
                                        Text(dayNames[dayIndex])
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(repeatDays.contains(dayIndex) ? .black : .white)
                                            .frame(width: 44, height: 44)
                                            .background(repeatDays.contains(dayIndex) ? Color.pink : Color.gray.opacity(0.3))
                                            .cornerRadius(22)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        
                        // 음성 녹음
                        VStack(alignment: .leading, spacing: 12) {
                            Text("알람 소리")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 16) {
                                if audioRecorder.isRecording {
                                    HStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 12, height: 12)
                                            .opacity(audioRecorder.isRecording ? 1 : 0)
                                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                                        
                                        Text("녹음 중... \(Int(audioRecorder.recordingTime))초")
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                } else if audioFileName != nil {
                                    HStack {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.pink)
                                        
                                        Text("녹음 완료")
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Button {
                                            audioFileName = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                } else {
                                    Text("녹음된 소리가 없습니다")
                                        .foregroundColor(.gray)
                                }
                                
                                Button {
                                    if audioRecorder.isRecording {
                                        audioRecorder.stopRecording()
                                        if let url = audioRecorder.audioURL {
                                            let fileName = "\(UUID().uuidString).m4a"
                                            audioFileName = audioRecorder.copyAudioFile(from: url, to: fileName)
                                        }
                                    } else {
                                        _ = audioRecorder.startRecording()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 24))
                                        
                                        Text(audioRecorder.isRecording ? "녹음 중지" : "녹음 시작")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(audioRecorder.isRecording ? Color.red.opacity(0.8) : Color.pink.opacity(0.8))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        
                        // 삭제 버튼 (편집 모드일 때만)
                        if isEditing {
                            Button {
                                showingDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("알람 삭제")
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "알람 편집" : "새 알람")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveAlarm()
                    }
                    .foregroundColor(.pink)
                    .fontWeight(.semibold)
                }
            }
            .alert("알람 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteAlarm()
                }
            } message: {
                Text("이 알람을 삭제하시겠습니까?")
            }
        }
    }
    
    private func saveAlarm() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            if let url = audioRecorder.audioURL {
                let fileName = "\(UUID().uuidString).m4a"
                audioFileName = audioRecorder.copyAudioFile(from: url, to: fileName)
            }
        }
        
        // 12시간 형식을 24시간 형식으로 변환
        let hour24: Int
        if isAM {
            hour24 = selectedHour == 12 ? 0 : selectedHour
        } else {
            hour24 = selectedHour == 12 ? 12 : selectedHour + 12
        }
        
        if let existingAlarm = alarm {
            // 기존 알람 취소
            AlarmNotificationManager.shared.cancelAlarm(existingAlarm)
            
            // 편집 모드
            existingAlarm.title = title
            existingAlarm.hour = hour24
            existingAlarm.minute = selectedMinute
            existingAlarm.repeatDays = Array(repeatDays)
            if let fileName = audioFileName {
                existingAlarm.audioFileName = fileName
            }
            
            // 알람 재스케줄링
            AlarmNotificationManager.shared.scheduleAlarm(existingAlarm)
        } else {
            // 새 알람 생성
            let newAlarm = Alarm(
                title: title,
                hour: hour24,
                minute: selectedMinute,
                isEnabled: true,
                audioFileName: audioFileName,
                repeatDays: Array(repeatDays)
            )
            modelContext.insert(newAlarm)
            
            // 알람 스케줄링
            AlarmNotificationManager.shared.scheduleAlarm(newAlarm)
        }
        
        dismiss()
    }
    
    private func deleteAlarm() {
        if let alarm = alarm {
            AlarmNotificationManager.shared.cancelAlarm(alarm)
            modelContext.delete(alarm)
        }
        dismiss()
    }
}

#Preview {
    AddAlarmView()
        .modelContainer(for: Alarm.self, inMemory: true)
}

