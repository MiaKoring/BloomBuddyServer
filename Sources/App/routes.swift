import Fluent
import Vapor

func routes(_ app: Application) throws {    
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    app.get(".well-known", "apple-app-site-association") { req async -> String in
        """
            {
              "applinks": {
                "apps": [],
                "details": [
                  {
                    "appID": "68YWPYV749.de.touchthegrass.BloomBuddy",
                    "paths": [
                      "/faq/images/*"
                    ]
                  }
                ]
              }
            }
        """
    }
    
    try app.register(collection: UserController())
    try app.register(collection: SensorController())
    
}
