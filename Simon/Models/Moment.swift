//
//  Moment.swift
//  Simon
//
//  Created on 2026-02-02.
//

import Foundation
import SwiftData

@Model
final class Moment {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var order: Int
    var text: String
    var templateId: String?
    
    // We treat attached files as separate entities or just store metadata here if needed.
    // For now, simple storage of the moment text and metadata.
    
    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        order: Int = 0,
        text: String,
        templateId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.order = order
        self.text = text
        self.templateId = templateId
    }
}
