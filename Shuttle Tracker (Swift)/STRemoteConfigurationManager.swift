//
//  STRemoteConfigurationManager.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit
import Alamofire

class STRemoteConfigurationManager: NSObject {
    
    func loadBaseDefaults() {
        /*
            The base defaults are kind of the "default defaults."
            By loading these if they don't exist early on, I can assume they'll be set at all times in other parts of the code.
        */
        
        let baseDefaultsPath = NSBundle.mainBundle().pathForResource("BaseDefaults", ofType: "plist")
        let baseDefaultsDictionary = NSDictionary(contentsOfFile: baseDefaultsPath!)
        let standardDefaults = NSUserDefaults.standardUserDefaults()
        
        // Set any values to the base defaults that haven't been set before.
        for (eachKey, eachValue) in baseDefaultsDictionary! as [String: AnyObject] {
            if standardDefaults.objectForKey(eachKey) == nil {
                standardDefaults.setObject(eachValue, forKey: eachKey)
            }
        }
    }
    
    func updateRemoteDefaults() {
        
        // Grab the URL from which we should be accessing remote config variables.
        let requestURLString = NSUserDefaults.standardUserDefaults().objectForKey("AppConfigRemoteURL") as String
        
        
        let requestParameters = [
            // Include the app's version and its UUID, so we can modify configuration remotely based on those things, if necessary.
            "version" : NSBundle.mainBundle().infoDictionary?["CFBundleVersion"]! as String,
            "uuid" : UIDevice.currentDevice().identifierForVendor.UUIDString,
            
            // Include the app's selected localization, in case we want to make any changes to the configuration remotely because of it.
            "locale" : NSBundle.mainBundle().preferredLocalizations[0] as String
        ]
        
        //println("Updating remote defaults from \(requestURLString) with parameters: \(requestParameters)")
        
        STAppDelegate.didStartNetworking()
        
        Alamofire.request(.GET, requestURLString, parameters: requestParameters)
            .responseJSON { (request, response, JSON, error) in
                
                STAppDelegate.didStopNetworking()
                
                if error != nil || JSON == nil {
                    println("Unable to update remote configuration. An error occurred while contacting server.")
                    
                    // I don't have it alerting the user or anything because this is just the remote config. This method will be called again when they re-open the app, and unless there were big changes in the config, the app should still "just work."
                }
                else {
                    // Received valid JSON response! Let's get the values out, save them to the defaults, and send notifications that they've been updated.
                    
                    // Let's keep a counter so that we can log how many were changed.
                    var defaultsUpdated = 0
                    
                    for (eachKey, newValue) in JSON! as [String: AnyObject] {
                        let oldValueWrapper : AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey(eachKey)
                        
                        if oldValueWrapper == nil {
                            // There is no value already set for this default, which means it wasn't in the base defaults. If it's not in the base defaults, there's no logic for doing anything with it, so it can be safely ignored.
                            continue
                        }
                        
                        // At this point, we may as well unwrap it since we know it's not nil.
                        let oldValue : AnyObject = oldValueWrapper!
                        
                        // Let's keep track of whether or not it was updated. If it's the same, then we don't need to do anything.
                        var valueWasUpdated = false
                        
                        // Use datatype-specific equality comparisons.
                        if oldValue is NSNumber && newValue is NSNumber {
                            valueWasUpdated = !( oldValue.isEqualToNumber(newValue as NSNumber) )
                        }
                        else if oldValue is String && newValue is String {
                            valueWasUpdated = !( oldValue.isEqualToString(newValue as String) )
                        }
                        else if oldValue is NSArray && newValue is NSArray {
                            valueWasUpdated = !( oldValue.isEqualToArray(newValue as NSArray) )
                        }
                        else if oldValue is NSDictionary && newValue is NSDictionary {
                            valueWasUpdated = !( oldValue.isEqualToDictionary(newValue as NSDictionary) )
                        }
                        else {
                            // The datatypes between the old and new value don't match. We should skip processing this because if code elsewhere is expecting, say, an array, and it finds a string, it will likely cause a crash.
                            print("Data type mismatch, or unknown data type for \(eachKey) : \(oldValue) : \(newValue)")
                            continue
                        }
                        
                        if (valueWasUpdated) {
                            
                            // The value changed, so update the defaults.
                            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: eachKey)
                            
                            // Update our counter.
                            defaultsUpdated++
                            
                            // Send along the key name, old value, and new value so the receiving function can determine what exactly changed (if necessary).
                            var notificationInfo : [NSObject : AnyObject]! = [
                                "key" : eachKey,
                                "oldValue" : oldValue,
                                "newValue" : newValue
                            ]
                            
                            // Send the notification.
                            NSNotificationCenter.defaultCenter()
                                .postRemoteConfigurationUpdateNotificationName(
                                    eachKey,
                                    object:self,
                                    userInfo:notificationInfo
                            )
                            
                        }
                    }
                    
                    //println("Remote defaults updated (\(defaultsUpdated) changed).")
                }
        }
    }
    
}
