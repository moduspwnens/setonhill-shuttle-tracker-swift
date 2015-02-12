//
//  STRoadPolylineRenderer.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 2/11/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

class STRoadPolylineRenderer: MKPolylineRenderer {
    
    override init!(overlay: MKOverlay!) {
        super.init(overlay: overlay)
        self.performDefaultInitialization()
    }
    
    override init!(polyline: MKPolyline!) {
        super.init(polyline: polyline)
        self.performDefaultInitialization()
    }
    
    func performDefaultInitialization() {
        self.strokeColor = UIColor.whiteColor()
    }
    
    override func applyStrokePropertiesToContext(context: CGContext!, atZoomScale zoomScale: MKZoomScale) {
        super.applyStrokePropertiesToContext(context, atZoomScale: zoomScale)
        
        // These will be smaller roads, so let's make the lines a fraction of the road width at this scale.
        let lineWidth = MKRoadWidthAtZoomScale(zoomScale) * 0.6
        CGContextSetLineWidth(context, lineWidth)
    }
}