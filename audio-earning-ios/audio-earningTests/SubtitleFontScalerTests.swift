import XCTest
@testable import audio_earning

final class SubtitleFontScalerTests: XCTestCase {
    func testCompactSizeMapping() {
        let size = SubtitleFontScaler.basePointSize(for: .medium, horizontalClass: .compact, contentSizeCategory: .large)
        XCTAssertEqual(size, 22)
    }

    func testRegularSizeMapping() {
        let size = SubtitleFontScaler.basePointSize(for: .large, horizontalClass: .regular, contentSizeCategory: .large)
        XCTAssertEqual(size, 36)
    }

    func testDynamicTypeScaling() {
        let base = SubtitleFontScaler.basePointSize(for: .small, horizontalClass: .regular, contentSizeCategory: .accessibilityExtraLarge)
        XCTAssertGreaterThan(base, 24)
    }
}
