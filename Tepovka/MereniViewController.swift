//
//  MereniViewController.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

import UIKit
import AVFoundation

class MereniViewController: UIViewController, FrameExtractorDelegate {
        
    // Polozky k ulozeni do Modelu
    var datumMereni: String = ""
    var labelMereni: String = ""
    var hodnotaTF: Int = 0
    
    // Testovaci promenna pro vypocet HR
    var arrayHR: [Int] = []
    var lastHitHR: Int = 0
    
    // Odkaz na vykreslovaci plochu View
    @IBOutlet weak var lineChart: LineChart!
        
    // Uzivatelske nastaveni View
    let defaults = UserDefaults.standard
    
    var zobrazPrubeh: Bool = false
    var zobrazProgress: Bool = false
    var oznamKonec: Bool = false
    var delkaAkvizice: Int = 600 // = sekundy * 30 FPS
    var koeficientPrahu: Float = 0.5
    
    // Odkazy na obrazek, tlacitka, stitek a progresBar
    @IBOutlet weak var mereniImage: UIImageView!
    @IBOutlet weak var mereniButton: UIButton!
    @IBOutlet weak var mereniLabelTF: UILabel!
    @IBOutlet weak var mereniProgress: UIProgressView!
    
    // FrameExtractor init
    var frameExtractor: FrameExtractor!
    
    // Cesta k historickym datum
    var filePath: String {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        
        // Soubor HistorickaData pro Historii mereni -> HistorieTableViewController
        return (url!.appendingPathComponent("HistorickaData").path)
    }
    
    // Ukazatel na ulozene hodnoty mereni
    var store = HodnotyMereni.instance
    
    // Datum a cas
    let formatDatum = DateFormatter()
    let formatCas = DateFormatter()
    
    // Akce pro tlacitko
    @IBAction func mereniButtonClicked(_ sender: Any) {
        stopAll()
    }
    
    // Zachyceni snimku pomoci delegata FrameExtractor
    func captured(image: UIImage) {
        showHR()
        
        // Pri dosazeni nastavene delky akvizice zastav
        if (frameExtractor.arrayPPG.count == delkaAkvizice) {
            stopAll()
        }
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Nacteni tridy FrameExtractor = inicializace kamery a blesku
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        
        // Inicializace UI (MereniViewController)
        mereniImage.image = UIImage(named: "heart-120.png")
        mereniButton.setTitle("Start", for: .normal)
        mereniLabelTF.isHidden = true
        mereniProgress.isHidden = true
        mereniProgress.progress = 0.0
        
        // Formatovani datumu a casu
        formatDatum.locale = Locale(identifier: "cs_CZ")
        formatCas.locale = Locale(identifier: "cs_CZ")
        formatDatum.dateStyle = .medium
        formatCas.timeStyle = .medium
        
        // Prvnotni animace srdce
        animujSrdce()
        
        // Nacteni uzivatelskeho nastaveni
        nactiNastaveni()
        
        // Nacteni historickych dat mereni
        if let udaje = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as? [HistorieMereni] {
            self.store.polozkyMereni = udaje
        }
    }
    
    // MARK: Private methody
    
    func showHR() {
        // Zesileni grafu
        // (index, hodnota, zesileni)
        let g: (Int, Double, Int) -> CGPoint = {
            return CGPoint(x: Double($0), y: $1 * Double($2))
        }
        
        // Smazani prvnich 50 vzorku, ktere jsou ovlivneny zmenou apertury po zapnuti blesku
        let currentFrame = frameExtractor.arrayPPG.count
        guard !(currentFrame < 50) else { return }
        
        // Suffix() bere poslednich n vzorku pole, efektivne to pak tvori klouzavy graf
        let dataPPG = frameExtractor.arrayPPG.dropFirst(40).suffix(150)
        //let dataPPGDiff = frameExtractor.arrayPPGDiff.dropFirst(46).suffix(300)
                
        // Mapovani bodu
        // https://stackoverflow.com/questions/28012205/map-or-reduce-with-index-in-swift
        let points: [CGPoint] = dataPPG.enumerated().map({ g($0, $1, 3) })
        //let pointsDiff: [CGPoint] = dataPPGDiff.enumerated().map({ g($0, $1, 50) })
        
        // Okamzita TF
        guard frameExtractor.arrayPPG.count > 50 else { return }
        let diffPPG = frameExtractor.arrayPPGDiff.suffix(50)
        
        let diffMin: Double = diffPPG.min() ?? 0
        let diffMax: Double = diffPPG.max() ?? 1
        
        // Prah
        let threshold = Double(koeficientPrahu) * ( diffMax - diffMin )

        let actualFrame: Int = frameExtractor.arrayPPGDiff.count - 1
        
        // Prekroceni prahu
        if frameExtractor.arrayPPGDiff[actualFrame] >= threshold {
            let rozdil = Double(actualFrame - lastHitHR)
            
            // dolni propust pro 180 BPM
            if rozdil < 10 { return }
            
            mereniLabelTF.isHidden = !(lastHitHR > 0)
            
            // Spocti aktualni TF a ukaz ji na obrazovce
            let HR = Int(round(60 * ( 30 / rozdil )))
            mereniLabelTF.text = String(HR)
            arrayHR.append(HR)
            self.lastHitHR = actualFrame
            
            animujSrdce()
        }
        
        // PPG graf
        if self.zobrazPrubeh {
            lineChart.deltaX = 150
            lineChart.deltaY = 1
            lineChart.yMin = CGFloat(diffPPG.min() ?? 0)
            lineChart.yMax = CGFloat(diffPPG.max() ?? 1)
            lineChart.plot(points)
        }
        
        // Posunuti progressu, pokud je povolen
        if self.zobrazProgress {
            self.mereniProgress.progress = Float(frameExtractor.arrayPPG.count) / Float(self.delkaAkvizice)
        }
        
        /*
        // 1. diference graf
        lineChartDiff.deltaX = 150
        lineChartDiff.deltaY = 1
        lineChartDiff.plot(pointsDiff)
        */
    }
    
    func stopAll() {
        // Zastavit akvizici, pokud bezi; jinak ji spustit
        frameExtractor.controlAcquision()
        
        // Nacti uzivatelske nastaveni a zobraz HR –> dale jede skrze delegata FrameExtractor
        nactiNastaveni()
        
        mereniButton.setTitle(frameExtractor.acquisitionStoped ? "Start" : "Stop", for: .normal)
        //mereniLabelTF.isHidden = frameExtractor.acquisitionStoped
        mereniProgress.isHidden = !(self.zobrazProgress && frameExtractor.acquisitionStoped)
        
        // Rizeni timeru inaktivity uzivatele kvuli setreni baterie = vypnuto pri akvizici
        UIApplication.shared.isIdleTimerDisabled = !frameExtractor.acquisitionStoped
        
        // Schovani TabBaru, aby nemohl uzivatel manipulovat s aplikaci pri mereni.
        self.tabBarController?.tabBar.isHidden = !frameExtractor.acquisitionStoped
        
        // Akvizice byla zastavena => nastavit View pro spusteni
        if frameExtractor.acquisitionStoped {
            showHR()
            
            // Spocteni medianove TF (zakomentovany prumer TF)
            if self.arrayHR.count > 5 {
                self.hodnotaTF = Int(round(calculateMedian(array: arrayHR)))
                //self.hodnotaTF = Int(round( Double(arrayHR.dropFirst(2).reduce(0, +)) / Double(arrayHR.dropFirst(2).count) ))
                mereniLabelTF.text = String(self.hodnotaTF)
            }
                        
            // Ulozeni mereni do /Documents
            if self.hodnotaTF > 0 && self.arrayHR.count > 5 {
                ulozMereni()
            }
            
            // Oznameni konce mereni - dvojita vibrace
            if self.oznamKonec {
                AudioServicesPlayAlertSound(SystemSoundID(1011))
            }
            
            // Vynulovani pro dalsi mereni
            self.hodnotaTF = 0
            self.lastHitHR = 0
            self.arrayHR = []
            
        // Akvizice byla spustena
        } else {
            lineChart.isHidden = !self.zobrazPrubeh
            mereniLabelTF.isHidden = true
            mereniProgress.isHidden = !self.zobrazProgress
        }
    }
    
    // http://seimith.github.io/swift/uiview/views/tutorial/animation/2016/09/18/Swift-Pulsating-UIView.html
    // https://stackoverflow.com/questions/34729578/uibutton-heartbeat-animation
    // Upravena metoda pro animaci
    private func animujSrdce() {
        let animaceSrdce = CASpringAnimation(keyPath: "transform.scale")
        animaceSrdce.duration = 0.4
        animaceSrdce.fromValue = 1.0
        animaceSrdce.toValue = 1.5
        animaceSrdce.autoreverses = true
        animaceSrdce.repeatCount = 1
        animaceSrdce.initialVelocity = 0.5
        animaceSrdce.damping = 0.8

        let animationGroup = CAAnimationGroup()
        animationGroup.duration = 1.0
        animationGroup.repeatCount = 1
        animationGroup.animations = [animaceSrdce]

        self.mereniImage.layer.add(animaceSrdce, forKey: "pulse")
    }
    
    // Nacteni uzivatelskeho nastaveni
    private func nactiNastaveni() {
        self.zobrazPrubeh = defaults.bool(forKey: "ZobrazPrubeh") ?? true
        self.zobrazProgress = defaults.bool(forKey: "ZobrazProgress") ?? false
        self.oznamKonec = defaults.bool(forKey: "OznamKonec") ?? false
        self.delkaAkvizice = defaults.integer(forKey: "DelkaAkvizice") ?? 600
        self.koeficientPrahu = defaults.float(forKey: "KoeficientPrahu") ?? 0.5
        
        print("Prubeh: " + String(zobrazPrubeh) + ", Progres: " + String(zobrazProgress) + ", Delka: " + String(delkaAkvizice))
    }
    
    // https://stackoverflow.com/questions/44450266/get-median-of-array
    // Upravena metoda pro vypocet medianu
    private func calculateMedian(array: [Int]) -> Float {
        let sorted = array.sorted()
        if sorted.count % 2 == 0 {
            return Float((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
        } else {
            return Float(sorted[(sorted.count - 1) / 2])
        }
    }
    
    // Ulozeni skonceneho mereni
    private func ulozMereni() {
        // Slovnik s hodnotami
        let poleMereni: NSDictionary = [
            "arrayPPG": frameExtractor.arrayPPG.dropFirst(20),
            "arrayHR": arrayHR
        ]
        
        // UNIX Timestamp
        let timestamp = NSDate().timeIntervalSince1970
        
        // Ulozeni raw dat do /Documents/timestamp.txt
        let URLDoc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentURL = URLDoc.first {
            let mereniSouborURL = documentURL.appendingPathComponent(String(timestamp) + ".txt").path
            poleMereni.write(toFile: mereniSouborURL, atomically: true)
        }
        
        // Zobrazeni aktualniho datumu a casu
        self.datumMereni = self.formatDatum.string(from: NSDate() as Date) + " " + self.formatCas.string(from: NSDate() as Date)
        
        // Ulozeni historickych dat (datum, stitek a TF) do /Documents/HistorickaData
        let novaPolozka = HistorieMereni(datumMereni: self.datumMereni, labelMereni: self.labelMereni, hodnotaTF: String(self.hodnotaTF))
        self.store.polozkyMereni.append(novaPolozka)
        
        NSKeyedArchiver.archiveRootObject(self.store.polozkyMereni, toFile: filePath)
    }
}
