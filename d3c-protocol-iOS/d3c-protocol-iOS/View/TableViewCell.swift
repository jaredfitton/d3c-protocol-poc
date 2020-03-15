//
//  TableViewCell.swift
//  d3c-protocol-iOS
//
//  Created by Jared Fitton on 3/15/20.
//  Copyright © 2020 Jared Fitton. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {

    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var message: UILabel!
    @IBOutlet weak var RTT: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
