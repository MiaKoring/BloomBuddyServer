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
            throw Abort(.notFound, reason: "no sensor with matching id found")
        }
        
        guard let body = req.body.string else {
            throw Abort(.badRequest, reason: "Invalid Value: Body is empty")
        }
        let numbers = body.split(separator: " ").map({Double("\($0)")})
        
        guard !numbers.contains(nil) || !numbers.isEmpty else {
            throw Abort(.badRequest, reason: "Invalid Value: Not convertible to double")
        }
        
        let updated = Int(Date().timeIntervalSinceReferenceDate)
        
        try await req.db.transaction { db in
            sensor.updated = updated
            sensor.latest = numbers[0]
            if numbers.count > 1, let num = numbers[1] {
                sensor.battery = Int(num)
            } else {
                sensor.battery = nil
            }
            try await sensor.save(on: db)
        }
        
        try? await NotificationController.sendBackgroundNotification(req, to: owner, data: SensorData(id: id, name: sensor.name, sensor: numbers[0], battery: sensor.battery, model: sensor.model))
        
        return "\(updated):\(numbers[0] ?? 0)"
    }
}
