import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import APNS
import VaporAPNS
import APNSCore

let hexCharset = CharacterSet(charactersIn: "0123456789abcdef")

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
    app.migrations.add(DeviceMigration())
    
    //jwt
    guard let jwtKey = Environment.get("JWT_KEY")?.data(using: .utf8) else {
        throw Abort(.internalServerError, reason: "JWT_KEY empty")
    }
    await app.jwt.keys.add(hmac: .init(key: SymmetricKey(data: jwtKey)), digestAlgorithm: .sha256)
    
    //APNS
    let path = Environment.get("APNS_KEY_PATH") ?? "/Users/miakoring/Documents/Fork/BloomBuddyServer/Sources/App/key.p8"
    guard let key = try? String(contentsOfFile: path, encoding: .utf8) else {
        throw Abort(.internalServerError, reason: "apns key missing")
    }
    
    let apnsConfig = APNSClientConfiguration(authenticationMethod: .jwt(privateKey: try .loadFrom(string: key), keyIdentifier: "24DPU9JX9R", teamIdentifier: "68YWPYV749"), environment: .development)
    
    app.apns.containers.use(
        apnsConfig,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .default)
    
    
    // register routes
    try routes(app)
}

