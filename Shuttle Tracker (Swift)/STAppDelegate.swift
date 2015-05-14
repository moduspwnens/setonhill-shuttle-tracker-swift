//
//  STAppDelegate.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/18/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit
import Alamofire
import Reachability

let kAppEnteredBackgroundNotification = "kAppEnteredBackgroundNotification"
let kAppWillEnterForegroundNotification = "kAppWillEnterForegroundNotification"

@UIApplicationMain
class STAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let remoteConfigurationManager = STRemoteConfigurationManager()
    private let shuttleDataManager = STShuttleDataManager()
    private var networkingCount = 0
    private var shuttleStatusUpdateTimer: NSTimer?
    private var internetReachability = Reachability.reachabilityForInternetConnection()
    private var internetWasUnreachable = false

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Load base defaults (in case they haven't been set already).
        self.remoteConfigurationManager.loadBaseDefaults()
        
        // Set up listener for ShuttleDataRefreshInterval variable changes.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "shuttleDataRefreshIntervalChanged:",
            name: "ShuttleDataRefreshInterval",
            object: nil
        )
        
        // Set up listener for Internet reachability.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "reachabilityStatusChanged:",
            name: kReachabilityChangedNotification,
            object: nil
        )
        
        // Start Internet reachability notifier.
        self.internetReachability.startNotifier()
        
        // Check if we're starting out with no Internet.
        self.internetWasUnreachable = self.internetReachability.currentReachabilityStatus() == NetworkStatus.NotReachable
        
        // Check to see if any remotely settable configuration variables have changed.
        self.remoteConfigurationManager.updateRemoteDefaults()
        
        // Start loading shuttle locations/statuses.
        self.beginShuttleStatusUpdates(true)
        
        // Disable idle timer. We can expect some users to watch this for a while without touching.
        UIApplication.sharedApplication().idleTimerDisabled = true
        
        return true
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Stop loading shuttle locations/statuses.
        self.shuttleStatusUpdateTimer?.invalidate()
        
        // Post notification to other objects.
        NSNotificationCenter.defaultCenter().postNotificationName(kAppEnteredBackgroundNotification, object: self)
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Check to see if any remotely settable configuration variables have changed.
        self.remoteConfigurationManager.updateRemoteDefaults()
        
        // Start loading shuttle locations/statuses.
        self.beginShuttleStatusUpdates(true)
        
        // Post notification to other objects.
        NSNotificationCenter.defaultCenter().postNotificationName(kAppWillEnterForegroundNotification, object: self)
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func beginShuttleStatusUpdates(immediately: Bool) {
        
        // Invalidate existing timer if it's already set.
        self.shuttleStatusUpdateTimer?.invalidate()
        
        // Get update interval from user defaults.
        let updateInterval : NSTimeInterval = NSUserDefaults.standardUserDefaults().doubleForKey("ShuttleDataRefreshInterval")
        
        // Create timer, set to repeat.
        self.shuttleStatusUpdateTimer = NSTimer.scheduledTimerWithTimeInterval(
            updateInterval,
            target: self.shuttleDataManager,
            selector: "updateData",
            userInfo: nil,
            repeats: true
        )
        
        if immediately {
            self.shuttleStatusUpdateTimer?.fire()
        }
    }
    
    // MARK: - Other event handlers
    func reachabilityStatusChanged(notification: NSNotification) {
        let currentNetworkStatus = (notification.object as! Reachability).currentReachabilityStatus()
        if currentNetworkStatus != NetworkStatus.NotReachable && self.internetWasUnreachable {
            // The Internet just became available after previously being off. Immediately check for new shuttle status updates.
            self.shuttleStatusUpdateTimer?.fire()
            self.internetWasUnreachable = false
        }
        else if currentNetworkStatus == NetworkStatus.NotReachable {
            // The Internet just became unavailable after previously being on.
            self.internetWasUnreachable = true
        }
    }
    
    func shuttleDataRefreshIntervalChanged(notification: NSNotification) {
        // Start the shuttle status updates again. This will create reset the timer with the new refresh interval.
        self.beginShuttleStatusUpdates(false)
    }
    
    // MARK: - Shared network activity indicator handler methods
    
    func updateNetworkActivityIndicator() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = (self.networkingCount > 0)
    }
    
    class func didStartNetworking() {
        dispatch_async(dispatch_get_main_queue(),{
            let appDelegate = UIApplication.sharedApplication().delegate as! STAppDelegate
            appDelegate.networkingCount++
            appDelegate.updateNetworkActivityIndicator()
        })
        
    }

    class func didStopNetworking() {
        dispatch_async(dispatch_get_main_queue(),{
            let appDelegate = UIApplication.sharedApplication().delegate as! STAppDelegate
            appDelegate.networkingCount--
            appDelegate.updateNetworkActivityIndicator()
        })
    }
}

