//
//  Message.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 2/10/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import Foundation
import MultipeerConnectivity

//  Flag Meaning:
//  message = 0
//  routingInfoAddition = 1
//  routingRequest = 2
//  ackMessage = 3

struct Message: Codable {
    let body: String
    let flag: Int
    let routingInfo: Set<String>
    let sendingDevice: String
    let destinationDevice: String
   // let routingPath: [String]
}

