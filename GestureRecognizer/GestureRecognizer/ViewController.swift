//
//  ViewController.swift
//  GestureRecognizer
//
//  Created by Joshua Verdejo on 3/29/21.
//

import UIKit
import CoreBluetooth
import CoreData
import CoreML
import Vision
import EITKitMobile


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

class ViewController: UIViewController,  CBPeripheralDelegate, CBCentralManagerDelegate {
    
    // Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var saveToggle: UISwitch!
    @IBOutlet weak var gestureLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel!
    
    var gesture = ""
    var confidence = 0.0
    public var myCharacteristic : CBCharacteristic!
    var frameString = ""
    var buffer = ""
    var origin = [Double]()
    var frame = [Double]()
    var frameTag = 200;
    var infoTag = 300;
    override func viewDidLoad() {
        super.viewDidLoad()
        // extract node, element, alpha
        (eit,pts,tri) = mesh_setup(16)
        var ds_black = [Double](repeatElement(0.0, count: tri.count*3))
        let (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
        mesh.tag = frameTag
        info.tag = infoTag
        mesh.center = CGPoint(x: self.view.frame.width/2, y: self.view.frame.width)
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
    }
    
    @IBAction func resetTouched(_ sender: Any) {
        frame = []
        buffer = ""
        origin = []
        frameString = ""
        if (self.view.viewWithTag(frameTag) != nil){
            self.view.viewWithTag(frameTag)!.removeFromSuperview()
        }
        if (self.view.viewWithTag(infoTag) != nil){
            self.view.viewWithTag(infoTag)!.removeFromSuperview()
        }
        gestureLabel.isHidden = true
        confidenceLabel.isHidden = true
        var ds_black = [Double](repeatElement(0.0, count: tri.count*3))
        let (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
        mesh.tag = frameTag
        info.tag = infoTag
        mesh.center = CGPoint(x: self.view.frame.width/2, y: self.view.frame.width)
        self.view.addSubview(mesh)
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
                if origin.count == 0{
                    origin = parseFrame(frameString)
                }
                else{
                    frame = parseFrame(frameString)
//                    print(origin.count,frame.count)
                    if (frame != origin && frame.count == origin.count){
                        //                        print(origin.count,frame.count)
                        let ds : [Double] = eit!.solve(v1: frame, v0: origin)
                        if (self.view.viewWithTag(frameTag) != nil){
                            self.view.viewWithTag(frameTag)!.removeFromSuperview()
                        }
                        if (self.view.viewWithTag(infoTag) != nil){
                            self.view.viewWithTag(infoTag)!.removeFromSuperview()
                        }
                        let (mesh,info) = mapSingle(ds: ds,pts: pts,tri: tri, w: Double(self.view.frame.width))
                        mesh.tag = frameTag
                        info.tag = infoTag
                        mesh.center = CGPoint(x: self.view.frame.width/2, y: self.view.frame.width)
                        self.view.addSubview(mesh)
                        //Add for a colorbar/max and min values
//                        self.view.addSubview(info)
                        let im = mesh.asImage()
                        classifyImage(im)
                        if saveToggle.isOn{
                        UIImageWriteToSavedPhotosAlbum(im,self,#selector(handleFrameSaved(_:didFinishSavingWithError:contextInfo:)), nil)
                        }

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
        let model = try VNCoreMLModel(for: CombinedGestures().model)
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
                DispatchQueue.main.async {
                    self.gestureLabel.isHidden = false
                    self.gestureLabel.text = self.gesture
                    self.confidenceLabel.isHidden = false
                    self.confidenceLabel.text  = "[confidence: " + String(round(self.confidence*10000)/100) + "]"
                }
                
                
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



////  ViewController.swift
////  GestureRecognizer
////  Show
////  Created by Joshua Verdejo on 3/29/21.
////
//
//import UIKit
//import CoreBluetooth
//import CoreData
//import CoreML
//import Vision
//import EITKitMobile
//
//
//let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
//let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
//var pts = [[Double]]()
//var tri = [[Int]]()
//var eit : BP?
//
//extension UIView {
//
//    // Using a function since `var image` might conflict with an existing variable
//    // (like on `UIImageView`)
//    func asImage() -> UIImage {
//        if #available(iOS 10.0, *) {
//            let renderer = UIGraphicsImageRenderer(bounds: bounds)
//            return renderer.image { rendererContext in
//                layer.render(in: rendererContext.cgContext)
//            }
//        } else {
//            UIGraphicsBeginImageContext(self.frame.size)
//            self.layer.render(in:UIGraphicsGetCurrentContext()!)
//            let image = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            return UIImage(cgImage: image!.cgImage!)
//        }
//    }
//}
//
//class ViewController: UIViewController,  CBPeripheralDelegate, CBCentralManagerDelegate {
//
//    // Properties
//    private var centralManager: CBCentralManager!
//    private var peripheral: CBPeripheral!
//    @IBOutlet weak var connectButton: UIButton!
//    @IBOutlet weak var disconnectButton: UIButton!
//    @IBOutlet weak var resetButton: UIButton!
//    @IBOutlet weak var saveToggle: UISwitch!
//    @IBOutlet weak var gestureLabel: UILabel!
//    @IBOutlet weak var confidenceLabel: UILabel!
//
//    var gesture = ""
//    var confidence = 0.0
//    public var myCharacteristic : CBCharacteristic!
//    var frameString = ""
//    var buffer = ""
//    var origin = [Double]()
//    var frame = [Double]()
//    var frameTag = 200;
//    var infoTag = 300;
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // extract node, element, alpha
//        (eit,pts,tri) = mesh_setup(16)
//        var ds_black = [Double](repeatElement(0.0, count: tri.count*3))
//        let (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
//        mesh.tag = frameTag
//        info.tag = infoTag
//        mesh.center = CGPoint(x: self.view.frame.width/2, y: self.view.frame.width)
//        self.view.addSubview(mesh)
//        centralManager = CBCentralManager(delegate: self, queue: nil)
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        saveToggle.setOn(false, animated: false)
//    }
//
//
//    @IBAction func scanButtonTouched(_ sender: Any) {
//        centralManager.stopScan()
//        print("Central scanning for", serviceUUID);
//        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
//    }
//
//
//    @IBAction func disconnectTouched(_ sender: Any) {
//        centralManager?.cancelPeripheralConnection(peripheral!)
//    }
//
//    @IBAction func resetTouched(_ sender: Any) {
//        frame = []
//        buffer = ""
//        origin = []
//        frameString = ""
//        if (self.view.viewWithTag(frameTag) != nil){
//            self.view.viewWithTag(frameTag)!.removeFromSuperview()
//        }
//        if (self.view.viewWithTag(infoTag) != nil){
//            self.view.viewWithTag(infoTag)!.removeFromSuperview()
//        }
//        gestureLabel.isHidden = true
//        confidenceLabel.isHidden = true
//        var ds_black = [Double](repeatElement(0.0, count: tri.count*3))
//        let (mesh,info) = mapSingle(ds: ds_black,pts: pts,tri: tri, w: Double(self.view.frame.width))
//        mesh.tag = frameTag
//        info.tag = infoTag
//        mesh.center = CGPoint(x: self.view.frame.width/2, y: self.view.frame.width)
//        self.view.addSubview(mesh)
//    }
//
//
//
//    func sendText(text: String) {
//        if (peripheral != nil && myCharacteristic != nil) {
//            let data = text.data(using: .utf8)
//            peripheral!.writeValue(data!,  for: myCharacteristic!, type: CBCharacteristicWriteType.withResponse)
//        }
//    }
//
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        // We've found it so stop scan
//        self.centralManager.stopScan()
//        // Copy the peripheral instance
//        self.peripheral = peripheral
//        self.peripheral.delegate = self
//
//        // Connect!
//        self.centralManager.connect(self.peripheral, options: nil)
//    }
//
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        switch central.state {
//        case .poweredOff:
//            print("Bluetooth is switched off")
//        case .poweredOn:
//            print("Bluetooth is switched on")
//        case .unsupported:
//            print("Bluetooth is not supported")
//        default:
//            print("Unknown state")
//        }
//    }
//
//    // The handler if we do connect succesfully
//    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        if peripheral == self.peripheral {
//            print("Connected to your board")
//            peripheral.discoverServices([serviceUUID])
//        }
//        connectButton.isEnabled = false
//        disconnectButton.isEnabled = true
//    }
//
//    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        print("Disconnected from " +  peripheral.name!)
//        connectButton.isEnabled = true
//        disconnectButton.isEnabled = false
//    }
//
//    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
//        print(error!)
//    }
//    @objc func handleFrameSaved(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
//        if let error = error {
//            print( error.localizedDescription )
//        } else {
//            print("Saved!")
//        }
//    }
//
//
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//        guard let services = peripheral.services else { return }
//        for service in services {
//            peripheral.discoverCharacteristics(nil, for: service)
//        }
//    }
//
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
//        guard let characteristics = service.characteristics else { return }
//        myCharacteristic = characteristics[0]
//        peripheral.setNotifyValue(true, for: myCharacteristic)
//        peripheral.readValue(for: myCharacteristic)
//
//    }
//    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
//                    error: Error?){
//        if let string = String(bytes: myCharacteristic.value!, encoding: .utf8) {
//
//            frameString += string
//            if string.contains("framef") || string.contains("framei"){
//                while (frameString.last! != "i" && frameString.last! != "f"){
//                    buffer = String(frameString.last!) + buffer
//                    frameString.removeLast()
//                }
//                if origin.count == 0{
//                    origin = parseFrame(frameString)
//                }
//                else{
//                    frame = parseFrame(frameString)
////                    print(origin.count,frame.count)
//                    if (frame != origin && frame.count == origin.count){
//                        //                        print(origin.count,frame.count)
//                        let ds : [Double] = eit!.solve(v1: frame, v0: origin)
//                        if (self.view.viewWithTag(frameTag) != nil){
//                            self.view.viewWithTag(frameTag)!.removeFromSuperview()
//                        }
//                        if (self.view.viewWithTag(infoTag) != nil){
//                            self.view.viewWithTag(infoTag)!.removeFromSuperview()
//                        }
//                        let (mesh,info) = mapSingle(ds: ds,pts: pts,tri: tri, w: Double(self.view.frame.width))
//                        mesh.tag = frameTag
//                        info.tag = infoTag
//                        mesh.center = CGPoint(x: self.view.frame.width/2, y: self.view.frame.width)
//                        self.view.addSubview(mesh)
//                        //Add for a colorbar/max and min values
////                        self.view.addSubview(info)
//                        let im = mesh.asImage()
//                        classifyImage(im)
//                        if saveToggle.isOn{
//                        UIImageWriteToSavedPhotosAlbum(im,self,#selector(handleFrameSaved(_:didFinishSavingWithError:contextInfo:)), nil)
//                        }
//
//                    }
//                }
//                frameString = buffer
//                buffer = ""
//                sendText(text: "")
//            }
//            else{
//                sendText(text: "")
//            }
//            sendText(text: "")
//            if (string == "RESET"){
//                resetTouched(0)
//            }
//        } else {
//            print(myCharacteristic.value!)
//            print("not a valid UTF-8 sequence")
//        }
//
//
//    }
//    // 1
//    private lazy var classificationRequest: VNCoreMLRequest = {
//      do {
//        // 2
//        let model = try VNCoreMLModel(for: CombinedGestures().model)
//        // 3
//        let request = VNCoreMLRequest(model: model) { request, _ in
//            if let classifications =
//              request.results as? [VNClassificationObservation] {
//                let topClassifications = classifications.first.map {
//                  (confidence: $0.confidence, identifier: $0.identifier)
//                }
//                print("Top Confidence Score: \(topClassifications!.confidence)")
//                print("Top Classification: \(topClassifications!.identifier)")
//                self.confidence = Double(topClassifications!.confidence)
//                self.gesture = topClassifications!.identifier
//                if topClassifications!.identifier == "One Finger"{
//                    self.gesture = "Thumb Up"
//                }
//                if topClassifications!.identifier == "Fist"{
//                    self.gesture = "Rock"
//                }
//                if topClassifications!.identifier == "Stretch"{
//                    self.gesture = "Paper"
//                }
//                DispatchQueue.main.async {
//                    self.gestureLabel.isHidden = false
//                    self.gestureLabel.text = self.gesture
//                    self.confidenceLabel.isHidden = false
//                    self.confidenceLabel.text  = "[confidence: " + String(round(self.confidence*10000)/100) + "]"
//                }
//
//
//            }
//        }
//        // 4
////        request.imageCropAndScaleOption = .centerCrop
//        return request
//      } catch {
//        // 5
//        fatalError("Failed to load Vision ML model: \(error)")
//      }
//    }()
//
//
//    func classifyImage(_ image: UIImage) {
//      // 1
//      guard let orientation = CGImagePropertyOrientation(
//        rawValue: UInt32(image.imageOrientation.rawValue)) else {
//        return
//      }
//      guard let ciImage = CIImage(image: image) else {
//        fatalError("Unable to create \(CIImage.self) from \(image).")
//      }
//      // 2
//
//        let handler =
//          VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
//        do {
//          try handler.perform([self.classificationRequest])
//        } catch {
//          print("Failed to perform classification.\n\(error.localizedDescription)")
//        }
//
//    }
//}
//
//
