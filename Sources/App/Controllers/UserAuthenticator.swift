//
//  UserAuthenticator.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 16.08.24.
//

import Vapor
import Fluent

struct UserAuthenticator: AsyncBasicAuthenticator {
    func authenticate(basic: Vapor.BasicAuthorization, for req: Vapor.Request) async throws {
        let res = try await User.query(on: req.db)
            .filter(\.$name == basic.username)
            .first()
        
        guard let user = res else {
            throw Abort(.unauthorized)
        }
        
        if try !user.verify(password: basic.password) {
            throw Abort(.unauthorized)
        }
        
        req.auth.login(user)
    }
}
