import SwiftUI
import UIKit

struct RecordingControlsView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var audioFileName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recording.label")
                .font(.omyuHeadline)
                .foregroundColor(.white)

            if audioRecorder.isRecording {
                recordingView
            } else if audioFileName != nil {
                recordedView
            } else {
                noRecordingView
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            setupHapticCallbacks()
        }
        .onChange(of: audioRecorder.recordingState) { oldValue, newValue in
            if newValue == .limitReached && audioRecorder.audioURL != nil {
                audioFileName = audioRecorder.audioURL?.lastPathComponent
                AnalyticsManager.shared.logRecordingLimitReached()
                AnalyticsManager.shared.logRecordingCompleted(duration: audioRecorder.recordingTime)
            }
        }
    }

    private func setupHapticCallbacks() {
        audioRecorder.onWarningReached = {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
        audioRecorder.onLimitReached = {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RecordingProgressRing(
                    progress: audioRecorder.recordingTime / AlarmConfiguration.maxRecordingDuration,
                    isWarning: audioRecorder.recordingState == .warning
                )
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(audioRecorder.recordingState == .warning ? Color.orange : Color.teal)
                            .frame(width: 8, height: 8)
                        Text("recording.status.recording")
                            .font(.omyuCaption)
                            .foregroundColor(.gray)
                    }

                    Text(String(format: String(localized: "recording.time.remaining"), Int(audioRecorder.remainingTime)))
                        .font(.omyuBody)
                        .foregroundColor(audioRecorder.recordingState == .warning ? .orange : .white)
                }

                Spacer()
            }

            Button {
                let duration = audioRecorder.recordingTime
                audioRecorder.stopRecording()
                if let url = audioRecorder.audioURL {
                    audioFileName = url.lastPathComponent
                    AnalyticsManager.shared.logRecordingCompleted(duration: duration)
                }
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .font(.omyu(size: 24))
                    Text("recording.button.stop")
                        .font(.omyu(size: 16))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.teal.opacity(0.8))
                .cornerRadius(12)
            }
        }
    }

    private var recordedView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.teal)
                Text("recording.status.completed")
                    .font(.omyuBody)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    audioPlayer.stop()
                    if let fileName = audioFileName {
                        let deleted = audioRecorder.deleteAudioFile(fileName: fileName)
                        if deleted {
                            audioFileName = nil
                        }
                    }
                    AnalyticsManager.shared.logRecordingCanceled()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 12) {
                Button {
                    if audioPlayer.isPlaying {
                        audioPlayer.stop()
                    } else if let fileName = audioFileName {
                        _ = audioPlayer.playPreview(fileName: fileName)
                        AnalyticsManager.shared.logRecordingPlayed()
                    }
                } label: {
                    HStack {
                        Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            .font(.omyu(size: 16))
                        Text(audioPlayer.isPlaying ? "button.stop" : "recording.button.preview")
                            .font(.omyu(size: 14))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal.opacity(0.8))
                    .cornerRadius(12)
                }

                Button {
                    audioPlayer.stop()
                    if let fileName = audioFileName {
                        let deleted = audioRecorder.deleteAudioFile(fileName: fileName)
                        if deleted {
                            audioFileName = nil
                        }
                    }
                    _ = audioRecorder.startRecording()
                    AnalyticsManager.shared.logRecordingStarted()
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.omyu(size: 16))
                        Text("recording.button.reRecord")
                            .font(.omyu(size: 14))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var noRecordingView: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("recording.status.empty")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("recording.maxDuration.info")
                    .font(.omyuCaption)
                    .foregroundColor(.gray.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                _ = audioRecorder.startRecording()
                AnalyticsManager.shared.logRecordingStarted()
            } label: {
                HStack {
                    Image(systemName: "mic.circle.fill")
                        .font(.omyu(size: 24))
                    Text("recording.button.start")
                        .font(.omyu(size: 16))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.teal)
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    RecordingControlsView(
        audioRecorder: AudioRecorder(),
        audioPlayer: AudioPlayer(),
        audioFileName: .constant(nil)
    )
    .preferredColorScheme(.dark)
}
