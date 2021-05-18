//
//  DriveViewController.swift
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

class DriveViewController: UIViewController,  CBPeripheralDelegate, CBCentralManagerDelegate {
    
    // Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var driveImage: UIImageView!
    
    var gestureLeft = ""
    var gestureRight = ""
    var confidenceLeft = 0.0
    var confidenceRight = 0.0
    var incl = 0
    var incr = 0
    var csl = [0.5,0.0,0.5,0.0]
    var csr = [0.5,0.5,0.0,0.0]
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
    var frame1Tag = 200;
    var frame2Tag = 400;
    var hours = 0
    var minutes = 0
    var seconds = 0
    var ll = 0
    var rr = 0
    var rl = 0
    var nn = 0
    var t = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        // extract node, element, alpha
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        frame1 = []
        frame2 = []
        buffer = ""
        origin = []
        origin1 = []
        origin2 = []
        // use this line to reset to band 1
        toggle = true
        frameString = ""
        self.driveImage.image = nil
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
        let rightNow = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let components: Array = formatter.string(from: rightNow).components(separatedBy: ":")
        hours = Int(components[0])!
        minutes = Int(components[1])!
        seconds = Int(components[2])!
        print(hours, minutes,seconds)
    }
    
    @IBOutlet weak var Background: UILabel!
    @IBOutlet weak var s: UILabel!
    @IBOutlet weak var leftOff: UILabel!
    @IBOutlet weak var rightOff: UILabel!
    @IBOutlet weak var time: UILabel!
    @IBOutlet weak var lt: UILabel!
    @IBOutlet weak var rt: UILabel!
    @IBOutlet weak var bt: UILabel!
    @IBOutlet weak var ptime: UILabel!
    @IBOutlet weak var ror: UILabel!
    @IBOutlet weak var summ: UILabel!
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from " +  peripheral.name!)
        connectButton.isEnabled = true
        disconnectButton.isEnabled = false
        let rightNow = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let components: Array = formatter.string(from: rightNow).components(separatedBy: ":")
        var a = Int(components[0])!
        var b = Int(components[1])!
        var c = Int(components[2])!
        var hdiff = b - minutes < 0 ? a - hours - 1 : a - hours
        var mdiff = c - seconds < 0 ? b - minutes - 1 : b - minutes
        var sdiff = c - seconds < 0 ? 60 + (c - seconds) : c - seconds
        var rrt = Double(rr) / Double(t) * 100
        rrt.round()
        var llt = Double(ll) / Double(t) * 100
        llt.round()
        var rlt = Double(rl) / Double(t) * 100
        rlt.round()
        var nnt = Double(nn) / Double(t) * 100
        nnt.round()
        Background.isHidden = false
        s.isHidden = false
        leftOff.isHidden = false
        rightOff.isHidden = false
        lt.isHidden = false
        rt.isHidden = false
        bt.isHidden = false
        time.isHidden = false
        ptime.isHidden = false
        ror.isHidden = false
        summ.isHidden = false
        
        lt.text = String(llt)+"%"
        rt.text = String(rrt)+"%"
        bt.text = String(rlt)+"%"
        time.text = String(hdiff)+":"+String(mdiff)+":"+String(sdiff)
        print(rr,ll,rl,nn,t)
        print(rrt,llt,rlt,nnt)
        print(hdiff, mdiff,sdiff)
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
                }
                else if origin2.count == 0{
                    origin2 = parseFrame(frameString)
                }
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
                            origin = origin2
                            ds2 = eit!.solve(v1: frame, v0: origin)
                        }
                        if (toggle && ds1.count != 0){
                            let (mesh,_) = mapSingle(ds: ds1,pts: pts,tri: tri, w: Double(self.view.frame.width))
                            mesh.tag = frame1Tag
                            let im = mesh.asImage()
                            classifyImage(im)
                            selectImage()
                        }
                        else if (!toggle && ds2.count != 0){
                            let (mesh,_) = mapSingle(ds: ds2,pts: pts,tri: tri, w: Double(self.view.frame.width))
                            mesh.tag = frame2Tag
                            let im = mesh.asImage()
                            classifyImage(im)
                            selectImage()
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
    
    func selectImage(){
        //Add gesture condition info in each case
        t += 1
        print(self.gestureLeft,self.gestureRight)
        if (self.confidenceLeft >= 0.5 && self.confidenceRight >= 0.5 && self.gestureRight == "Holding" && self.gestureLeft == "Holding"){
            nn += 1
            driveImage.image = nil
            driveImage.image = #imageLiteral(resourceName: "YY.jpg")
            print(1)
        }
        else if (self.confidenceRight >= 0.5 && self.gestureRight == "Holding"){
            ll += 1
            driveImage.image = nil
            driveImage.image = #imageLiteral(resourceName: "NY.jpg")
            print(2)
        }
        else if (self.confidenceLeft >= 0.5 && self.gestureLeft == "Holding"){
            rr += 1
            driveImage.image = nil
            driveImage.image = #imageLiteral(resourceName: "YN.jpg")
            print(3)
        }
        else{
            rl += 1
            driveImage.image = nil
            driveImage.image = #imageLiteral(resourceName: "NN.jpg")
            print(4)
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
                if (self.toggle){
                    self.gestureLeft = String(topClassifications!.identifier)
                    self.confidenceLeft = Double(topClassifications!.confidence)
//                    //for debugging
//                    self.gestureLeft = "Holding"
//                    self.confidenceLeft = self.csl[self.incl]
//                    self.incl = (self.incl + 1) % 4
                }
                else{
                    self.gestureRight = String(topClassifications!.identifier)
                    self.confidenceRight = Double(topClassifications!.confidence)
//                    //for debugging
//                    self.gestureRight = "Holding"
//                    self.confidenceRight = self.csr[self.incr]
//                    self.incr = (self.incl + 1) % 4
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


