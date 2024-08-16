//
//  Sensor.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//

import Foundation
import Vapor
import Fluent

final class Sensor: Model, Authenticatable {
    static let schema: String = "sensors"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "latest")
    var latest: Double?
    
    @Field(key: "updated")
    var updated: Int?
    
    @Field(key: "owner")
    var owner: UUID
    
    init() { }
    
    init(id: UUID? = nil, latest: Double? = nil, updated: Int? = nil, owner: UUID) {
        self.id = id
        self.latest = latest
        self.updated = updated
        self.owner = owner
    }
}
