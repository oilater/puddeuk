import SwiftUI
import MessageUI

struct FeedbackView: View {
    @State private var rating = 0
    @State private var fromEmail = ""
    @State private var feedback = ""
    @State private var showingMailView = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 헤더
                    VStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)

                        Text("사용후기 남기기")
                            .font(.omyuTitle3)
                            .foregroundStyle(.white)

                        Text("퍼뜩이 마음에 드셨나요?")
                            .font(.omyuSubheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 40)

                    // 평점
                    VStack(alignment: .leading, spacing: 12) {
                        Text("평점")
                            .font(.omyuSubheadline)
                            .foregroundStyle(.gray)

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    rating = star
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundStyle(star <= rating ? .yellow : .gray)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)

                    // 폼
                    VStack(spacing: 16) {
                        // 이메일
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이메일")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextField("답변받을 이메일 주소", text: $fromEmail)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        // 후기
                        VStack(alignment: .leading, spacing: 8) {
                            Text("후기")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextEditor(text: $feedback)
                                .frame(height: 200)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(Color(red: 0.18, green: 0.18, blue: 0.2))
                                .cornerRadius(12)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 20)

                    // 전송 버튼
                    Button {
                        sendFeedback()
                    } label: {
                        Text("전송")
                            .font(.omyuHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isFormValid ? Color.blue : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("사용후기")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMailView) {
            MailComposeView(
                toEmail: "squareknot@icloud.com",
                subject: "퍼뜩 사용후기 ⭐️\(String(repeating: "⭐️", count: rating))",
                fromEmail: fromEmail,
                message: feedback
            ) { result in
                handleMailResult(result)
            }
        }
        .alert("알림", isPresented: $showingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var isFormValid: Bool {
        rating > 0 &&
        !fromEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(fromEmail)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showingMailView = true
        } else {
            alertMessage = "이 기기에서 메일을 보낼 수 없습니다.\n메일 앱을 설정해주세요."
            showingAlert = true
        }
    }

    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case .success(let mailResult):
            switch mailResult {
            case .sent:
                alertMessage = "소중한 후기 감사합니다! 💙"
                clearForm()
            case .saved:
                alertMessage = "메일이 임시 보관함에 저장되었습니다."
            case .cancelled:
                break
            case .failed:
                alertMessage = "메일 전송에 실패했습니다."
            @unknown default:
                break
            }

            if mailResult != .cancelled {
                showingAlert = true
            }

        case .failure:
            alertMessage = "메일 전송 중 오류가 발생했습니다."
            showingAlert = true
        }
    }

    private func clearForm() {
        rating = 0
        fromEmail = ""
        feedback = ""
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
