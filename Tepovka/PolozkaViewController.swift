//
//  PolozkaViewController.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

import UIKit

class PolozkaViewController: UIViewController, UINavigationControllerDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // Odkazy na prvky View
    @IBOutlet weak var vysledekDatum: UILabel!
    @IBOutlet weak var typMereniPicker: UIPickerView!
    @IBOutlet weak var vysledekTF: UILabel!
    @IBOutlet weak var ulozitButton: UIBarButtonItem!
    
    // Vsechny stitky
    let stitky = [
        "Klid", "Před cvičením", "Po cvičení", "Po probuzení", "Před spaním", "Únava", "Káva"
    ]
    
    // Pole pro predavani hodnot zvolene bunky, polozky
    var store: HistorieMereni?
    
    // Stisknuto "Zrusit" -> Zahozeni upravy mereni a navrat
    @IBAction func zahoditUpravu(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    // Stisknuto "Ulozit" -> Uloz upravy a navrat
    @IBAction func ulozitUpravu(_ sender: UIBarButtonItem) {
        let stitek = typMereniPicker.selectedRow(inComponent: 0)
        self.store?.labelMereni = stitky[stitek]
        dismiss(animated: true, completion: nil)
    }
    
    // Pocet "valcu" pickeru
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
         return 1
    }
    
    // Pocet polozek na "valci"
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return stitky.count
    }
    
    // Metoda delagata dotazujici se na data
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return stitky[row]
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Zobrazeni aktualniho datumu a casu
        vysledekDatum.text = store?.datumMereni
        typMereniPicker.selectRow(stitky.firstIndex(of: self.store!.labelMereni) ?? 0, inComponent: 0, animated: true)
        vysledekTF.text = store?.hodnotaTF
    }
    
    // MARK: Navigation

    // Systemova metoda pro navigaci
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // Definovani navratoveho ViewControlleru
        guard let button = sender as? UIBarButtonItem, button === ulozitButton else { return }
    }

}
