//
//  STAppDelegate.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/18/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit

@UIApplicationMain
class STAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var remoteConfigurationManager: STRemoteConfigurationManager = STRemoteConfigurationManager()


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        
        // Load base defaults (in case they haven't been set already).
        self.remoteConfigurationManager.loadBaseDefaults()
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Check to see if any remotely settable configuration variables have changed.
        self.remoteConfigurationManager.updateRemoteDefaults()
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

