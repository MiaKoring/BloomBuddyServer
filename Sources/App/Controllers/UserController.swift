//
//  UserController.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//
import Vapor
import Fluent
import JWT

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")
        
        let authenticated = users.grouped(UserAuthenticator())
        
        users.post(use: create)
        authenticated.post("login", use: login)
        users.delete(use: delete)
        
        users.post("sensors", use: addSensor)
        users.get("sensors", use: sensors)
        users.get("sensors", ":id", use: sensor)
        users.get("sensors", "all", use: allSensorData)
        users.get("info", use: info)
    }
    
    @Sendable func create(req: Request) async throws -> JWT {
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
                let jwt = try await JWT.jwt(req: req, name: user.name, id: userID)
                return jwt
            } else {
                throw Abort(.internalServerError)
            }
        }
    }
    
    @Sendable func login(req: Request) async throws -> JWT {
        let user = try req.auth.require(User.self)
        
        guard let id = user.id?.uuidString else {
            throw Abort(.internalServerError, reason: "UserID empty")
        }
        
        return try await JWT.jwt(req: req, name: user.name, id: id)
    }
    
    @Sendable func addSensor(req: Request) async throws -> String {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        guard let id = UUID(uuidString: payload.subject.value), let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        
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
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value), let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        return user.sensors.map {
            $0.uuidString
        }.joined(separator: ",")
    }
    
    @Sendable func sensor(req: Request) async throws -> String {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value), let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        guard let idString = try? req.parameters.require("id"), let sensorID = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "invalid sensorID")
        }
        
        if !user.sensors.contains(sensorID) {
            throw Abort(.badRequest, reason: "No sensor with the given ID is linked to this account")
        }
        
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User doesn't have ID")
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
    
    @Sendable func delete(req: Request) async throws -> String {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value), let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        let sensors = try await Sensor.query(on: req.db)
            .filter(\.$owner == id)
            .all()
        
        try await req.db.transaction { db in
            try await user.delete(on: db)
            
            for sensor in sensors {
                try await sensor.delete(on: db)
            }
        }
        
        return "deleted:\(user.name)"
    }
    
    @Sendable func info(req: Request) async throws -> Response {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value) else {
            throw Abort(.internalServerError, reason: "User doesn't have ID")
        }
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$id == id)
            .first(), let jsonUser = try? JSONEncoder().encode(user) else {
            throw Abort(.internalServerError, reason: "user not found")
        }
        
        return Response(status: .ok, body: .init(data: jsonUser))
    }
    
    @Sendable func allSensorData(req: Request) async throws -> Response {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value) else {
            throw Abort(.internalServerError, reason: "User doesn't have ID")
        }
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$id == id)
            .first() else {
            throw Abort(.internalServerError, reason: "user not found")
        }
        
        let sensors = try await Sensor.query(on: req.db)
            .filter(\.$id ~~ user.sensors)
            .filter(\.$owner == id)
            .all()
        
        let jsonData = try JSONEncoder().encode(sensors)
        
        return Response(status: .ok, body: .init(data: jsonData))
    }
}
