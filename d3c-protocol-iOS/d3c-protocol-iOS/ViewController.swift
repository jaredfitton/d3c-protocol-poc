//
//  Device.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 2/10/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate  {
    @IBOutlet var tableView: UITableView!
    
    var devices: [Device] = []
    var routingTable: [RouteUI] = []
    
    @objc func reload( ){
        print("Got here")
        self.routingTable = MPCManager.instance.routeMessages
        
        //self.devices = Array(MPCManager.instance.devices).sorted(by: { $0.name < $1.name })
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: MPCManager.Notifications.deviceDidChangeState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: MPCManager.Notifications.deviceDidChangeState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: Device.messageReceivedNotification, object: nil)
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.reload()
    }


    func getRoutingTables() -> [String] {
        var routingTable: [String] = []
        for device in MPCManager.instance.devices {
            for route in device.routingInfo {
                if !routingTable.contains(route) {
                    routingTable.append(route)
                }
            }
        }
        return routingTable
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("Num rows")
        return self.routingTable.count
            //self.devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let device = self.routingTable[indexPath.row]
        cell.textLabel?.text = "\(device.destinationName)"
        cell.detailTextLabel?.text = device.lastMessage
        return cell
    }

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = self.routingTable[indexPath.row]
        let alert = UIAlertController(title: "Send To \(device.destinationName)", message: "Enter your message:", preferredStyle: .alert)
        alert.addTextField { field in }
        
        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text {
                MPCManager.instance.prepareToSendMessage(messageBody: text, destinationName: device.destinationName)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
