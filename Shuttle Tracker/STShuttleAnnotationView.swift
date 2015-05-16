//
//  STShuttleAnnotationView.swift
//  Shuttle Tracker
//
//  Created by Benn Linger on 1/26/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import MapKit

let kShuttleAnnotationViewIdentifier = "kShuttleAnnotationViewIdentifier"

class STShuttleAnnotationView: MKAnnotationView {
    
    private weak var shuttleBlipImageView : UIImageView?
    private weak var shuttleHeadingImageView : UIImageView?
    private var lastSetShuttleType = ShuttleType.Red
    
    // This apparently only needs to be fleshed out if I plan to use this class in a storyboard.
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    init(_ shuttle: STShuttle) {
        super.init(annotation: shuttle, reuseIdentifier: kShuttleAnnotationViewIdentifier)
        
        // The callout will show the name of the shuttle and its subtitle. This is actually kind of critical for accessibility (color blindness).
        self.canShowCallout = true
        
        // Set up the main shuttle blip imageview.
        let blipImage = UIImage(named: self.shuttle!.getBlipImageName())
        self.frame = CGRectMake(0, 0, blipImage!.size.width, blipImage!.size.height)
        let newShuttleBlipImageView = UIImageView(image: blipImage)
        newShuttleBlipImageView.center = self.center
        newShuttleBlipImageView.contentMode = .Center
        self.addSubview(newShuttleBlipImageView)
        self.shuttleBlipImageView = newShuttleBlipImageView
        self.lastSetShuttleType = shuttle.shuttleType
        
        // Set up the heading blip imageview.
        let newHeadingBlipImageView = UIImageView(image:UIImage(named: "HeadingBlip"))
        newHeadingBlipImageView.frame = self.bounds
        newHeadingBlipImageView.contentMode = .Center
        self.insertSubview(newHeadingBlipImageView, belowSubview: newShuttleBlipImageView)
        self.shuttleHeadingImageView = newHeadingBlipImageView
        
        self.updateShuttleImageViewAngle()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Check if the shuttle type is different from when it was last set up. That'll call for a different image.
        if self.lastSetShuttleType != self.shuttle!.shuttleType {
            self.shuttleBlipImageView?.image = UIImage(named: self.shuttle!.getBlipImageName())
            self.lastSetShuttleType = self.shuttle!.shuttleType
        }
        
        self.updateShuttleImageViewAngle()
    }
    
    func updateShuttleImageViewAngle() {
        
        // First, convert the shuttle's heading (stored as degrees) to radians.
        let angleInRadians = CGFloat(shuttle!.heading / 57.2958)
        
        // Now apply the transformation.
        self.shuttleBlipImageView?.transform = CGAffineTransformMakeRotation(angleInRadians)
        self.shuttleHeadingImageView?.transform = CGAffineTransformMakeRotation(angleInRadians)
    }
    
    var shuttle:STShuttle? {
        get {
            return self.annotation as! STShuttle?
        }
        set {
            self.annotation = newValue
        }
    }
    
    
}
