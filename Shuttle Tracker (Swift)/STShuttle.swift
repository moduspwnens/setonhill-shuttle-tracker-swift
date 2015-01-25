//
//  STShuttle.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/24/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

enum ShuttleType: NSInteger {
    case Normal = 0
    case Employee = 1
    case Other = 2
}

class STShuttle: NSObject, MKAnnotation {
    var identifier : NSString?
    var title : NSString?
    var subtitle : NSString?
    var statusMessage : NSString?
    var updateTime : NSDate?
    var heading : Float = -1
    var speed : Float = 0
    var latitude : CLLocationDegrees = 0
    var longitude : CLLocationDegrees = 0
    var shuttleTypeAsNumber : NSNumber = NSNumber(integer: ShuttleType.Normal.rawValue)
    
    // Default initializer. It's OK to create an empty shuttle and fill in its properties later.
    override init() {
        super.init()
    }
    
    // Dictionary initializer for easy creation from JSON response.
    init(dictionary: NSDictionary) {
        super.init()
        self.setValuesForKeysWithDictionary(dictionary)
    }
    
    // Dictionary representation for easy comparison.
    func dictionaryRepresentation() -> NSDictionary {
        let m = reflect(self)
        var s = [String]()
        for i in 0..<m.count
        {
            let (name,_)  = m[i]
            if name == "super"{continue}
            s.append(name)
        }
        return self.dictionaryWithValuesForKeys(s)
    }
    
    // Custom isEqual method allows for easily checking whether or not there are changes between two shuttles.
    func isEqualToShuttle(otherShuttle: STShuttle) -> Bool {
        return self.dictionaryRepresentation().isEqualToDictionary(otherShuttle.dictionaryRepresentation())
    }
    
    // Using computed property with behind-the-scenes storage as NSNumber so that dictionary representation/comparison will work.
    var shuttleType:ShuttleType {
        set {
            self.shuttleTypeAsNumber = NSNumber(integer: newValue.rawValue)
        }
        get {
            return ShuttleType(rawValue: self.shuttleTypeAsNumber.integerValue)!
        }
    }
    
    // Using computed property with behind-the-scenes storage as NSNumbers so that we're not storing the same CLLocationCoordinate2D.
    var coordinate:CLLocationCoordinate2D {
        set {
            self.latitude = newValue.latitude
            self.longitude = newValue.longitude
        }
        get {
            return CLLocationCoordinate2DMake(self.latitude, self.longitude)
        }
    }
}
