//
//  NastaveniViewController.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

import UIKit

class NastaveniViewController: UIViewController {
    
    // Odkazy na prvky View
    @IBOutlet weak var prubehSwitch: UISwitch!
    @IBOutlet weak var progressSwitch: UISwitch!
    @IBOutlet weak var oznamKonecSwitch: UISwitch!
    @IBOutlet weak var delkaAkviziceSlider: UISlider!
    @IBOutlet weak var delkaAkviziceLabel: UILabel!
    @IBOutlet weak var koeficientPrahuSlider: UISlider!
    @IBOutlet weak var koeficientPrahuLabel: UILabel!
    
    // Uzivatelska nastaveni
    let defaults = UserDefaults.standard
    
    // Posun slideru
    @IBAction func delkaAkvizicePosun(_ sender: UISlider) {
        defaults.set(round(delkaAkviziceSlider.value), forKey: "DelkaAkvizice")
        defaults.set(koeficientPrahuSlider.value, forKey: "KoeficientPrahu")

        // Uprava stitku u slideru
        delkaAkviziceLabel.text = "Délka akvizice (" + String(Int(round(delkaAkviziceSlider.value / 30.0))) + " sekund)"
        koeficientPrahuLabel.text = "Koeficient prahu (" + String(koeficientPrahuSlider.value) + ")"
    }
    
    // Prepnuti nektereho prepinace = zmena hodnot se projevi pri jakekoliv zmene
    @IBAction func prepnutiSwitche(_ sender: UISwitch) {
        defaults.set(prubehSwitch.isOn, forKey: "ZobrazPrubeh")
        defaults.set(progressSwitch.isOn, forKey: "ZobrazProgress")
        defaults.set(oznamKonecSwitch.isOn, forKey: "OznamKonec")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nactiNastaveni()        
    }
    
    // Nacteni aktualniho uzivatelskeho nastaveni
    func nactiNastaveni() {
        prubehSwitch.isOn = defaults.bool(forKey: "ZobrazPrubeh") ?? true
        progressSwitch.isOn = defaults.bool(forKey: "ZobrazProgress") ?? false
        oznamKonecSwitch.isOn = defaults.bool(forKey: "OznamKonec") ?? false
        delkaAkviziceSlider.value = Float(defaults.integer(forKey: "DelkaAkvizice")) ?? 600
        koeficientPrahuSlider.value = defaults.float(forKey: "KoeficientPrahu") ?? 0.5
        
        // Uprava stitku slideru
        delkaAkviziceLabel.text = "Délka akvizice (" + String(Int(round(delkaAkviziceSlider.value / 30.0))) + " sekund)"
        koeficientPrahuLabel.text = "Koeficient prahu (" + String(koeficientPrahuSlider.value) + ")"
    }
}
