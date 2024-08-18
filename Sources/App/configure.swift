import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    //app.http.server.configuration.port = 8081
    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "",
        password: Environment.get("DATABASE_PASSWORD") ?? "",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)
    
    //Migrations
    app.migrations.add(UserMigration())
    app.migrations.add(SensorMigration())
    
    //jwt
    guard let jwtKey = Environment.get("JWT_KEY")?.data(using: .utf8) else {
        throw Abort(.internalServerError, reason: "JWT_KEY empty")
    }
    await app.jwt.keys.add(hmac: .init(key: SymmetricKey(data: jwtKey)), digestAlgorithm: .sha256)
    
    // register routes
    try routes(app)
}

