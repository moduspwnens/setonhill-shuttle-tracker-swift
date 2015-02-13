//
//  STPolylineRenderer.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 2/11/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

class STPolylineRenderer: MKPolylineRenderer {
    
    var overlaySpecType : OverlaySpecificationType = .ParkingLot
    
    override init!(overlay: MKOverlay!) {
        super.init(overlay: overlay)
        self.performDefaultInitialization()
    }
    
    override init!(polyline: MKPolyline!) {
        super.init(polyline: polyline)
        self.performDefaultInitialization()
    }
    
    init(customPolyline: STPolyline) {
        super.init(polyline: customPolyline)
        
        // Save overlay spec type in instance variable.
        self.overlaySpecType = customPolyline.overlaySpecType
        
        self.performDefaultInitialization()
    }
    
    func performDefaultInitialization() {
        switch self.overlaySpecType {
        case .Road:
            self.strokeColor = UIColor.whiteColor()
        default:
            "" // Do nothing.
        }
    }
    
    override func applyStrokePropertiesToContext(context: CGContext!, atZoomScale zoomScale: MKZoomScale) {
        super.applyStrokePropertiesToContext(context, atZoomScale: zoomScale)
        
        if self.overlaySpecType == .Road {
            // These will be smaller roads, so let's make the lines a fraction of the road width at this scale.
            let lineWidth = MKRoadWidthAtZoomScale(zoomScale) * 0.6
            CGContextSetLineWidth(context, lineWidth)
        }
    }
}
