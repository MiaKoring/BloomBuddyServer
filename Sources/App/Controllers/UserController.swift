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
        users.get("info", use: info)
        users.delete(use: delete)
        
        users.post("sensors", use: addSensor)
        users.get("sensors", use: sensors)
        users.get("sensors", ":id", use: sensor)
        users.get("sensors", "all", use: allSensorData)
        users.patch("sensors", ":id", use: changeSensorName)
        
        users.patch("sensorModel", ":id", use: updateSensorModel)
        
        users.post("device", use: registerDevice)
        users.get("device", use: devices)
        users.delete("device", ":id", use: removeDevice)
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
        let id = try await checkJWT(req: req)
        guard let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        
        if user.sensors.count >= 5 {
            throw Abort(.badRequest, reason: "Can't have more than 5 sensors")
        }
        
        let jsonSensor = try req.content.decode(JSONSensor.self)
        
        return try await req.db.transaction { db in
            guard let userID = user.id else {
                throw Abort(.internalServerError, reason: "User doesn't have ID") //shouldn't happen
            }
            
            let existingSensor = try await Sensor.query(on: db)
                .filter(\.$name == jsonSensor.name)
                .filter(\.$owner == userID)
                .first()
            
            if existingSensor != nil {
                throw Abort(.badRequest, reason: "Sensor with that name already exists")
            }
            
            let sensor = Sensor(model: jsonSensor.model, name: jsonSensor.name, owner: userID)
            try await sensor.save(on: db)
            
            guard let id = sensor.id else {
                throw Abort(.internalServerError, reason: "Sensor has no ID")
            }
            
            user.sensors.append(id)
            try await user.save(on: db)
            
            return id.uuidString
        }
    }
    
    @Sendable func changeSensorName(req: Request) async throws -> String {
        let id = try await checkJWT(req: req)
        
        guard let idStr = try? req.parameters.require("id"), let uuid = UUID(uuidString: idStr) else {
            throw Abort(.badRequest, reason: "Path id is either empty or not convertible to UUID")
        }
        
        let sensors = try await Sensor.query(on: req.db)
            .filter(\.$owner == id)
            .all()
        
        guard let sensor = sensors.first(where: {$0.id == uuid}) else {
            throw Abort(.badRequest, reason: "User has no sensor with the given ID")
        }
        
        guard let name = try? req.content.decode(Name.self).name, !name.isEmpty else {
            throw Abort(.badRequest, reason: "Body must contain a valid String for Name")
        }
        
        guard !sensors.contains(where: {$0.name == name}) else {
            throw Abort(.badRequest, reason: "Sensor with that name already exists")
        }
        
        sensor.name = name
        
        try await sensor.save(on: req.db)
        
        return name
        
        struct Name: Codable{
            let name: String
        }
    }
    
    @Sendable func updateSensorModel(req: Request) async throws -> Int {
        let id = try await checkJWT(req: req)
        
        guard let idStr = try? req.parameters.require("id"), let uuid = UUID(uuidString: idStr) else {
            throw Abort(.badRequest, reason: "Path id is either empty or not convertible to UUID")
        }
        
        let sensors = try await Sensor.query(on: req.db)
            .filter(\.$owner == id)
            .all()
        
        guard let sensor = sensors.first(where: {$0.id == uuid}) else {
            throw Abort(.badRequest, reason: "User has no sensor with the given ID")
        }
        
        guard let model = try? req.content.decode(Model.self).model else {
            throw Abort(.badRequest, reason: "Given model doesn't exist or is empty")
        }
        
        sensor.model = model
        sensor.battery = nil
        
        try await sensor.save(on: req.db)
        
        return model.rawValue
        
        struct Model: Codable {
            let model: SensorModel
        }
    }
    
    @Sendable func sensors(req: Request) async throws -> Response {
        let id = try await checkJWT(req: req)
        
        guard let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        let sensors = try await Sensor.query(on: req.db)
            .filter(\.$owner == id)
            .filter(\.$id ~~ user.sensors)
            .all()
        
        let response: [[String: String?]] = sensors.map { sensor in
            var dict: [String: String?] = [:]
            dict["id"] = sensor.id?.uuidString
            dict["name"] = sensor.name
            return dict
        }
        
        let data = try JSONEncoder().encode(response)
        return Response(status: .ok, body: .init(data: data))
    }
    
    @Sendable func sensor(req: Request) async throws -> String {
        let id = try await checkJWT(req: req)
        
        guard let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
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
    
    @Sendable func registerDevice(req: Request) async throws -> String {
        let id = try await checkJWT(req: req)
        
        guard let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        guard let token = try? req.content.decode(DeviceToken.self).dt, token.count == 64, token.rangeOfCharacter(from: hexCharset.inverted) == nil else {
            throw Abort(.badRequest, reason: "invalid format for token")
        }
        guard try await Device.query(on: req.db).filter(\.$token == token).filter(\.$owner == id).count() == 0 else {
            throw Abort(.badRequest, reason: "device already exists")
        }
        let device = Device(isIOS: true, token: token, owner: id)
        try await device.save(on: req.db)
        
        try await NotificationController.sendNotification(req, toDevice: token, title: "Push-Benachrichtugungen", subtitle: "Registrierung für Push-Benachrichtigungen abgeschlossen")
        
        return token
        
        struct DeviceToken: Codable {
            let dt: String
        }
    }
    
    @Sendable func devices(req: Request) async throws -> [Device] {
        let id = try await checkJWT(req: req)
        
        return try await Device.query(on: req.db).filter(\.$owner == id).all()
    }
    
    @Sendable func removeDevice(req: Request) async throws -> String {
        let id = try await checkJWT(req: req)
        
        guard let deviceIDStr = try? req.parameters.require("id"), let deviceID = UUID(uuidString: deviceIDStr) else {
            throw Abort(.badRequest, reason: "Id is empty or not conform to UUID")
        }
        
        guard let device = try await Device.query(on: req.db).filter(\.$id == deviceID).filter(\.$owner == id).first() else {
            throw Abort(.badRequest, reason: "device doesn't exist")
        }
        
        try await device.delete(on: req.db)
        
        return "\(device.id?.uuidString ?? "Device") deleted"
    }
    
    @Sendable func delete(req: Request) async throws -> String {
        let id = try await checkJWT(req: req)
        
        guard let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
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
    
    @Sendable func deleteSensor(req: Request) async throws -> String {
        let id = try await checkJWT(req: req)
        
        guard let user = try await User.query(on: req.db).filter(\.$id == id).first() else {
            throw Abort(.internalServerError, reason: "fetching user failed")
        }
        
        guard let sensorIdStr = try? req.parameters.require("id"), let sensorID = UUID(uuidString: sensorIdStr) else {
            throw Abort(.badRequest, reason: "Requires parameter id to match UUID")
        }
        
        guard let sensor = try await Sensor.query(on: req.db).filter(\.$id == sensorID).filter(\.$owner == id).first() else {
            throw Abort(.badRequest, reason: "Sensor doesn't exist")
        }
        
        try await req.db.transaction { db in
            try await sensor.delete(on: db)
        }
        
        return "deleted:\(sensorIdStr)"
    }
    
    @Sendable func info(req: Request) async throws -> Response {
        let id = try await checkJWT(req: req)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$id == id)
            .first(), let jsonUser = try? JSONEncoder().encode(user) else {
            throw Abort(.internalServerError, reason: "user not found")
        }
        
        return Response(status: .ok, body: .init(data: jsonUser))
    }
    
    @Sendable func allSensorData(req: Request) async throws -> Response {
        let id = try await checkJWT(req: req)
        
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
    
    private func checkJWT(req: Request) async throws -> UUID {
        let payload = try await req.jwt.verify(as: JWTUserPayload.self)
        
        guard let id = UUID(uuidString: payload.subject.value) else {
            throw Abort(.internalServerError, reason: "User doesn't have ID")
        }
        
        return id
    }
}
