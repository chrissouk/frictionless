import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.064)
    static let surface = Color(red: 0.11, green: 0.13, blue: 0.125)
    static let banana = Color(red: 1.00, green: 0.85, blue: 0.25)
    static let text = Color(red: 0.95, green: 0.94, blue: 0.90)
    // Keep this order aligned with FruitPalette.names and persisted task indices.
    static let colors: [Color] = [
        banana,
        Color(red: 0.42, green: 0.57, blue: 0.92), // Blueberry
        Color(red: 1.00, green: 0.68, blue: 0.53), // Peach
        Color(red: 0.72, green: 0.48, blue: 0.86), // Grape
        Color(red: 0.69, green: 0.82, blue: 0.32), // Pear
        Color(red: 0.94, green: 0.36, blue: 0.39), // Apple
        Color(red: 1.00, green: 0.59, blue: 0.22) // Orange
    ]
    static func color(_ index: Int) -> Color { colors[abs(index % colors.count)] }
}
