import Foundation
import SwiftUI

struct Folder: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let icon: String
    let sortOrder: Int
    let createdAt: Date

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    init(
        id: String,
        name: String,
        colorHex: String = "#6b7280",
        icon: String = "folder",
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
