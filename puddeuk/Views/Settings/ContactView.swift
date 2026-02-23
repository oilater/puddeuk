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
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.omyu(size: 50))
                            .foregroundStyle(.teal)

                        Text("contact.title")
                            .font(.omyuTitle3)
                            .foregroundStyle(.white)

                        Text("contact.subtitle")
                            .font(.omyuSubheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("contact.subject.label")
                                .font(.omyuSubheadline)
                                .foregroundStyle(.gray)

                            TextField("contact.subject.placeholder", text: $subject)
                                .font(.omyuBody)
                                .textFieldStyle(CustomTextFieldStyle())
                        }

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

                    Button {
                        sendMail()
                    } label: {
                        Text("button.send")
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
        .navigationTitle("contact.navigation.title")
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
        .alert("alert.title", isPresented: $showingAlert) {
            Button("button.ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fromEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        fromEmail.isValidEmail
    }

    private func sendMail() {
        if MFMailComposeViewController.canSendMail() {
            showingMailView = true
        } else {
            alertMessage = String(localized: "contact.error.mailUnavailable")
            showingAlert = true
        }
    }

    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case .success(let mailResult):
            switch mailResult {
            case .sent:
                alertMessage = String(localized: "contact.success.sent")
                clearForm()
            case .saved:
                alertMessage = String(localized: "contact.success.saved")
            case .cancelled:
                break
            case .failed:
                alertMessage = String(localized: "contact.error.failed")
            @unknown default:
                break
            }

            if mailResult != .cancelled {
                showingAlert = true
            }

        case .failure:
            alertMessage = String(localized: "contact.error.failure")
            showingAlert = true
        }
    }

    private func clearForm() {
        subject = ""
        fromEmail = ""
        message = ""
    }
}

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
