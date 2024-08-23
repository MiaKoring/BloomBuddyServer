//
//  SensorMigration.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//

import Foundation
import Fluent

struct SensorMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sensors")
            .id()
            .field("name", .string, .required)
            .field("latest", .double)
            .field("updated", .int)
            .field("owner", .uuid, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sensors").delete()
    }
}
