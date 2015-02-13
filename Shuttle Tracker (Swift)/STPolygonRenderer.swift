//
//  STPolygonRenderer.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 2/11/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

class STPolygonRenderer: MKPolygonRenderer {
    
    var overlaySpecType : OverlaySpecificationType = .ParkingLot
   
    override init!(overlay: MKOverlay!) {
        super.init(overlay: overlay)
        self.performDefaultInitialization()
    }
    
    override init!(polygon: MKPolygon!) {
        super.init(polygon: polygon)
        self.performDefaultInitialization()
    }
    
    init(customPolygon: STPolygon) {
        super.init(polygon: customPolygon)
        
        // Save overlay spec type in instance variable.
        self.overlaySpecType = customPolygon.overlaySpecType
        
        self.performDefaultInitialization()
    }
    
    func performDefaultInitialization() {
        
        if self.overlaySpecType == .ParkingLot {
            self.fillColor = UIColor.grayColor()
            self.strokeColor = UIColor.whiteColor()
            self.lineWidth = 2
        }
    }
    
}
