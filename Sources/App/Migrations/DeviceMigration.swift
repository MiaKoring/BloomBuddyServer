//
//  DeviceMigration.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 18.11.24.
//
import Foundation
import Fluent

struct DeviceMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("devices")
            .id()
            .field("isIOS", .bool, .required)
            .field("token", .string, .required)
            .field("owner", .uuid, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
