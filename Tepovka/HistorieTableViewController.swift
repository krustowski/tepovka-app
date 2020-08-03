//
//  HistoryTableViewController.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

import UIKit

class HistorieTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var tableView: UITableView!
    
    // Pole pro historicka data
    var store = HodnotyMereni.instance
    
    // Cesta k historickym datum kvuli praci s daty (napr. smazani)
    var filePath: String {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        
        // Soubor HistorickaData pro Historii mereni -> HistorieTableViewController
        return (url!.appendingPathComponent("HistorickaData").path)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
        
        // Ulozit hodnoty; ulozeni novych stitku z PolozkaViewController
        NSKeyedArchiver.archiveRootObject(self.store.polozkyMereni, toFile: filePath)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: TableView Data Source

    // Pocet sekci TableView
    func tableView(in tableView: UITableView) -> Int {
        return 1
    }

    // Pocet vypisovanych bunek
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.store.polozkyMereni.count
    }
    
    // Obsah bunek
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Spravne napojeni identifikatoru bunky
        let cellIdentifier = "HistorieTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? HistorieTableViewCell else {
            fatalError("The dequeued cell is not an instance of HistorieTableViewCell.")
        }
        
        // Chronologicky sestupne razeni bunek
        let polozka = self.store.polozkyMereni.reversed()[indexPath.row]
        
        // Prirazeni nactenych hodnot polozky pole k prvkum bunky
        cell.datumMereni.text = polozka.datumMereni
        cell.labelMereni.text = polozka.labelMereni
        cell.hodnotaTF.text = polozka.hodnotaTF

        return cell
    }
    
    // Povoleni editace bunky
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Editacni chovani bunky
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Smazani polozky
        if editingStyle == .delete {
            store.polozkyMereni.remove(at: store.polozkyMereni.count - indexPath.row - 1)
            NSKeyedArchiver.archiveRootObject(self.store.polozkyMereni, toFile: filePath)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // MARK: Navigation
    
    // Systemova metoda pro predavani dat mezi Views = navigace
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // Overeni identifikatoru ViewController
        switch (segue.identifier ?? "") {
        case "ShowDetail":
            guard let DetailViewController = segue.destination as? PolozkaViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedCell = sender as? HistorieTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedCell) else {
                fatalError("The selected ccell is not being displayed by the table.")
            }
            
            // Prirad data zvolene bunky tride PolozkaViewController
            let selectedPolozka = self.store.polozkyMereni.reversed()[indexPath.row]
            DetailViewController.store = selectedPolozka
        
        default:
            fatalError("Unexpected Segue Identifier: \(String(describing: segue.identifier))")
        }
        
    }
}
