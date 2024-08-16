//
//  SensorController.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 17.08.24.
//

import Vapor
import Fluent
import SwiftChameleon
import Foundation

struct SensorController: RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        let protected = routes.grouped("sensors")
            .grouped(SensorAuthenticator())
        
        protected.patch(use: updateData)
    }
    
    @Sendable func updateData(req: Request) async throws -> String {
        let sensor = try req.auth.require(Sensor.self)
        
        let body = req.body.string
        
        guard let double = body?.toDouble else {
            throw Abort(.badRequest, reason: "Invalid Value: Not conform to Double")
        }
        
        let updated = Date().timeIntervalSinceReferenceDate.int
        
        try await req.db.transaction { db in
            sensor.updated = updated
            sensor.latest = double
            try await sensor.save(on: db)
        }
        
        return "\(updated):\(double)"
    }
}
