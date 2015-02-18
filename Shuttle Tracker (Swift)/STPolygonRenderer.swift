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
        
        // Buildings and parking lots won't have outlines.
        self.strokeColor = UIColor.clearColor()
        self.lineWidth = 0
        
        if self.overlaySpecType == .ParkingLot {
            self.fillColor = UIColor(rgba: NSUserDefaults.standardUserDefaults().stringForKey("ParkingLotOverlayMainColor")!)
        }
        else if self.overlaySpecType == .Building {
            self.fillColor = UIColor(rgba: NSUserDefaults.standardUserDefaults().stringForKey("BuildingOverlayMainColor")!)
        }
    }
    
}
