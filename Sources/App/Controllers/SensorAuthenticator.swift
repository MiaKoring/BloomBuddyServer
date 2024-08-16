//
//  SensorAuthenticator.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 17.08.24.
//

import Vapor
import Fluent

struct SensorAuthenticator: AsyncBasicAuthenticator {
    func authenticate(basic: Vapor.BasicAuthorization, for req: Vapor.Request) async throws {
        
        guard let id = UUID(uuidString: basic.username), let owner = UUID(uuidString: basic.password) else {
            throw Abort(.unauthorized, reason: "couldn't convert credentials to UUIDs")
        }
        
        let res = try await Sensor.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$owner == owner)
            .first()
        
        guard let sensor = res else {
            throw Abort(.unauthorized)
        }
        
        req.auth.login(sensor)
    }
}
