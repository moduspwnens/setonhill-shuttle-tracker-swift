//
//  STShuttle.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

enum ShuttleType: NSInteger {
    case Red = 0
    case Yellow = 1
    case Green = 2
}

class STShuttleStatusInstance: NSObject {
    var shuttle : STShuttle
    var updateTime : NSDate
    
    init(shuttle: STShuttle, updateTime: NSDate) {
        self.shuttle = shuttle
        self.updateTime = updateTime
        super.init()
    }
}

// Override "==" operator to allow for accurate direct comparison of STShuttle objects.
func ==(lhs: STShuttle, rhs: STShuttle) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class STShuttle: NSObject, MKAnnotation, Hashable {
    var identifier : NSString?
    dynamic var title : NSString?
    dynamic var subtitle : NSString?
    var statusMessage : NSString?
    var heading : Float = -1
    var speed : Float = 0
    var latitude : CLLocationDegrees = 0
    var longitude : CLLocationDegrees = 0
    var shuttleType = ShuttleType.Red
    
    // Default initializer. It's OK to create an empty shuttle and fill in its properties later.
    override init() {
        super.init()
    }
    
    // Implementing to make sure class implements Hashable, which allows it to implement Equatable. This will allow us to directly compare STShuttles with the == operator.
    override var hashValue : Int {
        get {
            return "\(self.identifier)-\(self.title)-\(self.subtitle)-\(self.statusMessage)-\(self.heading)-\(self.speed)-\(self.latitude)-\(self.longitude)-\(self.shuttleType)".hashValue
        }
    }
    
    // Using computed property with behind-the-scenes storage as NSNumbers so that we're not storing the same CLLocationCoordinate2D.
    dynamic var coordinate:CLLocationCoordinate2D {
        set {
            self.latitude = newValue.latitude
            self.longitude = newValue.longitude
        }
        get {
            return CLLocationCoordinate2DMake(self.latitude, self.longitude)
        }
    }
    
    // Function for retrieving image names (found in Images.xcassets) based on shuttle type ID (integer received from server).
    func getBlipImageName() -> String {
        switch self.shuttleType {
        case .Red:
            return "RedBlip"
        case .Yellow:
            return "YellowBlip"
        case .Green:
            return "GreenBlip"
        }
    }
}
