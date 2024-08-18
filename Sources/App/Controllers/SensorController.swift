//
//  SensorController.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 17.08.24.
//

import Vapor
import Fluent
import Foundation

struct SensorController: RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        let sensors = routes.grouped("sensors")
        let protected = sensors.grouped(SensorAuthenticator())
        
        sensors.patch(use: updateData)
        protected.post(use: authenticate)
    }
    
    @Sendable func authenticate(req: Request) async throws -> JWT {
        let sensor = try req.auth.require(Sensor.self)
        
        guard let id = sensor.id?.uuidString else {
            throw Abort(.internalServerError, reason: "Sensor id empty")
        }
        
        return try await JWT.jwt(req: req, name: sensor.owner.uuidString, id: id)
    }
    
    @Sendable func updateData(req: Request) async throws -> String {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value), let owner = UUID(uuidString: payload.name) else {
            throw Abort(.internalServerError, reason: "Could't convert Sensor ID || owner to uuid")
        }
        
        guard let sensor = try await Sensor.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$owner == owner)
            .first() else {
            throw Abort(.notFound)
        }
        
        guard let body = req.body.string, let double = Double(body) else {
            throw Abort(.badRequest, reason: "Invalid Value: Not conform to Double")
        }
        
        let updated = Int(Date().timeIntervalSinceReferenceDate)
        
        try await req.db.transaction { db in
            sensor.updated = updated
            sensor.latest = double
            try await sensor.save(on: db)
        }
        
        return "\(updated):\(double)"
    }
}
