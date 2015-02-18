//
//  STPolygonRenderer.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 2/11/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

let parkingLotColor = UIColor(white: 200/255.0, alpha: 1)
let buildingColor = UIColor(red: 197/255.0, green: 30/255.0, blue: 58/255.0, alpha: 1)

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
            self.fillColor = parkingLotColor
        }
        else if self.overlaySpecType == .Building {
            self.fillColor = buildingColor
        }
    }
    
}
