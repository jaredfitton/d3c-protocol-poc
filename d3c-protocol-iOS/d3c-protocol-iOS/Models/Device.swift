//
//  Device.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 3/10/20.
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

    func send(text: String, with flag: Int) throws {
        
        var routingInfoToSend: Set<String> = []
        
        if flag == 1 || flag == 2 {
            routingInfoToSend = self.routingInfo
            routingInfoToSend.insert(MPCManager.instance.localPeerID.displayName)
        }
        
        let message = Message(body: text, flag: flag, routingInfo: routingInfoToSend)
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
                try self.send(text: "", with: 2)
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
            self.lastMessageReceived = message
            NotificationCenter.default.post(name: Device.messageReceivedNotification, object: message, userInfo: ["from": self])
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
            
        default:
            print("Unknown flag in message")
            return
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
                    try device.send(text: "", with: 1)
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
            try self.send(text: "", with: 1)
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
            if !self.routingInfo.contains(route) {
                self.routingInfo.insert(route)
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

