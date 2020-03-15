//
//  MPCManager.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 3/10/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import Foundation
import MultipeerConnectivity

class MPCManager: NSObject, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    static let instance = MPCManager()
    let localPeerID: MCPeerID
    let serviceType = "d3c-poc"
    var devices: [Device] = []
    var deviceIsConnecting: Bool = false
    
    var connectedDevices: [Device] {
        return self.devices.filter { $0.state == .connected }
    }
    
    struct Notifications {
        static let deviceDidChangeState = Notification.Name("deviceDidChangeState")
    }
    
    override init() {
        if let data = UserDefaults.standard.data(forKey: "peerID"), let id = NSKeyedUnarchiver.unarchiveObject(with: data) as? MCPeerID {
            self.localPeerID = id
        } else {
            let peerID = MCPeerID(displayName: UIDevice.current.name)
            let data = NSKeyedArchiver.archivedData(withRootObject: peerID)
            UserDefaults.standard.set(data, forKey: "peerID")
            self.localPeerID = peerID
        }
        
        super.init()
        
        self.advertiser = MCNearbyServiceAdvertiser(peer: localPeerID, discoveryInfo: nil, serviceType: self.serviceType)
        
        self.advertiser.delegate = self
        
        self.browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: self.serviceType)
        
        self.browser.delegate = self
    }
    
    func device(for id: MCPeerID) -> Device {
        let device = Device(peerID: id)
        self.devices.append(device)
        
        return device
    }

    func start() {
        self.advertiser.startAdvertisingPeer()
        self.browser.startBrowsingForPeers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    @objc func enteredBackground() {
        for device in self.devices {
            device.disconnect()
//            logMessage(message: "Device '\(discDevice.name)' disconnected")
//            self.devices.remove(at: deviceIndex)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        // Only one device can be connecting at a time to prevent closed loop
        // network chains
        if deviceIsConnecting {
            return
        }
    
        // The MPCManager can only be connected to two devices at a time
        if self.devices.count >= 2 {
            return
        }
        
        // If there is already a connection to this device through the network
        // chain, we do not want to add it again
        if doesDeviceExistInRoutingInfo(peerID: peerID) {
            return
        }
        
        // Return if the displayName is bigger than peerId sending the invitation
        if localPeerID.displayName > peerID.displayName {
            return
        }
        
        deviceIsConnecting = true
        
        let device = MPCManager.instance.device(for: peerID)
        device.connect()
        device.didAcceptInvitation = true
        logMessage(message: "Accepted invitation and connected to \(device.name)")
        
        invitationHandler(true, device.session)
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    
        
        // Only one device can be connecting at a time to prevent closed loop
        // network chains
        if deviceIsConnecting {
            return
        }
        
        // The MPCManager can only be connected to two devices at a time
        if self.devices.count >= 2 {
            return
        }
        
        // If there is already a connection to this device through the network
        // chain, we do not want to add it again
        if doesDeviceExistInRoutingInfo(peerID: peerID) {
            return
        }
        
        // Return if the displayName is smaller than peerId sending the invitation
        if localPeerID.displayName < peerID.displayName {
            return
        }
        
        deviceIsConnecting = true
        
        let device = MPCManager.instance.device(for: peerID)
        device.invite(with: self.browser)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        disconnectDevice(peerID: peerID)
    }
    
    func doesDeviceExistInRoutingInfo(peerID: MCPeerID) -> Bool {
        for device in devices {
            if device.routingInfo.contains(peerID.displayName) {
                return true
            }
        }
        return false
    }
    
    func getDeviceIndex(with peerId: MCPeerID) -> Int? {
        for i in 0...1 {
            if self.devices[i].peerID == peerId {
                return i
            }
        }
        return nil
    }
    
    func disconnectDevice(peerID: MCPeerID) {
        guard let deviceIndex = getDeviceIndex(with: peerID) else {
            return
        }
        self.devices[deviceIndex].disconnect()
        logMessage(message: "Disconnected from \(self.devices[deviceIndex].name)")
        self.devices.remove(at: deviceIndex)
    }
    
    func logMessage(message: String) {
        print("\(self.localPeerID.displayName): \(message)")
    }
}

