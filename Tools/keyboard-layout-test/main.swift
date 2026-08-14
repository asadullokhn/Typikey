import CoreGraphics
import Foundation

let grantedHeight: CGFloat = 479
let suggestionBarHeight: CGFloat = 56
let availableHeight = grantedHeight - suggestionBarHeight
let rowHeight = KeyboardFit.fittedRowHeight(
    preferred: 127,
    availableHeight: availableHeight,
    rows: 4,
    gap: 8,
    outerInset: 12)
let gridBottom = suggestionBarHeight + 12 + rowHeight * 4 + 8 * 3 + 12

precondition(abs(rowHeight - 93.75) < 0.001,
             "a 479pt grant must reduce four rows to 93.75pt")
precondition(gridBottom <= grantedHeight + 0.001,
             "the fourth row must remain inside the granted keyboard height")

let roomyRowHeight = KeyboardFit.fittedRowHeight(
    preferred: 127,
    availableHeight: 584,
    rows: 4,
    gap: 8,
    outerInset: 12)
precondition(roomyRowHeight == 127,
             "the reference row size must remain unchanged when it fits")

let landscapeRequest = KeyboardFit.requestedHeight(
    preset: 640,
    measuredDeficit: 135,
    screenHeight: 1024,
    isPhone: false)
precondition(landscapeRequest == 768,
             "iPad compensation must be allowed to request 75% of landscape height")

let phoneRequest = KeyboardFit.requestedHeight(
    preset: 640,
    measuredDeficit: 135,
    screenHeight: 1024,
    isPhone: true)
precondition(abs(phoneRequest - 614.4) < 0.001,
             "the existing 60% phone cap must remain unchanged")
