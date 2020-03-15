//
//  Message.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 3/10/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import Foundation
import MultipeerConnectivity

//  Flag Meaning:
//  message = 0
//  routingInfoAddition = 1
//  routingInfoNegation = 3
//  routingRequest = 2

struct Message: Codable {
//  let destinationDevice: String
    let body: String
    let flag: Int
    let routingInfo: Set<String>
}
