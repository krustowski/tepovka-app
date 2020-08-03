//
//  ViewController.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2019 Kryštof Šara. All rights reserved.
//

import UIKit

class ViewControllerOld: UIViewController, FrameExtractorDelegate {
    
    // Nova instance tridy FrameExtractor, abychom mohli pristupovat k jejim funkcim
    var frameExtractor: FrameExtractor!
    
    // Testovaci promenna pro vypocet HR
    var arrayHR: [Int] = []
    var lastHitHR: Int = 0
        
    // Odkaz na objekt ImageView z platna (storyboard)
    //@IBOutlet weak var imageView: UIImageView!
    
    // Odkaz na tlacitko stopButton
    @IBOutlet weak var stopButton: UIButton!
    
    // Pole s okamzitou HR
    @IBOutlet weak var labelHR: UILabel!
    
    // Graf testing
    @IBOutlet weak var lineChart: LineChart!
    @IBOutlet weak var lineChartDiff: LineChart!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Zavolani init()
        frameExtractor = FrameExtractor()
        
        // Prirazeni delegata sobe
        frameExtractor.delegate = self

        // Plot Test
        //plotTest()
    }
    
    // Testovani
    func plotTest() {
        
        // (index, hodnota, zesileni)
        let g: (Int, Double, Int) -> CGPoint = {
            return CGPoint(x: Double($0), y: $1 * Double($2))
        }
        
        // Smazani prvnich 50 vzorku, ktere jsou ovlivneny zmenou apertury po zapnuti blesku
        let currentFrame = frameExtractor.arrayPPG.count
        guard !(currentFrame < 50) else { return }
        
        // Zapnuti labelu az po 100 vzorcich
        //labelHR.isEnabled = currentFrame > 100
        
        // suffix bere poslednich n vzorku pole, efektivne to pak tvori klouzavy graf
        let dataPPG = frameExtractor.arrayPPG.dropFirst(47).suffix(300)
        let dataPPGDiff = frameExtractor.arrayPPGDiff.dropFirst(46).suffix(300)
        
        //print(dataPPG)
        
        // Mapovani bodu
        // https://stackoverflow.com/questions/28012205/map-or-reduce-with-index-in-swift
        let points: [CGPoint] = dataPPG.enumerated().map({ g($0, $1, 20) })
        let pointsDiff: [CGPoint] = dataPPGDiff.enumerated().map({ g($0, $1, 50) })
        
        // Okamzita TF
        showHR()
        
        // PPG graf
        lineChart.deltaX = 300
        lineChart.deltaY = 3
        lineChart.plot(points)
        
        // 1. diference graf
        lineChartDiff.deltaX = 300
        lineChartDiff.deltaY = 3
        lineChartDiff.plot(pointsDiff)
    }
    
    // Zobrazeni snimku od delegata
    func captured(image: UIImage) {
        //imageView.image = image
        //print("Snimek!")
        plotTest()
        
        // Proti preteceni grafu
        if(frameExtractor.arrayPPG.count == 3600) {
            stopAll()
        }
    }
    
    // Funkce pro spocteni aktualni tepove frekvence z vektoru diference
    func showHR() {
        guard frameExtractor.arrayPPG.count > 80 else { return }
        // Poslednich 100 vzorku
        let diffPPG = frameExtractor.arrayPPGDiff.suffix(70)
        
        // Prumer diference ~ testovaci prah
        //let threshold: Double = abs( diffPPG.reduce(0, +) / Double(diffPPG.count) )
        // co to sakra je za konstrukci
        let diffMin: Double = diffPPG.min() ?? 0
        let diffMax: Double = diffPPG.max() ?? 1
        
        let threshold = 0.50 * ( diffMax - diffMin )
        
        //labelHR.text = "lol"
        //print(threshold)
        let actualFrame: Int = frameExtractor.arrayPPGDiff.count - 1
        
        // :D
        if frameExtractor.arrayPPGDiff[actualFrame] > threshold {
            let rozdil = Double(actualFrame - lastHitHR)
            
            //print("ok")
            // Empirika jak prase
            if rozdil < 10 { return }
            //print(rozdil)
            
            labelHR.isEnabled = lastHitHR > 0
            labelHR.isHidden = false
            
            let HR = Int(round(60 * ( 30 / rozdil )))
            labelHR.text = String(HR)
            arrayHR.append(HR)
            self.lastHitHR = actualFrame
        }
    }
    
    // Zastaveni akvizice
    @IBAction func stopButtonPressed(_ sender: UIButton) {
        stopAll()
    }
    
    func stopAll() {
        frameExtractor.controlAcquision()
        
        // Zmena popisku tlacitka
        if frameExtractor.acquisitionStoped {
            // Zobrazeni grafu?
            plotTest()
            
            // Debug
            //print(frameExtractor.arrayPPG.count)
            //print(frameExtractor.arrayPPGDiff)
            
            if self.arrayHR.count > 3 {
                let avgHR = Int(round( Double(arrayHR.dropFirst().reduce(0, +)) / Double(arrayHR.dropFirst().count) ))
                labelHR.text = "avg: " + String( avgHR )
            }
            
            UIApplication.shared.isIdleTimerDisabled = false
            
            stopButton.setTitle("Start", for: .normal)
        } else {
            // Vyprazneni poli; musi se nastavit defaultne jako ve FrameExtractor!!! jinak bude hazet NaN (mas to osetrene, ze)
            // Edit: Provadi se jiz v ramci tridy FrameExtractor
            //frameExtractor.arrayPPG = []
            //frameExtractor.arrayPPGDiff = [0, 0]
            
            labelHR.isEnabled = false
            labelHR.isHidden = true
            self.arrayHR = []
            self.lastHitHR = 0
            
            UIApplication.shared.isIdleTimerDisabled = true
            
            stopButton.setTitle("Stop", for: .normal)
        }
    }
}

/*
extension UIImage {
    func pixelData(image: UIImage) -> [UInt8]? {
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else {
            return nil
        }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return pixelData
    }
}*/
