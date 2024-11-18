//
//  NotificationController.swift
//  BloomBuddyServer
//
//  Created by Mia Koring on 18.11.24.
//

import Vapor
import APNSCore
import APNS
import VaporAPNS
import Fluent

struct NotificationController {
    public static func sendNotification(_ req: Request, to id: UUID, title: String, subtitle: String, expiresIn: Int = 3600 * 48) async throws {
        let expiration = Int(Date().timeIntervalSince1970) + expiresIn
        
        let alert = buildAlertNotification(title: title, subtitle: subtitle, expiration: expiration)
        
        let devices = try await Device.query(on: req.db)
            .filter(\.$owner == id)
            .all()
        
        for device in devices {
            do {
                try await req.apns.client.sendAlertNotification(
                    alert,
                    deviceToken: device.token
                )
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    public static func sendNotification(_ req: Request, toDevice token: String, title: String, subtitle: String, expiresIn: Int = 3600 * 48) async throws {
        let expiration = Int(Date().timeIntervalSince1970) + expiresIn
        
        let alert = buildAlertNotification(title: title, subtitle: subtitle, expiration: expiration)
        
        try await req.apns.client.sendAlertNotification(alert, deviceToken: token)
    }
    
    public static func sendBackgroundNotification(_ req: Request, to id: UUID, data: SensorData, expiresIn: Int = 3600 * 48) async throws {
        let expiration = Int(Date().timeIntervalSince1970) + expiresIn
        let alert = APNSBackgroundNotification(
            expiration: .timeIntervalSince1970InSeconds(expiration),
            topic: "de.touchthegrass.BloomBuddy",
            payload: data)
        
        let devices = try await Device.query(on: req.db)
            .filter(\.$owner == id)
            .all()
        
        for device in devices {
            do {
                try await req.apns.client.sendBackgroundNotification(
                    alert,
                    deviceToken: device.token)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private static func buildAlertNotification(title: String, subtitle: String, expiration: Int) -> APNSAlertNotification<EmptyPayload> {
        APNSAlertNotification(
            alert: .init(title: .raw(title), subtitle: .raw(subtitle)),
            expiration: .timeIntervalSince1970InSeconds(expiration),
            priority: .consideringDevicePower,
            topic: "de.touchthegrass.BloomBuddy")
    }
}
