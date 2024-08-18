//
//  File.swift
//  
//
//  Created by Mia Koring on 18.08.24.
//

import Foundation
import Vapor

struct JWT: Codable, AsyncResponseEncodable {
    let token: String
    let expires: Date
    
    func encodeResponse(for req: Vapor.Request) async throws -> Vapor.Response {
        let data = try JSONEncoder().encode(self)
        return Response(status: .ok, version: req.version, headers: .init([("Content-Type", "application/json")]), body: .init(data: data))
    }
}

extension JWT {
    public static func jwt(req: Request, name: String, id: String) async throws -> JWT {
        let expires = Date.distantFuture
        let payload = JWTUserPayload(name: name, subject: .init(value: id), expiration: .init(value: expires))
        
        let token = try await req.jwt.sign(payload, kid: "a")
        
        return JWT(token: token, expires: expires)
    }
}
