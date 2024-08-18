//
//  File.swift
//  
//
//  Created by Mia Koring on 18.08.24.
//

import Foundation
import Vapor
import JWT

struct JWTUserPayload: JWTPayload {
    let name: String
    let subject: SubjectClaim
    let expiration: ExpirationClaim
    
    func verify(using algorithm: some JWTKit.JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}
