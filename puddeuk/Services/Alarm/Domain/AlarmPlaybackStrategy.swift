import Foundation

protocol AlarmPlaybackStrategy {
    func activate(context: AlarmContext) async
    func deactivate() async
    var requiresChainNotifications: Bool { get }
}
