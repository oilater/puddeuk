import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var audioFileName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("알람 소리")
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
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)

                Text("녹음 중... \(Int(audioRecorder.recordingTime))초")
                    .foregroundColor(.white)

                Spacer()
            }

            Button {
                audioRecorder.stopRecording()
                if let url = audioRecorder.audioURL {
                    audioFileName = url.lastPathComponent
                }
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                    Text("녹음 중지")
                        .font(.omyu(size: 16))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
            }
        }
    }

    private var recordedView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.pink)
                Text("녹음 완료")
                    .foregroundColor(.white)
                Spacer()
                Button {
                    audioPlayer.stop()
                    if let fileName = audioFileName,
                       audioRecorder.audioURL?.lastPathComponent == fileName {
                        audioRecorder.deleteAudioFile(fileName: fileName)
                    }
                    audioFileName = nil
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
                    }
                } label: {
                    HStack {
                        Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16))
                        Text(audioPlayer.isPlaying ? "정지" : "미리듣기")
                            .font(.omyu(size: 14))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink.opacity(0.8))
                    .cornerRadius(12)
                }

                Button {
                    audioPlayer.stop()
                    if let fileName = audioFileName {
                        audioRecorder.deleteAudioFile(fileName: fileName)
                    }
                    audioFileName = nil
                    _ = audioRecorder.startRecording()
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                        Text("다시 녹음")
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
            Text("녹음된 소리가 없습니다")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                _ = audioRecorder.startRecording()
            } label: {
                HStack {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 24))
                    Text("녹음 시작")
                        .font(.omyu(size: 16))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink.opacity(0.8))
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
