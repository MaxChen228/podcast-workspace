import Foundation
import Testing
@testable import audio_earning

struct ChapterNameParserTests {
    @Test func chapterIndexParsesStandardChapterString() {
        #expect(ChapterNameParser.chapterIndex(in: "chapter108") == 108)
        #expect(ChapterNameParser.chapterIndex(in: "Chapter 42") == 42)
    }

    @Test func chapterIndexIgnoresNonChapterTitles() {
        #expect(ChapterNameParser.chapterIndex(in: "Episode 3") == nil)
        #expect(ChapterNameParser.chapterIndex(in: "chapter-05-extra") == nil)
    }

    @Test func displayTitleFallsBackGracefully() {
        #expect(ChapterNameParser.displayTitle(id: "chapter12", title: "") == "Chapter 12")
        #expect(ChapterNameParser.displayTitle(id: "ep1", title: "Prologue") == "Prologue")
    }
}
