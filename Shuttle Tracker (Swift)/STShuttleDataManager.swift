//
//  STShuttleDataManager.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import Alamofire
import MapKit

let maxAllowableConsecutiveStatusUpdateFailures = 2

// NSNotification names
let kShuttleStatusUpdateErrorOccurredNotification = "kShuttleStatusUpdateErrorOccurred"
let kShuttleStatusUpdateReceivedNotification = "kShuttleStatusUpdateReceived"


enum ShuttleStatusChangeType: NSInteger {
    case Updated = 0,
    Added,
    Removed,
    Unchanged
}

class STShuttleDataManager: NSObject {
    
    private var alamofireManager : Alamofire.Manager?
    private var shuttleDictionary = NSMutableDictionary()
    
    override init() {
        super.init()
        self.setupAlamofireManager()
        
        // Listen for notification and act appropriately if the remotely-specified ShuttleDataRefreshInterval variable changes.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "shuttleDataRefreshIntervalChanged:",
            name: "ShuttleDataRefreshInterval",
            object: nil
        )
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
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
                
                // There are several reasons a response might not be valid. Let's set a flag and then if it's still "false" at the end, we'll post a notification that an error occurred.
                var validResponseConfirmed = false
                
                if let error = error {
                    println("An error occurred while fetching shuttle data.")
                }
                else if let JSON: AnyObject = JSON {
                    // Received valid JSON response!
                    
                    if let JSON : NSArray = JSON as? NSArray {
                        
                        // We've got a valid array. It's totally valid to have an empty array, so let's assume the response is valid from here on unless a shuttle's entry is invalid.
                        validResponseConfirmed = true
                        
                        // Keep track of the ones we've found, so we can tell if any have been removed.
                        var shuttleIdentifiersFound = NSMutableArray()
                        
                        var shuttlesToAdd : [STShuttle] = []
                        var shuttlesToUpdate : [STShuttle] = []
                        var shuttlesToRemove : [STShuttle] = []
                        var shuttlesToIgnore : [STShuttle] = []
                        
                        for eachItem in JSON {
                            
                            if let vehicleDictionary = eachItem["vehicle"]? as? NSDictionary {
                                
                                // Create a new STShuttle object and populate its properties with what we've received in the JSON.
                                var newShuttle = STShuttle()
                                
                                if let newIdentifier = vehicleDictionary["id"]? as? String {
                                    newShuttle.identifier = newIdentifier
                                }
                                else {
                                    println("Invalid id for shuttle. Skipping.")
                                    continue
                                }
                                
                                if let newTitle = vehicleDictionary["name"]? as? String {
                                    newShuttle.title = newTitle
                                }
                                else {
                                    println("Invalid title for shuttle. Skipping.")
                                    continue
                                }
                                
                                // Subtitles are optional, so no need to complain if it's missing or invalid.
                                newShuttle.subtitle = vehicleDictionary["subtitle"]? as? String
                                
                                if let newShuttleTypeNumber = vehicleDictionary["type"]? as? NSNumber {
                                    if let newShuttleType = ShuttleType(rawValue: newShuttleTypeNumber.integerValue) {
                                        newShuttle.shuttleType = newShuttleType
                                    }
                                    else {
                                        println("Invalid shuttle type. Should be a valid enum integer. Skipping.")
                                        continue
                                    }
                                }
                                else {
                                    println("Invalid shuttle type. Should be a number. Skipping.")
                                    continue
                                }
                                
                                
                                var updateTime : NSDate
                                
                                if let positionDictionary = vehicleDictionary["latest_position"]? as? NSDictionary {
                                    
                                    if let newLatitude = positionDictionary["latitude"]? as? NSNumber {
                                        newShuttle.latitude = newLatitude.doubleValue
                                    }
                                    else {
                                        println("Invalid latitude. Should be a number. Skipping.")
                                    }
                                    
                                    if let newLongitude = positionDictionary["longitude"]? as? NSNumber {
                                        newShuttle.longitude = newLongitude.doubleValue
                                    }
                                    else {
                                        println("Invalid longitude. Should be a number. Skipping.")
                                    }
                                    
                                    if let newHeading = positionDictionary["heading"]? as? NSNumber {
                                        newShuttle.heading = newHeading.floatValue
                                    }
                                    else {
                                        println("Invalid heading. Should be a number. Skipping.")
                                    }
                                    
                                    if let newSpeed = positionDictionary["speed"]? as? NSNumber {
                                        newShuttle.speed = newSpeed.floatValue
                                    }
                                    else {
                                        println("Invalid speed. Should be a number. Skipping.")
                                    }
                                    
                                    // Another totally optional string.
                                    newShuttle.statusMessage = positionDictionary["public_status_msg"]? as? String
                                    
                                    let dateFormatter = NSDateFormatter()
                                    dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
                                    dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                                    
                                    if let newTimestampString = positionDictionary["timestamp"]? as? String {
                                        if let newUpdateTime = dateFormatter.dateFromString(newTimestampString) {
                                            updateTime = newUpdateTime
                                        }
                                        else {
                                            println("Invalid timestamp. Unable to parse. Skipping.")
                                            continue
                                        }
                                    }
                                    else {
                                        println("Invalid timestamp. Should be a string in the specified format. Skipping.")
                                        continue
                                    }
                                    
                                }
                                else {
                                    println("Invalid or no position specification. Skipping.")
                                    continue
                                }
                                
                                
                                let newShuttleStatusInstance = STShuttleStatusInstance(shuttle: newShuttle, updateTime: updateTime)
                                
                                
                                // Add this shuttle's identifier to the list of identifiers we've found.
                                shuttleIdentifiersFound.addObject(newShuttle.identifier!)
                                
                                if let existingShuttleStatusInstance = self.shuttleDictionary.objectForKey(newShuttle.identifier!) as? STShuttleStatusInstance {
                                    // This shuttle exists locally, so it's probably already on the map.
                                    
                                    if existingShuttleStatusInstance.shuttle != newShuttle {
                                        // This shuttle is different from when we last saw it.
                                        
                                        // Update our local cache of shuttles.
                                        self.shuttleDictionary.setObject(newShuttleStatusInstance, forKey: newShuttle.identifier!)
                                        
                                        // Add to array of shuttles to update.
                                        shuttlesToUpdate.append(newShuttle)
                                    }
                                    else {
                                        // Update our local cache of shuttles anyway. The latest version will have the correct "last updated" time.
                                        self.shuttleDictionary.setObject(newShuttleStatusInstance, forKey: newShuttle.identifier!)
                                        
                                        // Add to array of shuttles to ignore.
                                        shuttlesToIgnore.append(newShuttle)
                                    }
                                }
                                else {
                                    // This shuttle doesn't exist locally, so it's the first time we've seen it.
                                    
                                    // Add it to our local cache of shuttles.
                                    self.shuttleDictionary.setObject(newShuttleStatusInstance, forKey: newShuttle.identifier!)
                                    
                                    // Add to array of shuttles to add.
                                    shuttlesToAdd.append(newShuttle)
                                }
                            }
                            else {
                                println("Object in shuttle array doesn't contain 'vehicle' key pointing to an NSDictionary. \(eachItem)")
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
                                
                                // Add to array of shuttles to delete.
                                shuttlesToRemove.append(oldShuttleStatusInstance.shuttle)
                                
                            }
                        }
                        
                        // Post a notification containing all the shuttles with their change statuses.
                        NSNotificationCenter.defaultCenter().postNotificationName(
                            kShuttleStatusUpdateReceivedNotification,
                            object: nil,
                            userInfo: [
                                NSNumber(integer: ShuttleStatusChangeType.Added.rawValue) : shuttlesToAdd,
                                NSNumber(integer: ShuttleStatusChangeType.Updated.rawValue) : shuttlesToUpdate,
                                NSNumber(integer: ShuttleStatusChangeType.Removed.rawValue) : shuttlesToRemove,
                                NSNumber(integer: ShuttleStatusChangeType.Unchanged.rawValue) : shuttlesToIgnore
                            ]
                        )
                    }
                    else {
                        println("JSON response not of type: NSArray.")
                    }
                    
                }
                else {
                    println("No error, but JSON response object is nil.")
                }
                
                if !validResponseConfirmed {
                    NSNotificationCenter.defaultCenter().postNotificationName(
                        kShuttleStatusUpdateErrorOccurredNotification,
                        object: nil,
                        userInfo: ["message" : NSLocalizedString("Data retrieval error", comment:"")]
                    )
                }
        }
    }
    
    // MARK: - Direct notification handling
    
    func shuttleDataRefreshIntervalChanged(notification: NSNotification) {
        // Create a new Alamofire manager with the latest update interval.
        self.setupAlamofireManager()
    }
}
