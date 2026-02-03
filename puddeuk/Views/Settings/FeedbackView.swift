import SwiftUI

struct FeedbackView: View {
    @State private var rating = 0
    @State private var fromEmail = ""
    @State private var feedback = ""
    @State private var isLoading = false
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
                            .font(.omyu(size: 50))
                            .foregroundStyle(.teal)

                        Text("사용 후기 남기기")
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
                                        .font(.omyu(size: 32))
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

                            TextField("답변 받을 이메일 주소", text: $fromEmail)
                                .font(.omyuBody)
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

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $feedback)
                                    .frame(height: 200)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .background(Color(red: 0.18, green: 0.18, blue: 0.2))
                                    .cornerRadius(12)
                                    .foregroundStyle(.white)

                                if feedback.isEmpty {
                                    Text("솔직한 후기를 남겨주세요")
                                        .font(.omyuBody)
                                        .foregroundStyle(.gray.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // 전송 버튼
                    Button {
                        sendFeedback()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "전송 중..." : "전송")
                                .font(.omyuHeadline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isFormValid && !isLoading ? Color.teal : Color.gray.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("사용 후기")
        .navigationBarTitleDisplayMode(.inline)
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
        isLoading = true

        Task {
            do {
                let stars = String(repeating: "⭐️", count: rating)
                let subject = "퍼뜩 사용 후기 \(stars)"

                guard let url = URL(string: "https://formspree.io/f/xqelwgva") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "email": fromEmail,
                    "subject": subject,
                    "message": """
                    평점: \(rating)/5

                    작성자 이메일: \(fromEmail)

                    후기:
                    \(feedback)
                    """
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if httpResponse.statusCode == 200 {
                    await MainActor.run {
                        isLoading = false
                        alertMessage = "소중한 후기 감사합니다! 💙"
                        showingAlert = true
                        clearForm()
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        alertMessage = "전송에 실패했습니다.\n잠시 후 다시 시도해주세요."
                        showingAlert = true
                    }
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "전송에 실패했습니다.\n네트워크 연결을 확인해주세요."
                    showingAlert = true
                }
            }
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
