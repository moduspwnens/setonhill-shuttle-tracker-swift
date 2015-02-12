//
//  STPolygon.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 2/11/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

enum PolygonOverlayType: NSInteger {
    case ParkingLot = 0
    case Building = 1
}

class STPolygon: MKPolygon {
    var overlayType : PolygonOverlayType = .ParkingLot
}
