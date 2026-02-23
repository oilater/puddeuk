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
                    VStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.omyu(size: 50))
                            .foregroundStyle(.teal)

                        Text("feedback.navigation.title")
                            .font(.omyuTitle3)
                            .foregroundStyle(.white)

                        Text("feedback.subtitle")
                            .font(.omyuSubheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("feedback.rating.label")
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

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("feedback.email.label")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextField("feedback.email.placeholder", text: $fromEmail)
                                .font(.omyuBody)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("feedback.content.label")
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
                                    Text("feedback.message.placeholder")
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

                    Button {
                        sendFeedback()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "feedback.button.sending" : "button.send")
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
        .navigationTitle("feedback.navigation.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("alert.title", isPresented: $showingAlert) {
            Button("button.ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var isFormValid: Bool {
        rating > 0 &&
        !fromEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        fromEmail.isValidEmail
    }

    private func sendFeedback() {
        isLoading = true

        Task {
            do {
                let stars = String(repeating: "⭐️", count: rating)
                let subject = String(format: String(localized: "feedback.email.subject"), stars)

                guard let url = URL(string: "https://formspree.io/f/xqelwgva") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let ratingLabel = String(localized: "feedback.rating.label")
                let emailLabel = String(localized: "feedback.email.label")
                let contentLabel = String(localized: "feedback.content.label")

                let body: [String: Any] = [
                    "email": fromEmail,
                    "subject": subject,
                    "message": """
                    \(ratingLabel): \(rating)/5

                    \(emailLabel): \(fromEmail)

                    \(contentLabel):
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
                        alertMessage = String(localized: "feedback.success.message")
                        showingAlert = true
                        clearForm()
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        alertMessage = String(localized: "feedback.error.failed")
                        showingAlert = true
                    }
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = String(localized: "feedback.error.network")
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
