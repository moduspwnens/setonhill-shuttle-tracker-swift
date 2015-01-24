//
//  STRemoteConfigurationManager.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit

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
        for (eachKey, eachValue) in baseDefaultsDictionary! {
            if standardDefaults.objectForKey(eachKey as String) == nil {
                standardDefaults.setObject(eachValue, forKey: eachKey as String)
            }
        }
    }
    
    func updateRemoteDefaults() {
        println("Updating remote defaults...")
    }
    
}
