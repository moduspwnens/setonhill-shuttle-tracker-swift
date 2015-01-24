//
//  NSNotificationCenter+RemoteConfiguration.swift
//  Shuttle Tracker (Swift)
//
//  Helper class for using notifications specifically for when remote configuration variables are updated.
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

let remoteConfigurationNotificationPrefix = "RemoteConfigUpdated-"

extension NSNotificationCenter {
    
    func postRemoteConfigurationUpdateNotificationName(configurationVariableName: String,
                                                object notificationSender: AnyObject?,
                                                       userInfo: [NSObject : AnyObject]?) {
        self.postNotificationName("\(remoteConfigurationNotificationPrefix)\(configurationVariableName)", object: notificationSender, userInfo: userInfo)
    }
    
    func addObserverForRemoteConfigurationNotificationName(configurationVariableName: String?,
                                                           object obj: AnyObject?,
                                                           queue: NSOperationQueue?,
                                                           usingBlock block: (NSNotification!) -> Void) -> NSObjectProtocol {
        return self.addObserverForName("\(remoteConfigurationNotificationPrefix)\(configurationVariableName!)", object: obj, queue: queue, usingBlock: block)
    }
    
    func addObserverForRemoteConfigurationUpdate(notificationObserver: AnyObject,
                                                selector notificationSelector: Selector,
                                                name configurationVariableName: String?,
                                                object notificationSender: AnyObject?) {
        return self.addObserver(notificationObserver, selector: notificationSelector, name: "\(remoteConfigurationNotificationPrefix)\(configurationVariableName!)", object: notificationSender)
    }
}
