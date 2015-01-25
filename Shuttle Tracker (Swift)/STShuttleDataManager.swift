//
//  STShuttleDataManager.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import Alamofire
import MapKit

// NSNotification names
let kShuttleStatusesUpdatedNotification = "kShuttleStatusesUpdated"
let kShuttleStatusUpdateErrorOccurredNotification = "kShuttleStatusUpdateErrorOccurred"

class STShuttleDataManager: NSObject {
    
    private var alamofireManager : Alamofire.Manager?
    
    override init() {
        super.init()
        self.setupAlamofireManager()
        
        // Listen for notification and act appropriately if the remotely-specified ShuttleDataRefreshInterval variable changes.
        NSNotificationCenter.defaultCenter()
            .addObserverForRemoteConfigurationNotificationName(
                "ShuttleDataRefreshInterval",
                object: nil,
                queue: NSOperationQueue.mainQueue(),
                usingBlock:
                { _ in
                    self.setupAlamofireManager()
                }
        )
    }
    
    func setupAlamofireManager() {
        
        // Set up our own Alamofire manager to allow for shortened timeouts. We may end up backed up if they take too long.
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let updateInterval : NSTimeInterval = NSUserDefaults.standardUserDefaults().doubleForKey("ShuttleDataRefreshInterval")
        configuration.timeoutIntervalForResource = updateInterval
        
        self.alamofireManager = Alamofire.Manager(configuration: configuration)
    }
    
    func updateData() {
        
        // Grab the URL from which we should be pulling shuttle locations and statuses.
        let requestURLString = NSUserDefaults.standardUserDefaults().objectForKey("ShuttleStatusUpdateURL") as String
        
        let requestParameters = [
            // Include the app's version and its UUID, so we can modify configuration remotely based on those things, if necessary.
            "version" : NSBundle.mainBundle().infoDictionary?["CFBundleVersion"]! as String,
            "uuid" : UIDevice.currentDevice().identifierForVendor.UUIDString,
            
            // Include the app's selected localization, in case we want to make any changes to the configuration remotely because of it.
            "locale" : NSBundle.mainBundle().preferredLocalizations[0] as String
        ]
        
        STAppDelegate.didStartNetworking()
        
        self.alamofireManager!.request(.GET, requestURLString, parameters: requestParameters)
            .responseJSON { (request, response, JSON, error) in
                
                STAppDelegate.didStopNetworking()
                
                if error != nil || JSON == nil {
                    println("An error occurred while fetching shuttle data.")
                    NSNotificationCenter.defaultCenter().postNotificationName(
                        kShuttleStatusUpdateErrorOccurredNotification,
                        object: nil,
                        userInfo: ["message" : NSLocalizedString("Data retrieval error", comment:"")]
                    )
                }
                else {
                    // Received valid JSON response!
                    
                    var shuttlesReceivedMap = NSMutableDictionary()
                    
                    for eachItem in JSON as NSArray {
                        let vehicleDictionary = (eachItem as NSDictionary)["vehicle"] as NSDictionary
                        
                        var newShuttle = STShuttle()
                        newShuttle.identifier = vehicleDictionary["id"] as String
                        newShuttle.title = vehicleDictionary["name"] as String
                        newShuttle.subtitle = vehicleDictionary["subtitle"] as String
                        
                        let positionDictionary = vehicleDictionary["latest_position"] as NSDictionary
                        newShuttle.coordinate = CLLocationCoordinate2DMake(
                            positionDictionary["latitude"]!.doubleValue,
                            positionDictionary["longitude"]!.doubleValue
                        )
                        newShuttle.heading = positionDictionary["heading"]!.floatValue
                        newShuttle.speed = positionDictionary["speed"]!.floatValue
                        newShuttle.shuttleType = ShuttleType(rawValue: vehicleDictionary["type"]!.integerValue)!
                        newShuttle.statusMessage = positionDictionary["public_status_msg"] as String
                        
                        let dateFormatter = NSDateFormatter()
                        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
                        dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                        newShuttle.updateTime = dateFormatter.dateFromString(positionDictionary["timestamp"] as String)
                        
                        shuttlesReceivedMap.setValue(newShuttle, forKey: newShuttle.identifier!)
                    }
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(
                        kShuttleStatusesUpdatedNotification,
                        object: nil,
                        userInfo: ["shuttles" : shuttlesReceivedMap]
                    )
                }
        }
    }
}
