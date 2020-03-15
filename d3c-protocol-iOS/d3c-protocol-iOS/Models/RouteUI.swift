//
//  RouteUI.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 2/17/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import Foundation

class RouteUI {
    
    var destinationName: String
    var lastMessage: String = ""
    var RTT: String = ""
    
    init(destinationName: String) {
        self.destinationName = destinationName
    }
}
