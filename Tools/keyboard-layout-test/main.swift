import CoreGraphics
import Foundation

// The device in front of us: a 13-inch iPad in Display Zoom, landscape.
let screenW: CGFloat = 1032
let screenH: CGFloat = 774
let safeBottom: CGFloat = 5
let columns = 10

let cell = KeyboardFit.cellWidth(boardWidth: screenW, columns: columns)
let target = KeyboardFit.targetHeight(
    boardWidth: screenW, columns: columns,
    screenHeight: screenH, safeAreaBottom: safeBottom)
let bottom = KeyboardFit.bottomInset(safeAreaBottom: safeBottom)
let row = KeyboardFit.fittedRowHeight(
    preferred: cell * KeyboardFit.maxRowAspect,
    availableHeight: target - KeyboardFit.barHeight,
    rows: KeyboardFit.rows,
    gap: KeyboardFit.gap,
    verticalInset: KeyboardFit.outerInset + bottom)

// Square keys are the design. The cell width is fixed by the column count,
// so this is also what decides the board's height.
precondition(abs(row - cell) < 0.001,
             "a word cell must be exactly as tall as it is wide")

// The board asks for precisely what those rows need, so the grid fills it:
// no dead margin above the first row or below the last beyond the insets.
let occupied = KeyboardFit.barHeight + KeyboardFit.outerInset
    + row * CGFloat(KeyboardFit.rows)
    + KeyboardFit.gap * CGFloat(KeyboardFit.rows - 1) + bottom
precondition(abs(occupied - target) < 0.001,
             "the target height must be exactly what the board occupies")

// The bottom margin is the home-indicator strip, not the 12pt the sides
// use — the board sits on the screen edge rather than floating above it.
precondition(bottom < KeyboardFit.outerInset,
             "the bottom margin must be tighter than the side margin")

// The screen fraction is a backstop, not the thing normally in force.
precondition(target < screenH * KeyboardFit.targetFraction,
             "square cells must land under the screen ceiling, not on it")

// A grant smaller than asked for shrinks the rows rather than pushing the
// fourth one past the bottom edge.
let squeezed = KeyboardFit.fittedRowHeight(
    preferred: cell,
    availableHeight: 300 - KeyboardFit.barHeight,
    rows: KeyboardFit.rows,
    gap: KeyboardFit.gap,
    verticalInset: KeyboardFit.outerInset + bottom)
let squeezedBottom = KeyboardFit.barHeight + KeyboardFit.outerInset
    + squeezed * 4 + KeyboardFit.gap * 3 + bottom
precondition(squeezed < cell, "a short grant must shrink the rows")
precondition(squeezedBottom <= 300.001,
             "the fourth row must remain inside the granted height")

// Portrait: narrower cells, so a shorter board. Still square, still exact.
let portraitCell = KeyboardFit.cellWidth(boardWidth: screenH, columns: columns)
let portraitTarget = KeyboardFit.targetHeight(
    boardWidth: screenH, columns: columns,
    screenHeight: screenW, safeAreaBottom: safeBottom)
precondition(portraitCell < cell && portraitTarget < target,
             "a narrower board must be a shorter one")
