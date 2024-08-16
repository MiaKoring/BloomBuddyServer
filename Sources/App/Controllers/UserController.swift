//
//  UserController.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//
import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")
        
        let protected = users.grouped(UserAuthenticator())
        
        users.post(use: create)
        
        protected.post("sensors", use: addSensor)
        protected.get("sensors", use: sensors)
        protected.get("sensors", ":id", use: sensor)
    }
    
    @Sendable func create(req: Request) async throws -> String {
        let user = try req.content.decode(JSONUser.self)
        
        if try await User.exists(name: user.name, req: req) { throw Abort(.badRequest, reason: "User with that name already exists")}
        
        let pwHashed = try Bcrypt.hash(user.password)
        if try !Bcrypt.verify(user.password, created: pwHashed) {
            throw Abort(.custom(code: 500, reasonPhrase: "Error while hashing password"))
        }
        
        return try await req.db.transaction {db in
            try await User(name: user.name, password: pwHashed).create(on: db)
            
            let res = try await User.query(on: db)
                .filter(\.$name == user.name)
                .first()
            if let userID = res?.id?.uuidString {
                return userID
            } else {
                throw Abort(.internalServerError)
            }
        }
    }
    
    @Sendable func addSensor(req: Request) async throws -> String {
        let user = try req.auth.require(User.self)
        
        if user.sensors.count >= 5 {
            throw Abort(.badRequest, reason: "Can't have more than 5 sensors")
        }
        
        return try await req.db.transaction { db in
            guard let userID = user.id else {
                throw Abort(.internalServerError, reason: "User doesn't have ID") //shouldn't happen
            }
            
            let sensor = Sensor(owner: userID)
            try await sensor.save(on: db)
            
            guard let id = sensor.id else {
                throw Abort(.internalServerError, reason: "Sensor has no ID")
            }
            
            user.sensors.append(id)
            try await user.save(on: db)
            
            return id.uuidString
        }
    }
    
    @Sendable func sensors(req: Request) async throws -> String {
        let user = try req.auth.require(User.self)
        
        return user.sensors.map {
            $0.uuidString
        }.joined(separator: ",")
    }
    
    @Sendable func sensor(req: Request) async throws -> String {
        let user = try req.auth.require(User.self)
        
        guard let idString = try? req.parameters.require("id"), let sensorID = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "invalid sensorID")
        }
        
        if !user.sensors.contains(sensorID) {
            throw Abort(.badRequest, reason: "No sensor with the given ID is linked to this account")
        }
        
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User has no ID")
        }
        
        let sensor = try await Sensor.query(on: req.db)
            .filter(\.$id == sensorID)
            .filter(\.$owner == userID)
            .first()
        
        guard let value = sensor?.latest, let updated = sensor?.updated else {
            throw Abort(.noContent, reason: "No data available yet")
        }
        
        return "\(updated):\(value)"
    }
}
