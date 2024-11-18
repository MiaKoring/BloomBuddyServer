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
    
    @Field(key: "model")
    var model: SensorModel
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "latest")
    var latest: Double?
    
    @Field(key: "battery")
    var battery: Int?
    
    @Field(key: "updated")
    var updated: Int?
    
    @Field(key: "owner")
    var owner: UUID
    
    init() { }
    
    init(id: UUID? = nil, model: Int? = nil, name: String, latest: Double? = nil, battery: Int? = nil, updated: Int? = nil, owner: UUID) {
        self.id = id
        self.model = SensorModel(rawValue: model ?? 0) ?? .diy
        self.name = name
        self.latest = latest
        self.battery = battery
        self.updated = updated
        self.owner = owner
    }
}
