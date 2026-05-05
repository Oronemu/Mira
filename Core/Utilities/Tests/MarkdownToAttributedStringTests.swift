import Foundation
import Testing
import CoreKit
@testable import Utilities

@Suite("MarkdownToAttributedString")
struct MarkdownToAttributedStringTests {

    // MARK: - Plain

    @Test("Plain text round-trips with no domain attributes")
    func plainPassesThrough() {
        let result = MarkdownToAttributedString.parse("hello world")
        #expect(String(result.characters) == "hello world")
        for run in result.runs {
            #expect(run[EntryBoldAttribute.self] == nil)
            #expect(run[EntryItalicAttribute.self] == nil)
            #expect(run[EntryFontSizeAttribute.self] == nil)
        }
    }

    // MARK: - Inline emphasis

    @Test("`**bold**` becomes a bold run, markers stripped")
    func boldStarStar() {
        let result = MarkdownToAttributedString.parse("hello **bold** world")
        #expect(String(result.characters) == "hello bold world")
        let bolded = boldRanges(in: result)
        #expect(bolded == ["bold"])
    }

    @Test("`__bold__` becomes a bold run too")
    func boldUnderscoreUnderscore() {
        let result = MarkdownToAttributedString.parse("__strong__ word")
        #expect(String(result.characters) == "strong word")
        #expect(boldRanges(in: result) == ["strong"])
    }

    @Test("`*italic*` and `_italic_` become italic runs")
    func italicSingle() {
        let starred = MarkdownToAttributedString.parse("*soft* echo")
        #expect(String(starred.characters) == "soft echo")
        #expect(italicRanges(in: starred) == ["soft"])

        let underscored = MarkdownToAttributedString.parse("a _b_ c")
        #expect(String(underscored.characters) == "a b c")
        #expect(italicRanges(in: underscored) == ["b"])
    }

    @Test("Mid-word `_` is preserved (snake_case stays plain)")
    func midWordUnderscoreLeftAlone() {
        let result = MarkdownToAttributedString.parse("snake_case is fine")
        #expect(String(result.characters) == "snake_case is fine")
        for run in result.runs {
            #expect(run[EntryItalicAttribute.self] == nil)
        }
    }

    @Test("Bold and italic can nest")
    func nestedBoldItalic() {
        let result = MarkdownToAttributedString.parse("**bold *and italic***")
        #expect(String(result.characters) == "bold and italic")
        // "bold " has bold, "and italic" has bold+italic.
        let bolded = boldRanges(in: result)
        #expect(bolded.joined() == "bold and italic")
        let italicised = italicRanges(in: result)
        #expect(italicised == ["and italic"])
    }

    // MARK: - Headings

    @Test("`# H1` maps to extraLarge + bold")
    func headingOne() {
        let result = MarkdownToAttributedString.parse("# Title")
        #expect(String(result.characters) == "Title")
        let runs = Array(result.runs)
        #expect(runs.count == 1)
        #expect(runs[0][EntryFontSizeAttribute.self] == .extraLarge)
        #expect(runs[0][EntryBoldAttribute.self] == true)
    }

    @Test("`## H2` maps to large + bold")
    func headingTwo() {
        let result = MarkdownToAttributedString.parse("## Subhead")
        let runs = Array(result.runs)
        #expect(runs[0][EntryFontSizeAttribute.self] == .large)
        #expect(runs[0][EntryBoldAttribute.self] == true)
    }

    @Test("`### H3` maps to regular + bold")
    func headingThree() {
        let result = MarkdownToAttributedString.parse("### Detail")
        let runs = Array(result.runs)
        #expect(runs[0][EntryFontSizeAttribute.self] == .regular)
        #expect(runs[0][EntryBoldAttribute.self] == true)
    }

    @Test("`####+` levels are not promoted to headings")
    func deepHashesPassThrough() {
        let result = MarkdownToAttributedString.parse("#### Too deep")
        #expect(String(result.characters) == "#### Too deep")
        for run in result.runs {
            #expect(run[EntryFontSizeAttribute.self] == nil)
        }
    }

    @Test("`#` without a trailing space is not a heading")
    func hashWithoutSpace() {
        let result = MarkdownToAttributedString.parse("#tag is plain")
        #expect(String(result.characters) == "#tag is plain")
        for run in result.runs {
            #expect(run[EntryFontSizeAttribute.self] == nil)
        }
    }

    // MARK: - List markers preserved

    @Test("`- ` and `1. ` markers stay in plain text for the renderer")
    func listMarkersPreserved() {
        let result = MarkdownToAttributedString.parse(
            """
            - first
            - second
            1. one
            2. two
            """
        )
        #expect(String(result.characters) == "- first\n- second\n1. one\n2. two")
    }

    // MARK: - Multi-line + heading combo

    @Test("Heading + paragraph + bold inline preserves line structure")
    func mixedDocument() {
        let source = """
        # Hello

        Today felt **bright** and _calm_.
        """
        let result = MarkdownToAttributedString.parse(source)
        #expect(String(result.characters) == "Hello\n\nToday felt bright and calm.")
        // First line is heading-styled.
        let firstRun = result.runs.first!
        #expect(firstRun[EntryFontSizeAttribute.self] == .extraLarge)
        #expect(firstRun[EntryBoldAttribute.self] == true)
        // "bright" is bold, "calm" is italic.
        #expect(boldRanges(in: result).contains("bright"))
        #expect(italicRanges(in: result).contains("calm"))
    }

    // MARK: - Helpers

    private func boldRanges(in attr: AttributedString) -> [String] {
        attr.runs.compactMap { run in
            guard run[EntryBoldAttribute.self] == true else { return nil }
            return String(attr[run.range].characters)
        }
    }

    private func italicRanges(in attr: AttributedString) -> [String] {
        attr.runs.compactMap { run in
            guard run[EntryItalicAttribute.self] == true else { return nil }
            return String(attr[run.range].characters)
        }
    }
}
