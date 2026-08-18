import XCTest
import SwiftUI
@testable import Typikey

/// What the app is allowed to write into the shared container, and what it
/// must leave alone.
///
/// The keyboard reads a stored page as "she arranged these keys": it stops
/// moving words into the spare cells and stops relabelling verbs, because a
/// board somebody laid out by hand must not rearrange itself under them.
/// The editor, though, is handed the shipped home so there is something to
/// arrange — so the first save of anything at all wrote an untouched copy
/// of home alongside it, and the keyboard's home board froze.
///
/// This is a unit test rather than a UI one because the keyboard extension
/// has no Full Access on a test simulator and so never reads the container
/// there at all. Every keyboard-side test stayed green through the whole
/// regression for exactly that reason.
@MainActor
final class SavedPagesTests: XCTestCase {
    private var suite = ""
    private var store = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suite = "SavedPagesTests.\(UUID().uuidString)"
        store = UserDefaults(suiteName: suite) ?? .standard
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAddingAPageDoesNotStoreAnUntouchedHome() {
        PageStore(store: store).addPage()

        let stored = BoardLayout.loadPages(from: store)
        XCTAssertNil(stored.first { $0.id == "home" },
                     "an untouched home must not be written: the keyboard reads a stored home "
                     + "as arranged by hand and stops following the sentence")
        XCTAssertNotNil(stored.first { $0.name == "New Page" },
                        "the page she actually added must still be saved")
    }

    func testAnArrangedHomeIsStored() {
        let pages = PageStore(store: store)
        pages.goHome()
        pages.binding(at: 0).wrappedValue = BoardButton(id: "home.I", label: "Zoq")

        guard let home = BoardLayout.loadPages(from: store).first(where: { $0.id == "home" })
        else { return XCTFail("a home she arranged must reach the keyboard") }
        XCTAssertEqual(home.cells.first??.label, "Zoq")
        XCTAssertTrue(BoardLayout.isArranged(home),
                      "reshaping must stand down for keys she placed")
    }

    /// Relabelling a key leaves every key where the packer would have put
    /// it, so shape alone cannot see the edit — which is how the first cut
    /// of this fix silently threw the edit away.
    func testRelabellingAKeyIsNotMistakenForAnUntouchedBoard() {
        var page = shippedHome()
        page.cells[0] = BoardButton(id: "home.I", label: "Zoq")
        page.arranged = false

        XCTAssertTrue(BoardLayout.isArranged(page),
                      "a key named after a word it no longer says was relabelled by hand")
    }

    /// The home word list has changed twice since the editor shipped, so a
    /// board saved by an older build does not match today's shipped one.
    /// It is still nobody's arrangement, and a device carrying one has to
    /// get its sentence-following board back when it updates.
    func testAHomeSavedByAnOlderBuildStillReadsAsUntouched() {
        let older = KeyboardPage(
            id: "home", name: "Keyboard Home Pg 1",
            words: BoardPlan.homeSelection.dropLast().map {
                BoardButton(id: "home.\($0)", label: $0)
            })
        XCTAssertNotEqual(older, BoardLayout.builtInPages.first { $0.id == "home" },
                          "setup: this should differ from what ships today")
        XCTAssertFalse(BoardLayout.isArranged(older),
                       "a board an older build generated is still a generated board")
    }

    func testAGapAKeyboardWouldNeverLeaveReadsAsArranged() {
        var page = shippedHome()
        page.cells[1] = nil
        XCTAssertTrue(BoardLayout.isArranged(page),
                      "the packer never leaves a hole mid-board — somebody emptied that cell")
    }

    /// Renaming is an edit worth keeping, but it is not laying out a
    /// board — the words may still move.
    func testRenamingAPageIsKeptButDoesNotStandDownReshaping() {
        var page = shippedHome()
        page.name = "Sayfullah's board"
        XCTAssertTrue(BoardLayout.isEdited(page), "a rename must survive being saved")
        XCTAssertFalse(BoardLayout.isArranged(page), "a rename does not place any key")
    }

    private func shippedHome() -> KeyboardPage {
        BoardLayout.builtInPages.first { $0.id == "home" }!
    }

    /// The predicate both halves turn on. A shipped board that read as
    /// customised would freeze the keyboard just as surely.
    func testShippedPagesReadAsUntouched() {
        for page in BoardLayout.builtInPages {
            XCTAssertFalse(BoardLayout.isArranged(page),
                           "the shipped '\(page.id)' must not read as arranged by hand")
            XCTAssertFalse(BoardLayout.isEdited(page),
                           "the shipped '\(page.id)' must not read as edited")
        }
    }
}
