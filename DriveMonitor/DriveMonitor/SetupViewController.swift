//
//  ViewController.swift
//  DriveMonitor
//
//  Created by Joshua Verdejo on 3/29/21.
//


import UIKit
import CoreBluetooth
import CoreData
import CoreML
import Vision
import EITKitMobile
import SwiftUI

let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
var pts = [[Double]]()
var tri = [[Int]]()
var eit : BP?

extension UIView {
    
    // Using a function since `var image` might conflict with an existing variable
    // (like on `UIImageView`)
    func asImage() -> UIImage {
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }
        } else {
            UIGraphicsBeginImageContext(self.frame.size)
            self.layer.render(in:UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return UIImage(cgImage: image!.cgImage!)
        }
    }
}

class SetupViewController: UIViewController,  CBPeripheralDelegate, CBCentralManagerDelegate {
    
    // Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var saveToggle: UISwitch!
//    @IBOutlet weak var gestureLabel: UILabel!
    var gesture = ""
    var confidence = 0.0
    public var myCharacteristic : CBCharacteristic!
    var frameString = ""
    var buffer = ""
    var origin = [Double]()
    var origin1 = [Double]()
    var origin2 = [Double]()
    var frame = [Double]()
    var frame1 = [Double]()
    var frame2 = [Double]()
    var ds1 = [Double]()
    var ds2 = [Double]()
    var toggle = true
    var frame1Tag = 200
    var frame2Tag = 400
    override func viewDidLoad() {
        super.viewDidLoad()
        // extract node, element, alpha
        (eit,pts,tri) = mesh_setup(16)
        var ds_black = [Double](repeatElement(0.0, count: tri.count*3))
        var (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
        mesh.tag = frame1Tag
        mesh.center = CGPoint(x: self.view.frame.width/4, y: self.view.frame.width)
        mesh.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
        self.view.addSubview(mesh)
        (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
        mesh.tag = frame2Tag
        mesh.center = CGPoint(x: self.view.frame.width*3/4, y: self.view.frame.width)
        mesh.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: -0.5)
        self.view.addSubview(mesh)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveToggle.setOn(false, animated: false)
    }
    
    
    @IBAction func scanButtonTouched(_ sender: Any) {
        centralManager.stopScan()
        print("Central scanning for", serviceUUID);
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    
    @IBAction func disconnectTouched(_ sender: Any) {
        centralManager?.cancelPeripheralConnection(peripheral!)
//        showReport()
    }
    
    @IBAction func resetTouched(_ sender: Any) {
        frame = []
        frame1 = []
        frame2 = []
        buffer = ""
        origin = []
        origin1 = []
        origin2 = []
        // use this line to reset to band 1
        toggle = true
        frameString = ""
        if (self.view.viewWithTag(frame1Tag) != nil){
            self.view.viewWithTag(frame1Tag)!.removeFromSuperview()
        }
        if (self.view.viewWithTag(frame2Tag) != nil){
            self.view.viewWithTag(frame2Tag)!.removeFromSuperview()
        }
        var ds_black = [Double](repeatElement(0.0, count: tri.count*3))
        let (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
        let (mesh2,info2) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
        mesh.tag = frame1Tag
        mesh.center = CGPoint(x: self.view.frame.width/4, y: self.view.frame.width)
        mesh.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
        self.view.addSubview(mesh)
        mesh2.tag = frame2Tag
        mesh2.center = CGPoint(x: self.view.frame.width*3/4, y: self.view.frame.width)
        mesh2.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
        self.view.addSubview(mesh2)
    }
    
    
    
    func sendText(text: String) {
        if (peripheral != nil && myCharacteristic != nil) {
            let data = text.data(using: .utf8)
            peripheral!.writeValue(data!,  for: myCharacteristic!, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // We've found it so stop scan
        self.centralManager.stopScan()
        // Copy the peripheral instance
        self.peripheral = peripheral
        self.peripheral.delegate = self
        
        // Connect!
        self.centralManager.connect(self.peripheral, options: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Bluetooth is switched off")
        case .poweredOn:
            print("Bluetooth is switched on")
        case .unsupported:
            print("Bluetooth is not supported")
        default:
            print("Unknown state")
        }
    }
    
    // The handler if we do connect succesfully
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.peripheral {
            print("Connected to your board")
            peripheral.discoverServices([serviceUUID])
        }
        connectButton.isEnabled = false
        disconnectButton.isEnabled = true
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from " +  peripheral.name!)
        connectButton.isEnabled = true
        disconnectButton.isEnabled = false
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(error!)
    }
    @objc func handleFrameSaved(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print( error.localizedDescription )
        } else {
            print("Saved!")
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        myCharacteristic = characteristics[0]
        peripheral.setNotifyValue(true, for: myCharacteristic)
        peripheral.readValue(for: myCharacteristic)
        
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?){
        if let string = String(bytes: myCharacteristic.value!, encoding: .utf8) {
            
            frameString += string
            if string.contains("framef") || string.contains("framei"){
                while (frameString.last! != "i" && frameString.last! != "f"){
                    buffer = String(frameString.last!) + buffer
                    frameString.removeLast()
                }
                if origin1.count == 0{
                    origin1 = parseFrame(frameString)
                    origin2 = origin1
                }
//                else if origin2.count == 0{
//                    origin2 = parseFrame(frameString)
//                }
                else{
                    frame = parseFrame(frameString)
                    if (frame != origin1 && frame != origin2 && frame.count == origin1.count && frame.count == origin2.count){
                        if toggle{
                            frame1 = frame
                            origin = origin1
                            ds1 = eit!.solve(v1: frame, v0: origin)
                        }
                        else{
                            frame2 = frame
                            origin = origin1
                            ds2 = eit!.solve(v1: frame, v0: origin)
                        }
                        print(toggle, ds1.count)
                        if (toggle && ds1.count != 0){
                            let (mesh,info) = mapSingle(ds: ds1,pts: pts,tri: tri, w: Double(self.view.frame.width))
                            mesh.tag = frame1Tag
                            let im = mesh.asImage()
                            if (saveToggle.isOn){
                                UIImageWriteToSavedPhotosAlbum(im,self,#selector(handleFrameSaved(_:didFinishSavingWithError:contextInfo:)), nil)
                            }
                            mesh.center = CGPoint(x: self.view.frame.width/4, y: self.view.frame.width)
                            mesh.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
                            if (self.view.viewWithTag(frame1Tag) != nil){
                                self.view.viewWithTag(frame1Tag)!.removeFromSuperview()
                            }
                            self.view.addSubview(mesh)
                        }
                        else if (!toggle && ds2.count != 0){
                            let (mesh,info) = mapSingle(ds: ds2,pts: pts,tri: tri, w: Double(self.view.frame.width))
                            mesh.tag = frame2Tag
                            let im = mesh.asImage()
                            if (saveToggle.isOn){
                                UIImageWriteToSavedPhotosAlbum(im,self,#selector(handleFrameSaved(_:didFinishSavingWithError:contextInfo:)), nil)
                            }
                            mesh.center = CGPoint(x: self.view.frame.width*3/4, y: self.view.frame.width)
                            mesh.transform = CGAffineTransform.identity.scaledBy(x: -0.5, y: 0.5)
                            if (self.view.viewWithTag(frame2Tag) != nil){
                                self.view.viewWithTag(frame2Tag)!.removeFromSuperview()
                            }
                            self.view.addSubview(mesh)
                        }
                        toggle = !toggle
                    }
                }
                frameString = buffer
                buffer = ""
                sendText(text: "")
            }
            else{
                sendText(text: "")
            }
            sendText(text: "")
        } else {
            print(myCharacteristic.value!)
            print("not a valid UTF-8 sequence")
        }
        
    }
    // 1
    private lazy var classificationRequest: VNCoreMLRequest = {
      do {
        // 2
        let model = try VNCoreMLModel(for: DrivingClassifier().model)
        // 3
        let request = VNCoreMLRequest(model: model) { request, _ in
            if let classifications =
              request.results as? [VNClassificationObservation] {
                let topClassifications = classifications.first.map {
                  (confidence: $0.confidence, identifier: $0.identifier)
                }
                print("Top Confidence Score: \(topClassifications!.confidence)")
                print("Top Classification: \(topClassifications!.identifier)")
                self.confidence = Double(topClassifications!.confidence)
                self.gesture = topClassifications!.identifier
//                DispatchQueue.main.async {
//                    self.gestureLabel.isHidden = false
//                    self.gestureLabel.text = self.gesture + " confidence: " + String(round(self.confidence*10000)/100)
//                }
                
                
            }
        }
        // 4
//        request.imageCropAndScaleOption = .centerCrop
        return request
      } catch {
        // 5
        fatalError("Failed to load Vision ML model: \(error)")
      }
    }()


    func classifyImage(_ image: UIImage) {
      // 1
      guard let orientation = CGImagePropertyOrientation(
        rawValue: UInt32(image.imageOrientation.rawValue)) else {
        return
      }
      guard let ciImage = CIImage(image: image) else {
        fatalError("Unable to create \(CIImage.self) from \(image).")
      }
      // 2
     
        let handler =
          VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
        do {
          try handler.perform([self.classificationRequest])
        } catch {
          print("Failed to perform classification.\n\(error.localizedDescription)")
        }
      
    }
}


