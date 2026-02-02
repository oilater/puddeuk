import SwiftUI

extension Font {
    /// 오뮤 다예쁨 폰트
    static func omyu(size: CGFloat) -> Font {
        return .custom("omyu_pretty", size: size)
    }

    // 미리 정의된 크기들
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

// 앱 전체에 기본 폰트 적용
extension View {
    func applyDefaultFont() -> some View {
        self.font(.omyu(size: 17))
    }
}

// SwiftUI Text의 기본 스타일을 오뮤 폰트로 설정
extension Text {
    init(omyu text: String) {
        self.init(text)
        self = self.font(.omyu(size: 17))
    }
}
