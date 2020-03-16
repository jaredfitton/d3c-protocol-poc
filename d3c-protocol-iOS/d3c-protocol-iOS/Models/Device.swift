//
//  Device.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 2/10/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import Foundation
import MultipeerConnectivity

class Device: NSObject, MCSessionDelegate {
    let peerID: MCPeerID
    var session: MCSession? //[MCSession? : [String]]
    var name: String
    var state = MCSessionState.notConnected
    var lastMessageReceived: Message?
    var numConnectedDevices: Int
    static let messageReceivedNotification = Notification.Name("DeviceDidReceiveMessage")
    var routingInfo: Set<String> = []
    var didAcceptInvitation: Bool = false
    var messageSendTime: TimeInterval = 0
    
    init(peerID: MCPeerID) {
        self.name = peerID.displayName
        self.peerID = peerID
        self.numConnectedDevices = 0
        super.init()
    }
    
    func connect() {
        if self.session != nil {
            return
        }
        
        self.session = MCSession(peer: MPCManager.instance.localPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.session?.delegate = self
    }
    
    
    func disconnect() {
        self.session?.disconnect()
        self.session = nil
    }
    
    func invite(with browser: MCNearbyServiceBrowser) {
        self.connect()
        browser.invitePeer(self.peerID, to: self.session!, withContext: nil, timeout: 10)
    }

    func send(text: String, with flag: Int, senderName: String, destinationName: String, routingPath: [String]) throws {
        
        // Check to see if this device is sending a message
        if flag == 0 && senderName == MPCManager.instance.localPeerID.displayName {
            self.messageSendTime = Date.timeIntervalSinceReferenceDate
            logMessage(message: "Set message send time to \(self.messageSendTime)")
        }
        
        
        var routingInfoToSend: Set<String> = []
        
        // Compile the routing table for this device and prepare to send
        if flag == 1 || flag == 2 {
            for device in MPCManager.instance.devices {
                if device != self {
                    for route in device.routingInfo {
                        routingInfoToSend.insert(route)
                    }
                }
            }
            routingInfoToSend.insert(MPCManager.instance.localPeerID.displayName)
        }
        
        // If the device is sending an acknowledgement, we want to include this device
        // in the route path back to the initial sender
        var routePath = routingPath
        if flag == 3 && !routePath.contains(MPCManager.instance.localPeerID.displayName){
            routePath.append(MPCManager.instance.localPeerID.displayName)
        }
        
        let message = Message(body: text,
                              flag: flag,
                              routingInfo: routingInfoToSend,
                              sendingDevice: senderName,
                              destinationDevice: destinationName,
                              routingPath: routePath)
        
        let payload = try JSONEncoder().encode(message)
        
        do {
            try self.session?.send(payload, toPeers: [self.peerID], with: .reliable)
        } catch {
            throw error
        }
    }
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        self.state = state
        
//        print("Connected Peers:\n\(session.connectedPeers)")
//        print("PeerID: \(peerID.displayName)")
//        print("Status: \(state.rawValue)")
        
        NotificationCenter.default.post(name: MPCManager.Notifications.deviceDidChangeState, object: self)
        
        // If the state change is a new device connecting to the session
        if state == .connected && self.didAcceptInvitation {
            do {
                try self.send(text: "", with: 2, senderName: "", destinationName: "", routingPath: [])
                logMessage(message: "Sent routing info request to \(peerID.displayName)")
            } catch {
                logMessage(message: "Error during routing info request =>\n\( error.localizedDescription)")
            }
        }
    
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else {
            print("Error decoding message from: \(peerID.displayName)")
            return
        }
        
        switch message.flag {
        case 0: //Standard Message
            handleStandardMessage(message: message)
        case 1: // Routing Info Update
            handleRoutingInfoUpdate(message: message)
            
            // Device has been updated with routes and can connect to other devices now
            if MPCManager.instance.deviceIsConnecting {
               MPCManager.instance.deviceIsConnecting = false
            }
            
        case 2: // Routing Info Request
            routingInfoRequestResponse(message: message)
            
            // Device has been updated with routes and can connect to other devices now
            if MPCManager.instance.deviceIsConnecting {
               MPCManager.instance.deviceIsConnecting = false
            }
            
        case 3: // Ack Message
            handleAckMessage(message: message)
            
            
        default:
            print("Unknown flag in message")
            return
        }
        
        NotificationCenter.default.post(name: MPCManager.Notifications.deviceDidChangeState, object: self)

    }
    
    func handleAckMessage(message: Message) {
        
        if message.destinationDevice != MPCManager.instance.localPeerID.displayName {
            
            // Forward the message to the next device using the routing table
            let devices = MPCManager.instance.devices
            for device in devices {
                if device != self {
                    
                    // Get the current routing path and add the current device to it
                    var routePath = message.routingPath
                    routePath.append(MPCManager.instance.localPeerID.displayName)
                    
                    if device.routingInfo.contains(message.destinationDevice) {
                        do {
                            try device.send(text: message.body,
                                            with: 3,
                                            senderName: message.sendingDevice,
                                            destinationName: message.destinationDevice, routingPath: routePath)
                            logMessage(message: "Forwarded ack message to \(device.name)")
                        } catch {
                            logMessage(message: error.localizedDescription)
                        }
                    } else {
                        logMessage(message: "Destination device '\(message.destinationDevice)' is not in '\(device.name)''s routing table")
                    }
                }
            }
            
            return
        }
        
        let receiveTime = TimeInterval(message.body)
        let RTT = String(receiveTime!-messageSendTime)
        
        // Find the correct RouteUI object and update the last message
        for route in MPCManager.instance.routeMessages {
            if route.destinationName == message.sendingDevice {
                route.RTT = RTT
            }
        }
        
        NotificationCenter.default.post(name: Device.messageReceivedNotification, object: message, userInfo: ["from": self])
    }
    
    func handleStandardMessage(message: Message) {
        
        logMessage(message: "Recieved message '\(message.body)' from '\(message.sendingDevice)'")
        
        let currentDeviceName = MPCManager.instance.localPeerID.displayName
        
        // Display the message if this device is the message destination
        if message.destinationDevice == currentDeviceName {
            // Find the correct RouteUI object and update the last message
            for route in MPCManager.instance.routeMessages {
                if route.destinationName == message.sendingDevice {
                    route.lastMessage = message.body
                }
            }
            
            NotificationCenter.default.post(name: Device.messageReceivedNotification, object: message, userInfo: ["from": self])
            
            let time = String(Date.timeIntervalSinceReferenceDate)
            
            // Send ack message
            do {
                try self.send(text: time, with: 3, senderName: currentDeviceName, destinationName: message.sendingDevice, routingPath: [])
            } catch {
                logMessage(message: error.localizedDescription)
            }
            
            return
        }
        
        // Forward the message to the next device using the routing table
        let devices = MPCManager.instance.devices
        for device in devices {
            if device != self {
                
                if device.routingInfo.contains(message.destinationDevice) {
                    do {
                        try device.send(text: message.body,
                                        with: 0,
                                        senderName: message.sendingDevice,
                                        destinationName: message.destinationDevice, routingPath: [])
                    } catch {
                        logMessage(message: error.localizedDescription)
                    }
                } else {
                    logMessage(message: "Destination device '\(message.destinationDevice)' is not in '\(device.name)''s routing table")
                }
            }
        }
        
    }
    
    func handleRoutingInfoUpdate(message: Message) {
        logMessage(message: "Recieved routing update from \(peerID.displayName)")
        updateRoutingInfo(routes: message.routingInfo)
        broadcastRoutingInfoUpdate()
    }
    
    func broadcastRoutingInfoUpdate() {
        let MPCManagerDevices = MPCManager.instance.devices
        for device in MPCManagerDevices {
            if device != self {
                do {
                    logMessage(message: "Sending routing info to next \(device.name)")
                    try device.send(text: "", with: 1, senderName: "", destinationName: "", routingPath: [])
                } catch {
                    logMessage(message: "Error broadcasting routing info update to \(device.name)=>\n\(error.localizedDescription)")
                }
            }
        }
    }
    
    func routingInfoRequestResponse(message: Message) {
        logMessage(message: "Recieved routing info request from \(peerID.displayName)")
        print("Routing Info: \(message.routingInfo)")
        
        do {
            try self.send(text: "", with: 1, senderName: "", destinationName: "", routingPath: [])
        } catch {
            logMessage(message: error.localizedDescription)
        }
        updateRoutingInfo(routes: message.routingInfo)
        broadcastRoutingInfoUpdate()
    }
    
    // Updates the devices routing table with devices it does not yet contain
    func updateRoutingInfo(routes: Set<String>) {
        
        logMessage(message: "Update Routing Info...")
        logMessage(message: "Original Routing Info:\n\(self.routingInfo)")
        
        for route in routes {
            if !self.routingInfo.contains(route) && route != MPCManager.instance.localPeerID.displayName {
                self.routingInfo.insert(route)
                
                //This is where messages from devices will be store, used only by UI
                MPCManager.instance.routeMessages.append(RouteUI(destinationName: route))
            } else {
                logMessage(message: "Already contains route to \(route)")
            }
        }
        
        logMessage(message: "New Routing Info:\n\(self.routingInfo)")
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }

    func logMessage(message: String) {
        print("\(MPCManager.instance.localPeerID.displayName): \(message)")
    }
}

