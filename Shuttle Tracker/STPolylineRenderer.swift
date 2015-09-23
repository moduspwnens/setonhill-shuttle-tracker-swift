//
//  STPolylineRenderer.swift
//  Shuttle Tracker
//
//  Created by Benn Linger on 2/11/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

class STPolylineRenderer: MKPolylineRenderer {
    
    var overlaySpecType : OverlaySpecificationType = .ParkingLot
    
    override init(overlay: MKOverlay) {
        super.init(overlay: overlay)
        self.performDefaultInitialization()
    }
    
    override init(polyline: MKPolyline) {
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
            self.strokeColor = UIColor(rgba: NSUserDefaults.standardUserDefaults().stringForKey("RoadOverlayMainColor")!)
            self.lineCap = CGLineCap.Butt
        default:
            "" // Do nothing.
        }
    }
    
    override func applyStrokePropertiesToContext(context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        super.applyStrokePropertiesToContext(context, atZoomScale: zoomScale)
        
        if self.overlaySpecType == .Road {
            
            // First, let's decide how wide the line should be based on how far the map is zoomed in.
            var baseWidth : CGFloat = 0
            
            if zoomScale < 0.03125 {
                // We're zoomed out pretty far.
                baseWidth = 0
            }
            else if zoomScale <= 0.0625 {
                // We're zoomed out a little. MKRoadWidthAtZoomScale will return the size of a bigger road, so we need to adjust it to be smaller.
                baseWidth = MKRoadWidthAtZoomScale(zoomScale) * 0.4
            }
            else {
                // We're zoomed in pretty close. Base our width off of the default road width, but not the full size.
                baseWidth = MKRoadWidthAtZoomScale(zoomScale) * 0.8
            }
            
            /*
                Method adapted from:
                http://adrian.schoenig.me/blog/2013/02/21/drawing-multi-coloured-lines-on-an-mkmapview/
            */
            
            // Draw the first (thicker) line, which will be the color of the outline.
            CGContextAddPath(context, self.path);
            CGContextSetStrokeColorWithColor(context, UIColor(rgba: NSUserDefaults.standardUserDefaults().stringForKey("RoadOverlayOutlineColor")!).CGColor);
            CGContextSetLineWidth(context, baseWidth * 1.5);
            CGContextSetLineCap(context, self.lineCap);
            CGContextStrokePath(context);
            
            // Draw the main line, which will cover the middle of the previous line.
            CGContextAddPath(context, self.path);
            CGContextSetStrokeColorWithColor(context, self.strokeColor!.CGColor);
            CGContextSetLineWidth(context, baseWidth);
            CGContextSetLineCap(context, self.lineCap);
            CGContextStrokePath(context);
            
        }
        
        
    }
}
