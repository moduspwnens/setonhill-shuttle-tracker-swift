//
//  STAppDelegate.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/18/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit
import Alamofire

@UIApplicationMain
class STAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let remoteConfigurationManager: STRemoteConfigurationManager = STRemoteConfigurationManager()
    let shuttleDataManager: STShuttleDataManager = STShuttleDataManager()
    var networkingCount = 0
    var shuttleStatusUpdateTimer: NSTimer?
    

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Load base defaults (in case they haven't been set already).
        self.remoteConfigurationManager.loadBaseDefaults()
        
        // Listen for notification and act appropriately if the remotely-specified ShuttleDataRefreshInterval variable changes.
        NSNotificationCenter.defaultCenter()
            .addObserverForRemoteConfigurationNotificationName(
                "ShuttleDataRefreshInterval",
                object: nil,
                queue: NSOperationQueue.mainQueue(),
                usingBlock:
                { _ in
                    self.beginShuttleStatusUpdates(false)
                }
        )
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        
    }

    func applicationDidEnterBackground(application: UIApplication) {
        self.shuttleStatusUpdateTimer?.invalidate()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Check to see if any remotely settable configuration variables have changed.
        self.remoteConfigurationManager.updateRemoteDefaults()
        
        // Start loading shuttle locations/statuses.
        self.beginShuttleStatusUpdates(true)
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func beginShuttleStatusUpdates(immediately: Bool) {
        // Invalidate existing timer if it's already set.
        self.shuttleStatusUpdateTimer?.invalidate()
        
        // Get update interval from user defaults.
        let updateInterval : NSTimeInterval = NSUserDefaults.standardUserDefaults().doubleForKey("ShuttleDataRefreshInterval")
        
        self.shuttleStatusUpdateTimer = NSTimer.scheduledTimerWithTimeInterval(updateInterval, target: self.shuttleDataManager, selector: "updateData", userInfo: nil, repeats: true)
        
        if immediately {
            self.shuttleStatusUpdateTimer?.fire()
        }
    }
    
    func updateNetworkActivityIndicator() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = (self.networkingCount > 0)
    }
    
    class func didStartNetworking() {
        dispatch_async(dispatch_get_main_queue(),{
            let appDelegate = UIApplication.sharedApplication().delegate as STAppDelegate
            appDelegate.networkingCount++
            appDelegate.updateNetworkActivityIndicator()
        })
        
    }

    class func didStopNetworking() {
        dispatch_async(dispatch_get_main_queue(),{
            let appDelegate = UIApplication.sharedApplication().delegate as STAppDelegate
            appDelegate.networkingCount--
            appDelegate.updateNetworkActivityIndicator()
        })
    }
}

