//
//  User.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//

import Foundation
import Fluent
import Vapor

final class User: Model {
    static let schema: String = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "password")
    var password: String
    
    @Field(key: "sensorIDs")
    var sensors: [UUID]
    
    @Field(key: "created")
    var created: Double
    
    init() { }
    
    init(id: UUID? = nil, name: String, password: String, sensors: [UUID] = []) {
        self.id = id
        self.name = name
        self.password = password
        self.sensors = sensors
        self.created = Date().timeIntervalSinceReferenceDate
    }
    
    static func exists(name: String, req: Request) async throws -> Bool {
        try await User.query(on: req.db)
            .filter(\.$name == name)
            .first() != nil
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$name
    static let passwordHashKey = \User.$password
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
    
}
