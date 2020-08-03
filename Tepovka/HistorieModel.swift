//
//  HistorieModel.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

import Foundation

class HistorieMereni: NSObject, NSCoding {
    
    // Struktura klicu pro decoder
    struct Keys {
        static let datumMereni = "datumMereni"
        static let labelMereni = "labelMereni"
        static let hodnotaTF = "hodnotaTF"
    }
    
    // Privatni pole ulozenych dat
    private var _datumMereni = ""
    private var _labelMereni = ""
    private var _hodnotaTF = ""
    
    // Setters a getters pro delegata NSCoding
    var datumMereni: String {
        get { return _datumMereni }
        set { _datumMereni = newValue }
    }
    var labelMereni: String {
        get { return _labelMereni }
        set { _labelMereni = newValue }
    }
    var hodnotaTF: String {
        get { return _hodnotaTF }
        set { _hodnotaTF = newValue }
    }
    
    // Inicializace hodnot
    override init() {}
    init(datumMereni: String, labelMereni: String, hodnotaTF: String) {
        self._datumMereni = datumMereni
        self._labelMereni = labelMereni
        self._hodnotaTF = hodnotaTF
    }
    
    // NSCoding inicializator = nacteni zakodovanych hodnot, protokolarni metoda
    required convenience init?(coder decoder: NSCoder) {
        guard let datum = decoder.decodeObject(forKey: Keys.datumMereni) as? String,
            let label = decoder.decodeObject(forKey: Keys.labelMereni) as? String,
            let hodnota = decoder.decodeObject(forKey: Keys.hodnotaTF) as? String
            else { return nil }
        
        // Predani nactenych hodnot objektu
        self.init(
            datumMereni: datum,
            labelMereni: label,
            hodnotaTF: hodnota
        )
    }
    
    // Protokolarni metoda ke kodovani
    func encode(with coder: NSCoder) {
        coder.encode(self._datumMereni, forKey: Keys.datumMereni)
        coder.encode(self._labelMereni, forKey: Keys.labelMereni)
        coder.encode(self._hodnotaTF, forKey: Keys.hodnotaTF)
    }
}


// Pomocna trida pro zisk dat
class HodnotyMereni {
    static let instance = HodnotyMereni()
    
    private init() {}
    
    var polozkyMereni: [HistorieMereni] = []
}
