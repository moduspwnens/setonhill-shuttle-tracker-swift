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
    var annotationView : MKAnnotationView?
    var heading : Float = -1
    var speed : Float = 0
    var coordinate : CLLocationCoordinate2D = CLLocationCoordinate2DMake(0,0)
    var shuttleType : ShuttleType = .Normal
}
