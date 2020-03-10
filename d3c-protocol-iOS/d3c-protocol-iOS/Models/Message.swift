//
//  Message.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 3/10/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import Foundation

struct Message: Codable {
    let body: String
    let isRouting: Bool
}

extension Device {
    func send(text: String) throws {
        let message = Message(body: text, isRouting: false)
        let payload = try JSONEncoder().encode(message)
        try self.session?.send(payload, toPeers: [self.peerID], with: .reliable)
    }
}
