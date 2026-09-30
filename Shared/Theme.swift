import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.064)
    static let surface = Color(red: 0.11, green: 0.13, blue: 0.125)
    static let mint = Color(red: 0.64, green: 0.9, blue: 0.77)
    static let text = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let colors: [Color] = [mint, Color(red: 0.69, green: 0.74, blue: 0.85), Color(red: 0.84, green: 0.73, blue: 0.62), Color(red: 0.76, green: 0.67, blue: 0.79), Color(red: 0.73, green: 0.80, blue: 0.63), Color(red: 0.80, green: 0.66, blue: 0.67)]
    static func color(_ index: Int) -> Color { colors[abs(index % colors.count)] }
}
