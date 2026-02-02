import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let toEmail: String
    let subject: String
    let fromEmail: String
    let message: String
    let completion: (Result<MFMailComposeResult, Error>) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator

        mailComposer.setToRecipients([toEmail])
        mailComposer.setSubject(subject)

        let fullMessage = """
        \(message)

        ---
        보내는 사람: \(fromEmail)
        """

        mailComposer.setMessageBody(fullMessage, isHTML: false)

        return mailComposer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // 업데이트 필요 없음
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let completion: (Result<MFMailComposeResult, Error>) -> Void

        init(completion: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            self.completion = completion
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                if let error = error {
                    self.completion(.failure(error))
                } else {
                    self.completion(.success(result))
                }
            }
        }
    }
}
