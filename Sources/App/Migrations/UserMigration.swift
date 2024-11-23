//
//  UserMigartion.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//

import Foundation
import Fluent

struct UserMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("name", .string, .required)
            .field("password", .string, .required)
            .field("sensorIDs", .array(of: .uuid), .required)
            .field("created", .double, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
