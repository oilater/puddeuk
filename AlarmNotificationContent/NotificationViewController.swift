import UIKit
import SwiftUI
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private var hostingController: UIHostingController<AlarmNotificationView>?
    private var alarmTitle: String = "일어나자"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)

        // 적절한 크기 설정
        let width = view.bounds.width
        let height = width * 1.5  // 높이 = 너비 * 1.5
        preferredContentSize = CGSize(width: width, height: height)

        let contentView = AlarmNotificationView(
            title: alarmTitle,
            onSnooze: { [weak self] in
                self?.handleSnooze()
            },
            onDismiss: { [weak self] in
                self?.handleDismiss()
            }
        )

        hostingController = UIHostingController(rootView: contentView)
        hostingController?.view.backgroundColor = .clear

        if let hostingView = hostingController?.view {
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            addChild(hostingController!)
            view.addSubview(hostingView)

            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])

            hostingController?.didMove(toParent: self)
        }
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        alarmTitle = content.userInfo["title"] as? String ?? content.title

        hostingController?.rootView = AlarmNotificationView(
            title: alarmTitle,
            onSnooze: { [weak self] in
                self?.handleSnooze()
            },
            onDismiss: { [weak self] in
                self?.handleDismiss()
            }
        )
    }

    private func handleSnooze() {
        extensionContext?.performNotificationDefaultAction()
    }

    private func handleDismiss() {
        extensionContext?.dismissNotificationContentExtension()
    }
}

struct AlarmNotificationView: View {
    let title: String
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 60))
                .foregroundColor(.teal)
                .rotationEffect(.degrees(isAnimating ? -10 : 10))
                .animation(
                    Animation.easeInOut(duration: 0.15)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
                .padding(.top, 20)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Button(action: onSnooze) {
                    Text("5분 후")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(12)
                }

                Button(action: onDismiss) {
                    Text("끄기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.teal)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
    }
}
