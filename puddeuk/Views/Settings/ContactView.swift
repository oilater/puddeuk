import SwiftUI
import MessageUI

struct ContactView: View {
    @State private var subject = ""
    @State private var fromEmail = ""
    @State private var message = ""
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
                        Image(systemName: "envelope.fill")
                            .font(.omyu(size: 50))
                            .foregroundStyle(.teal)

                        Text("개발자에게 문의하기")
                            .font(.omyuTitle3)
                            .foregroundStyle(.white)

                        Text("의견이나 문의사항을 보내주세요")
                            .font(.omyuSubheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 40)

                    // 폼
                    VStack(spacing: 16) {
                        // 제목
                        VStack(alignment: .leading, spacing: 8) {
                            Text("제목")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextField("제목을 입력해주세요", text: $subject)
                                .font(.omyuBody)
                                .textFieldStyle(CustomTextFieldStyle())
                        }

                        // 이메일
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이메일")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextField("답변받을 이메일 주소", text: $fromEmail)
                                .font(.omyuBody)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        // 내용
                        VStack(alignment: .leading, spacing: 8) {
                            Text("내용")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextEditor(text: $message)
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
                        sendMail()
                    } label: {
                        Text("전송")
                            .font(.omyuHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isFormValid ? Color.teal : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("문의하기")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMailView) {
            MailComposeView(
                toEmail: "squareknot@icloud.com",
                subject: subject,
                fromEmail: fromEmail,
                message: message
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
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fromEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(fromEmail)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func sendMail() {
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
                alertMessage = "메일이 성공적으로 전송되었습니다."
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
        subject = ""
        fromEmail = ""
        message = ""
    }
}

// 커스텀 텍스트필드 스타일
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(red: 0.18, green: 0.18, blue: 0.2))
            .cornerRadius(12)
            .foregroundStyle(.white)
    }
}

#Preview {
    NavigationStack {
        ContactView()
    }
}
