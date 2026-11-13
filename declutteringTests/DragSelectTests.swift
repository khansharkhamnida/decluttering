import Testing
import UIKit
@testable import decluttering

@MainActor
struct DragSelectTests {

    private func path(_ section: Int, _ item: Int) -> IndexPath { IndexPath(item: item, section: section) }

    @Test func sameItemReturnsOnlyThatItem() {
        let result = DragSelectController.indexPaths(from: path(0, 2), to: path(0, 2), itemCounts: [5])
        #expect(result == [path(0, 2)])
    }

    @Test func forwardWithinSection() {
        let result = DragSelectController.indexPaths(from: path(0, 1), to: path(0, 3), itemCounts: [5])
        #expect(result == [path(0, 1), path(0, 2), path(0, 3)])
    }

    @Test func backwardRunsInReverse() {
        let result = DragSelectController.indexPaths(from: path(0, 3), to: path(0, 1), itemCounts: [5])
        #expect(result == [path(0, 3), path(0, 2), path(0, 1)])
    }

    @Test func acrossSections() {
        let result = DragSelectController.indexPaths(from: path(0, 1), to: path(1, 1), itemCounts: [3, 4])
        #expect(result == [path(0, 1), path(0, 2), path(1, 0), path(1, 1)])
    }

    @Test func skipsEmptySections() {
        let result = DragSelectController.indexPaths(from: path(0, 1), to: path(3, 0), itemCounts: [2, 0, 0, 2])
        #expect(result == [path(0, 1), path(3, 0)])
    }

    @Test func invalidPathsReturnNothing() {
        #expect(DragSelectController.indexPaths(from: path(1, 0), to: path(0, 0), itemCounts: [2, 0]).isEmpty)
        #expect(DragSelectController.indexPaths(from: path(0, 0), to: path(0, 5), itemCounts: [2]).isEmpty)
    }
}
