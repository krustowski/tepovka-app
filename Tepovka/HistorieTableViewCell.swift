//
//  HistorieTableViewCell.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

import UIKit

class HistorieTableViewCell: UITableViewCell {

    // Napojeni na prvky bunky a pojmenovani
    @IBOutlet weak var datumMereni: UILabel!
    @IBOutlet weak var labelMereni: UILabel!
    @IBOutlet weak var hodnotaTF: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
