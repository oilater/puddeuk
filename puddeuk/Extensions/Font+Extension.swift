import SwiftUI

extension Font {
    static func omyu(size: CGFloat) -> Font {
        return .custom("omyu_pretty", size: size)
    }

    static let omyuLargeTitle = omyu(size: 34)
    static let omyuTitle = omyu(size: 28)
    static let omyuTitle2 = omyu(size: 22)
    static let omyuTitle3 = omyu(size: 20)
    static let omyuHeadline = omyu(size: 17)
    static let omyuBody = omyu(size: 17)
    static let omyuCallout = omyu(size: 16)
    static let omyuSubheadline = omyu(size: 15)
    static let omyuFootnote = omyu(size: 13)
    static let omyuCaption = omyu(size: 12)
}

extension View {
    func applyDefaultFont() -> some View {
        self.font(.omyu(size: 17))
    }
}

extension Text {
    init(omyu text: String) {
        self.init(text)
        self = self.font(.omyu(size: 17))
    }
}
