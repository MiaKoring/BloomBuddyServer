//
//  Device.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 18.11.24.
//

import Foundation
import Fluent
import Vapor

final class Device: Model, Content {
    static let schema: String = "devices"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "isIOS")
    var isIOS: Bool
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "owner")
    var owner: UUID
    
    init() {}
    
    init(id: UUID? = nil, isIOS: Bool, token: String, owner: UUID) {
        self.id = id
        self.isIOS = isIOS
        self.token = token
        self.owner = owner
    }
}

