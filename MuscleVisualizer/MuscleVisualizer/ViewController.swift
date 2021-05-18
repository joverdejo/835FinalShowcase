//
//  ViewController.swift
//  MuscleVisualizer
//
//  Created by Joshua Verdejo on 3/29/21.
//

import UIKit
import CoreBluetooth
import CoreData
import ARKit
import EITKitMobile


let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
var pts = [[Double]]()
var tri = [[Int]]()
var eit : BP?

class ViewController: UIViewController,  CBPeripheralDelegate, CBCentralManagerDelegate, ARSCNViewDelegate {
    
    // Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    public var myCharacteristic : CBCharacteristic!
    @IBOutlet weak var sceneView: ARSCNView!
    let config = ARWorldTrackingConfiguration()
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
    var frameTag = 200
    var infoTag = 300
    var legTag = "Leg"
    var mesh = SCNView()
    var position = SCNVector3()
    let leg = SCNScene(named: "leg10000.obj")
    override func viewDidLoad() {
        super.viewDidLoad()
        //extract node, element, alpha
        (eit,pts,tri) = mesh_setup(16)
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showPhysicsShapes,ARSCNDebugOptions.showWireframe]
        sceneView.allowsCameraControl = true
        
        sceneView.session.run(config)
//        sceneView.allowsCameraControl = true;
        centralManager = CBCentralManager(delegate: self, queue: nil)
        let legNode = (leg?.rootNode.childNodes[0])!
        var legMaterial = SCNMaterial()
        legMaterial.transparency = 0.0
        legMaterial.transparent.contents = UIColor(red: 160/255, green: 82/255, blue: 45/255, alpha: 0.9)
        legNode.geometry?.firstMaterial = legMaterial
        legNode.position = SCNVector3(0.5,-0.21,-0.8)
        legNode.scale = SCNVector3(0.015,0.015,0.015)
        legNode.name = self.legTag
        sceneView.scene.rootNode.addChildNode(legNode)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
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
    
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//
//        guard let touch = touches.first else { return }
//        let location = touch.location(in: sceneView)
//        guard let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any) else {return}
//        let results = sceneView.session.raycast(query)
//        print(results)
//        guard let hitFeature = results.first else { return }
//        let hitTransform = hitFeature.worldTransform
//        position = SCNVector3(hitTransform.columns.3.x,
//                                         hitTransform.columns.3.y,
//                                         hitTransform.columns.3.z)
//
//    }
    
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
                        //only trigger every time both ds1 and ds2 have been refreshed (every time only ds2 is refreshed)
                        if (!toggle && ds1.count != 0 && ds2.count != 0){
                            mesh = mapMulti3D(ds1: ds1, ds2: ds2, pts: pts, tri: tri, position: position)
                            for t in 0..<tri.count{
                                let name = "t" + String(t)
                                let old = self.sceneView.scene.rootNode.childNode(withName: name, recursively: true)
                                let new = mesh.scene!.rootNode.childNode(withName: name, recursively: true)
                                
                                new?.eulerAngles = SCNVector3(Double.pi/2,0,0)
                                new?.position = SCNVector3(0.45, -1.744, -1.02)
                                new?.scale = SCNVector3(0.5,0.5,2.2)
                                if (old != nil) && (new != nil){
                                    self.sceneView.scene.rootNode.replaceChildNode(old!, with: new!)
                                }
                                else if (new != nil){
                                    self.sceneView.scene.rootNode.addChildNode(new!)
                                }
                            }
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
}



