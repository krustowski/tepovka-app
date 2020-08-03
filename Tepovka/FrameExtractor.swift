//
//  FrameExtractor.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

// https://medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a

import UIKit
import AVFoundation

// Protokol pro delegata
protocol FrameExtractorDelegate: class {
    // Funkce volana pokazde, kdyz je dostupny UIImage snimek
    func captured(image: UIImage)
}

// Obsahuje delegata pro prijem snimku z AVCaptureVideoDataOutput
class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Session zajistuje proud dat ze vstupu na vystup.
    private let captureSession = AVCaptureSession()
    
    // Seriova fronta pro asynchronni ukony, ktere by blokovaly hlavni vlakno/proces
    private let sessionQueue = DispatchQueue(label: "Session queue")
    
    // Povoleni pouziti kamery
    private var permissionGranted: Bool = false
    
    // Prvni spusteni blesku (fix proti zablikani pri spusteni aplikace)
    private var firstFlashTry: Bool = true
    
    // Globalni promenna pro ulozeni zarizeni
    private var camera: AVCaptureDevice!
    
    // Atributy zaznamu (typ kamery a kvalita snimku)
    private let position = AVCaptureDevice.Position.back
    // https://developer.apple.com/documentation/avfoundation/avcapturesession/preset
    private let quality = AVCaptureSession.Preset.medium
    
    // Odkaz na delegata
    weak var delegate: FrameExtractorDelegate?
    
    // Jeden globalni kontext pro prevod zasobniku na snimek
    private let context = CIContext()
    
    // FPS
    private let preferredFPS: Double = 30.0
    
    // Pole pro hodnoty PPG
    var arrayPPG: [Double] = []
    var arrayPPGDiff: [Double] = [0, 0]
    
    // Pomocna logicka promenna pro zjisteni stavu celkove akvizice
    var acquisitionStoped = false
    
    // Inicializace tridy (protokolarni metoda NSObject)
    override init() {
        super.init()
        checkPermission()
        
        // Pojistka proti zaseknuti queue po pozastaveni; nastavit session az po spravnem vstupu od uzivatele (povoleni ke kamere); cekame na vstup uzivatele
        sessionQueue.async { [unowned self] in
            // Nakonfiguruj a spusti session pro zisk snimku
            self.configureSession()
            self.captureSession.startRunning()
            
            // Vypni akvizici pri spusteni aplikace
            self.controlAcquision()
        }
    }
    
    // MARK: AVCaptureSession konfigurace
    
    // Metoda pro overeni povoleni pro pouziti kamery, resp. stavu povoleni
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            // Uzivatel jiz povolil pouziti kamery
            self.permissionGranted = true
            break
        
        case .notDetermined:
            // Uzivatel jeste nerozhodl o povoleni -> zobrazit vyzvu (jde o asynchronni volani, takze je treba pozastavit session)
            requestPermission()
            break

        default:
            // Ostatni moznost, tj. uzivatel nemuze kameru pouzit, nebo nepovolil jeji pouziti => app nejde pouzit
            self.permissionGranted = false
            break
        }
    }
    
    // Vyzva k povoleni pristupu ke kamere
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    // Nastaveni session
    private func configureSession() {
        // Pokud neni povoleni udeleno, ukonci nastavovani
        guard permissionGranted else {
            return
        }
        // Prirazeni kvality snimku definovaneho na pocatku tridy
        captureSession.sessionPreset = quality
        
        // Vyber zarizeni pro snimani
        selectCaptureDevice()
        
        // Vytvoreni vstupu zarizeni
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: camera) else { return }
        
        // Pridani vstupu do session, pokud lze pridat vstup
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)

        // Video vystup
        let videoOutput = AVCaptureVideoDataOutput()
        
        // Prirazeni delegata sobe; trida podporuje protokol pro predavani snimku pomoci dedicnosti z vyssi tridy (Delegate)
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        
        // Pridani vystupu z session, pokud lze pridat vystup
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        
        // Kontrola, zda je vystup spravne orientovan
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
    }
    
    // Vyber z dostupnych zarizeni (kamer)
    private func selectCaptureDevice() {
        // Nalezeni dostupnych zarizeni
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
        
        // Ulozeni zarizeni
        let devices = session.devices
        
        // Nalezeni aktivniho zarizeni
        for camera in devices {
            // Predni kamera, nepouziva se
            if camera.position == .front {}
            
            // Zadni kamera
            if camera.position == .back {
                do {
                    try camera.lockForConfiguration()
                } catch {
                    fatalError("Nelze konfigurovat kameru")
                }
                
                // Zamknuti fokusace kamery
                camera.focusMode = .locked
                
                // Nastaveni vzorkovaci frekvence FPS
                // https://stackoverflow.com/questions/49522934/camera-issue-when-setting-avcapturedevice-to-1-fps
                let format = camera.activeFormat
                
                for range in format.videoSupportedFrameRateRanges { //as! [AVFrameRateRange] {
                    if range.minFrameRate <= preferredFPS &&
                        range.maxFrameRate >= preferredFPS {
                        let time: CMTime = CMTime(value: 1, timescale: CMTimeScale(preferredFPS))
                        camera.activeVideoMaxFrameDuration = time
                        camera.activeVideoMinFrameDuration = time
                        break
                    }
                }
                
                camera.unlockForConfiguration()
                self.camera = camera
                //return camera
            }
        }
    }
    
    // Inicializace a zapnutí svitilny
    private func toggleFlash() {
        do {
            try camera.lockForConfiguration()
            camera.focusMode = .locked
            
            // Zapnuti blesku, pokud zarizeni ma svitilnu
            if camera.hasTorch {
                
                // Zapni svitilnu pouze pokud se nejedna o spusteni aplikace
                if firstFlashTry {
                    firstFlashTry = false
                } else {
                    camera.torchMode = .on
                }
            }
            camera.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    // Meotda volana tlacitkem "Stop", nebo nasbiranim 600 (defaultne) vzorku
    func controlAcquision () {
        // Zastav akvizici pokud bezi
        if captureSession.isRunning {
            captureSession.stopRunning()
            sessionQueue.suspend()
            acquisitionStoped = true
            
        // Spust akvizici, pokud nebezi
        } else {
            // Vynulovani poli
            arrayPPG = []
            arrayPPGDiff = []
            
            sessionQueue.resume()
            captureSession.startRunning()
            acquisitionStoped = false
        }
    }
    
    // Metoda, ktera zasobnik sampleBuffer prevadi na zobrazitelny snimek (UIImage)
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        // Prvni prevedeni na CVImageBuffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        // CIImage z knihovny UIKit
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // K pameti setrnejsi prevod pres CIContext
        //let context = CIContext() // zgloblizovano
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
    
        // Vraceni UIImage
        return UIImage(cgImage: cgImage)
    }
    
    // Metoda volana pokazde, kdyz je dostupny snimek v zasobniku; buffer obsahuje informace o kazdem snimku (sampleBuffer); metoda je volana ze serial queue
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Nahozeni svitilny
        toggleFlash()
        
        // Prevod snimku v ramci serial queue (nezatezujeme hlavni frontu)
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        // Prumer snimku a inverze hodnoty
        let data = uiImage.averageColor
        arrayPPG.append(Double(1-data[0]))
        
        let arrayPPGCount = arrayPPG.count
        
        // Spocteni prvni diference signalu
        if arrayPPGCount > 1 {
            arrayPPGDiff.append( arrayPPG[arrayPPGCount - 1] - arrayPPG[arrayPPGCount - 2] )
        }
        
        // Hlavni fronta (main queue) -> informuj delegata
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.captured(image: uiImage)
        }
    }
}

// Rozsireni pro ziskani prumeru snimku
// https://www.hackingwithswift.com/example-code/media/how-to-read-the-average-color-of-a-uiimage-using-ciareaaverage
extension UIImage {
    var averageColor: [Float32] {
        guard let inputImage = CIImage(image: self) else { return [] }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return [] }
        guard let outputImage = filter.outputImage else { return [] }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        //return UIColor(red: CGFloat(bitmap[0]) / 1, green: CGFloat(bitmap[1]) / 1, blue: CGFloat(bitmap[2]) / 1, alpha: CGFloat(bitmap[3]) / 1)
        // [R, G, B]
        return [Float(bitmap[0])/255, Float(bitmap[1])/255, Float(bitmap[2])/255]
    }
}
