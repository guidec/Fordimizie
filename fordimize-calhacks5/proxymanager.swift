import SmartDeviceLink
import Charts

struct GlobalStruct
    {
    public var speedData = [ChartDataEntry]() // Array of tuples
    public var torqueData = [ChartDataEntry]()
    public var fuelData = [ChartDataEntry]()
    public var rpmData = [ChartDataEntry]()
    
    init()
    {
    }
}



public class ProxyManager: NSObject {
    private let appName = "fordimize-calhacks5"
    private let appId = "12345"
    
    // Manager
    fileprivate var sdlManager: SDLManager!
    
    // Singleton
    static let sharedManager = ProxyManager()
    
    private override init() {
        super.init()
        
        // Used for TCP/IP Connection
        let lifecycleConfiguration = SDLLifecycleConfiguration(appName: appName, fullAppId: appId, ipAddress: "10.105.128.111", port: 12345)
        
        // App icon image
        if let appImage = UIImage(named: "AppIcon") {
            let appIcon = SDLArtwork(image: appImage, name: "Fordimize", persistent: true, as: .JPG /* or .PNG */)
            lifecycleConfiguration.appIcon = appIcon
        }
        
        lifecycleConfiguration.shortAppName = "Fordimize"
        lifecycleConfiguration.appType = .media
        
        let lockscreenConfiguration = SDLLockScreenConfiguration.enabledConfiguration(withAppIcon: UIImage(named: "AppIcon")!, backgroundColor: UIColor(patternImage: UIImage(named: "coolbackground")!))
        let configuration = SDLConfiguration(lifecycle: lifecycleConfiguration, lockScreen: lockscreenConfiguration, logging: .default(), fileManager: .default())
        sdlManager = SDLManager(configuration: configuration, delegate: self)
    }
    
    func subscribe(){
        NotificationCenter.default.addObserver(self, selector: #selector(vehicleDataAvailable(_:)), name: .SDLDidReceiveVehicleData, object: nil)
        let subscribeVehicleData = SDLSubscribeVehicleData()
        subscribeVehicleData.speed = true as NSNumber & SDLBool
        subscribeVehicleData.engineTorque = true as NSNumber & SDLBool
        subscribeVehicleData.fuelLevel = true as NSNumber & SDLBool
        subscribeVehicleData.rpm = true as NSNumber & SDLBool
        
        
        sdlManager.send(request: subscribeVehicleData) { (request, response, error) in
            guard let response = response as? SDLSubscribeVehicleDataResponse else { return }
            
            guard response.success.boolValue == true else {
                if response.resultCode == .disallowed {
                    // Not allowed to register for this vehicle data.
                    print("Not allowed to register for this vehicle data.")
                } else if response.resultCode == .userDisallowed {
                    // User disabled the ability to give you this vehicle data
                    print("User disabled the ability to give you this vehicle data.")
                } else if response.resultCode == .ignored {
                    if let prndlData = response.prndl {
                        if prndlData.resultCode == .dataAlreadySubscribed {
                            // You have access to this data item, and you are already subscribed to this item so we are ignoring.
                        } else if prndlData.resultCode == .vehicleDataNotAvailable {
                            // You have access to this data item, but the vehicle you are connected to does not provide it.
                        } else {
                            print("Unknown reason for being ignored: \(prndlData.resultCode)")
                        }
                    } else {
                        print("Unknown reason for being ignored: \(String(describing: response.info))")
                    }
                } else if let error = error {
                    print("Encountered Error sending SubscribeVehicleData: \(error)")
                }
                return
            }
            
            // Successfully subscribed
            print("Successfully subscribed to SPEED")
        }
    }
    
    var counter = 1
    
    
    @objc func vehicleDataAvailable(_ notification: SDLRPCNotificationNotification) {
        guard let onVehicleData = notification.notification as? SDLOnVehicleData else {
            return
        }
        
        var SDLspeed: Int?
        var SDLtorque: Int?
        var SDLfuel: Float?
        var SDLrpm: Int?
        if onVehicleData.speed != nil {
            //            speedChanged = true
            SDLspeed = Int(onVehicleData.speed!.intValue)
        }
        if onVehicleData.engineTorque != nil {
            SDLtorque = Int(onVehicleData.engineTorque!.intValue)
        }
        if onVehicleData.fuelLevel != nil {
            SDLfuel = Float(onVehicleData.fuelLevel!.floatValue)
        }
        if onVehicleData.rpm != nil {
            SDLrpm = Int(onVehicleData.rpm!.intValue)
        }
        
        self.sdlManager.screenManager.beginUpdates()
        if counter % 3 == 0 {
            
            if SDLspeed != nil {
                let value = ChartDataEntry(x: Double(counter * 3), y: Double(SDLspeed!))
                dataStash.speedData.append(value)
                self.sdlManager.screenManager.textField1 = "Speed is \(SDLspeed!) MPH"
            }
            if SDLtorque != nil{
                let value = ChartDataEntry(x: Double(counter * 3), y: Double(SDLtorque!))
                dataStash.torqueData.append(value)
                self.sdlManager.screenManager.textField2 = "Engine Torque is \(SDLtorque!)"
            }
            if SDLfuel != nil {
                let value = ChartDataEntry(x: Double(counter * 3), y: Double(SDLfuel!))
                dataStash.fuelData.append(value)
                self.sdlManager.screenManager.textField3 = "Fuel Level is \(SDLfuel!)"
            }
            if SDLrpm != nil {
                let value = ChartDataEntry(x: Double(counter * 3), y: Double(SDLrpm!))
                dataStash.rpmData.append(value)
                self.sdlManager.screenManager.textField4 = "RPM is \(SDLrpm!)"
            }
        }
        counter += 1
        self.sdlManager.screenManager.endUpdates()
        
    }
    
    func connect() {
        // Start watching for a connection with a SDL Core
        sdlManager.start { (success, error) in
            if success {
                // Your app has successfully connected with the SDL Core
                self.subscribe()
            }
        }
    }
}


//MARK: SDLManagerDelegate
extension ProxyManager: SDLManagerDelegate {
    public func managerDidDisconnect() {
        print("Manager disconnected!")
    }
    
    public func hmiLevel(_ oldLevel: SDLHMILevel, didChangeToLevel newLevel: SDLHMILevel) {
        print("Went from HMI level \(oldLevel) to HMI level \(newLevel)")
    }
}
