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
let kShuttleStatusUpdateErrorOccurredNotification = "kShuttleStatusUpdateErrorOccurred"
let kShuttleStatusChangedNotification = "kShuttleStatusChanged"

enum ShuttleStatusChangeType: NSInteger {
    case Updated = 0
    case Added = 1
    case Removed = 2
}

class STShuttleDataManager: NSObject {
    
    private var alamofireManager : Alamofire.Manager?
    private var shuttleDictionary = NSMutableDictionary()
    
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
                    
                    // Keep track of the ones we've found, so we can tell if any have been removed.
                    var shuttleIdentifiersFound = NSMutableArray()
                    
                    for eachItem in JSON as NSArray {
                        let vehicleDictionary = (eachItem as NSDictionary)["vehicle"] as NSDictionary
                        
                        // Create a new STShuttle object and populate its properties with what we've received in the JSON.
                        var newShuttle = STShuttle()
                        newShuttle.identifier = vehicleDictionary["id"] as String
                        newShuttle.title = vehicleDictionary["name"] as String
                        newShuttle.subtitle = vehicleDictionary["subtitle"] as String
                        
                        let positionDictionary = vehicleDictionary["latest_position"] as NSDictionary
                        newShuttle.latitude = positionDictionary["latitude"]!.doubleValue
                        newShuttle.longitude = positionDictionary["longitude"]!.doubleValue
                        newShuttle.heading = positionDictionary["heading"]!.floatValue
                        newShuttle.speed = positionDictionary["speed"]!.floatValue
                        newShuttle.shuttleType = ShuttleType(rawValue: vehicleDictionary["type"]!.integerValue)!
                        newShuttle.statusMessage = positionDictionary["public_status_msg"] as String
                        
                        let dateFormatter = NSDateFormatter()
                        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
                        dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                        let updateTime = dateFormatter.dateFromString(positionDictionary["timestamp"] as String)!
                        
                        let newShuttleStatusInstance = STShuttleStatusInstance(shuttle: newShuttle, updateTime: updateTime)
                        
                        // Add this shuttle's identifier to the list of identifiers we've found.
                        shuttleIdentifiersFound.addObject(newShuttle.identifier!)
                        
                        if let existingShuttleStatusInstance = self.shuttleDictionary.objectForKey(newShuttle.identifier!) as? STShuttleStatusInstance {
                            // This shuttle exists locally, so it's probably already on the map.
                            
                            if existingShuttleStatusInstance.shuttle != newShuttle {
                                // This shuttle is different from when we last saw it.
                                
                                // Update our local cache of shuttles.
                                self.shuttleDictionary.setObject(newShuttleStatusInstance, forKey: newShuttle.identifier!)
                                
                                // Post a "shuttle updated" notification.
                                NSNotificationCenter.defaultCenter().postNotificationName(
                                    kShuttleStatusChangedNotification,
                                    object: nil,
                                    userInfo: [
                                        "shuttleStatus" : newShuttleStatusInstance,
                                        "type" : NSNumber(integer: ShuttleStatusChangeType.Updated.rawValue)
                                    ]
                                )
                            }
                            else {
                                // Update our local cache of shuttles anyway. The latest version will have the correct "last updated" time.
                                self.shuttleDictionary.setObject(newShuttleStatusInstance, forKey: newShuttle.identifier!)
                            }
                        }
                        else {
                            // This shuttle doesn't exist locally, so it's the first time we've seen it.
                            
                            // Add it to our local cache of shuttles.
                            self.shuttleDictionary.setObject(newShuttleStatusInstance, forKey: newShuttle.identifier!)
                            
                            // Post a "shuttle added" notification.
                            NSNotificationCenter.defaultCenter().postNotificationName(
                                kShuttleStatusChangedNotification,
                                object: nil,
                                userInfo: [
                                    "shuttleStatus" : newShuttleStatusInstance,
                                    "type" : NSNumber(integer: ShuttleStatusChangeType.Added.rawValue)
                                ]
                            )
                        }
                    }
                    
                    // Now let's see if any shuttles were removed (i.e. we have them cached locally, but they weren't in the latest valid response).
                    
                    let existingShuttleIdentifiers = self.shuttleDictionary.allKeys
                    for eachKey in existingShuttleIdentifiers {
                        if !shuttleIdentifiersFound.containsObject(eachKey) {
                            // This shuttle has been removed.
                            
                            let oldShuttleStatusInstance = self.shuttleDictionary.objectForKey(eachKey) as STShuttleStatusInstance
                            
                            // Remove from our local cache of shuttles.
                            self.shuttleDictionary.removeObjectForKey(eachKey)
                            
                            // Post a "shuttle removed" notification.
                            NSNotificationCenter.defaultCenter().postNotificationName(
                                kShuttleStatusChangedNotification,
                                object: nil,
                                userInfo: [
                                    "shuttleStatus" : oldShuttleStatusInstance,
                                    "type" : NSNumber(integer: ShuttleStatusChangeType.Removed.rawValue)
                                ]
                            )
                        }
                    }
                }
        }
    }
}
