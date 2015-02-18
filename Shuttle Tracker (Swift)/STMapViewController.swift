//
//  STMapViewController.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/19/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit
import MapKit
import Reachability

let kVisibleShuttlesUpdatedNotification = "kVisibleShuttlesUpdated"
let kUserSelectedShowMapNotification = "kUserSelectedShowMapNotification"

let kLastSelectedMapTypeKey = "LastSelectedMapType"

class STMapViewController: UIViewController, MKMapViewDelegate, UISplitViewControllerDelegate, UIAlertViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView?
    @IBOutlet weak var toolbar: UIToolbar?
    @IBOutlet weak var connectionErrorView: UIView?
    @IBOutlet weak var connectionErrorTitleLabel: UILabel?
    @IBOutlet weak var connectionErrorSubtitleLabel: UILabel?
    private weak var shuttleStatusLabel: UILabel?
    private var internetReachability = Reachability.reachabilityForInternetConnection()
    private var consecutiveStatusUpdateFailures = 0
    private var shuttleStatusDataLoadedAtLeastOnce = false
    private var locationManager = CLLocationManager()
    private var lastSuccessfulStatusUpdate = NSDate(timeIntervalSince1970: 0)
    private var loadedStaticOverlays = false
    private var staticOverlayObjects = [MKOverlay]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the main label's text on the connection error view.
        self.connectionErrorTitleLabel?.text = NSLocalizedString("Cannot Connect", comment:"")
        
        // Set the left bar button item.
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        self.navigationItem.leftItemsSupplementBackButton = true
        
        // Center and zoom the map to the right spot.
        self.centerAndZoomMap(false)
        
        // Setup the toolbar items that couldn't quite be laid out in Interface Builder right.
        self.loadToolbarItems()
        
        // Set map type to whatever it was last set to.
        // Note that if it wasn't previously set to anything, integerForKey: will return 0, which is equal to MKMapType.Standard.
        self.mapView?.mapType = MKMapType(rawValue: UInt(NSUserDefaults.standardUserDefaults().integerForKey(kLastSelectedMapTypeKey)))!
        
        // Listen for notification and act appropriately if the remotely-specified MapLayout variable changes.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "defaultMapLayoutChanged:",
            name: "MapLayout",
            object: nil
        )
        
        // Listen for notification of when static overlays are updated.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "staticOverlaysChanged:",
            name: "StaticOverlays",
            object: nil
        )
        
        // Listen for notification of when the app will enter the foreground.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "applicationWillEnterForeground:",
            name: kAppWillEnterForegroundNotification,
            object: nil
        )
        
        // Listen for notification of shuttle status updates and failures.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "shuttleStatusUpdateReceivedNotificationReceived:",
            name: kShuttleStatusUpdateReceivedNotification,
            object: nil
        )
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "shuttleStatusUpdateFailed:",
            name: kShuttleStatusUpdateErrorOccurredNotification,
            object: nil
        )
        
        
        // Set up listener for Internet reachability.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "reachabilityStatusChanged:",
            name: kReachabilityChangedNotification,
            object: nil
        )
        
        // Set up listener for if a shuttle was selected by the user.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "shuttleSelected:",
            name: kShuttleSelectedNotification,
            object: nil
        )
        
        // Set up listener for if a shuttle was selected by the user.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "userSelectedShowMap:",
            name: kUserSelectedShowMapNotification,
            object: nil
        )
        
        // Check now, in case the app loaded with no Internet connection.
        self.evaluateConnectionErrorViewVisibility()
    }
    
    func loadToolbarItems() {
        
        // Create the array that will hold the toolbar items.
        var toolbarItems = [UIBarButtonItem]()
        
        // The first item (the one on the left) will be the user tracking bar button item.
        let newUserTrackingBarButtonItem = MKUserTrackingBarButtonItem(mapView: self.mapView)
        toolbarItems.append(newUserTrackingBarButtonItem)
        
        // Next, we'll need a flexible item to allow for space between the user tracking bar button item and label.
        toolbarItems.append(UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil))
        
        // Now let's create the label that'll sit in the middle of the toolbar.
        // Let's make the label's height half the size of the toolbar.
        let labelHeight = (self.toolbar!.frame.size.height * 0.5)
        let labelFontSize: CGFloat = 12.0
        let labelFont = UIFont.systemFontOfSize(labelFontSize)
        
        // For the width, let's use the worst-case width.
        let worstCaseLabelText = String(format: NSLocalizedString("%d Shuttles Shown", comment: "") , 999)
        let worstCaseLabelWidth = worstCaseLabelText.sizeWithAttributes([NSFontAttributeName: labelFont]).width
        
        // With all of this, we now know what size the frame of the label should be.
        let toolbarLabel = UILabel(frame: CGRect(x:0, y:((self.toolbar!.frame.size.height - labelHeight) * 0.5), width:worstCaseLabelWidth, height:labelHeight))
        toolbarLabel.font = labelFont
        toolbarLabel.textAlignment = .Center
        
        // We'll want to keep a reference to this so it can be updated easily later.
        self.shuttleStatusLabel = toolbarLabel
        
        // We can't just add a label as a bar button item, so we'll need to create a bar button item as a container for it.
        let labelBarButtonItem = UIBarButtonItem(customView: toolbarLabel)
        toolbarItems.append(labelBarButtonItem)
        
        // And another flexible item for space between the label and final button.
        toolbarItems.append(UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil))
        
        // We don't actually have a use for the final button, so let's just use a fixed space for now.
        toolbarItems.append(UIBarButtonItem(barButtonSystemItem: .FixedSpace, target: nil, action: nil))
        
        // Now set the toolbar's items to the array we've created.
        self.toolbar?.setItems(toolbarItems, animated: false)
    }
    
    func loadStaticOverlays() {
        
        // Remove all static overlays we've already added.
        self.mapView?.removeOverlays(self.staticOverlayObjects)
        
        // Clear the array of static overlays (which have all been removed from the map view now).
        self.staticOverlayObjects.removeAll(keepCapacity: false)
        
        // Add all static overlays.
        if let newOverlaySpecArray = NSUserDefaults.standardUserDefaults().arrayForKey("StaticOverlays") as? [NSDictionary] {
            
            // Parse remote config variables into MKOverlay objects.
            let newOverlayArray = STRemoteConfigurationManager.getOverlaysFromOverlaySpecifications(newOverlaySpecArray)
            
            // Add the overlays to the map view.
            self.mapView?.addOverlays(newOverlayArray, level: .AboveRoads)
            
            // Add the overlays to our array of static overlay objects.
            self.staticOverlayObjects += newOverlayArray
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        // Stop listening for notifications.
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        // Need to unset our display mode button item to avoid a crash if the split view controller tries to access this view controller and it's gone.
        self.navigationItem.leftBarButtonItem = nil
    }
    
    func centerAndZoomMap(animated: Bool) {
        
        // Create the region from the variables saved in defaults.
        let mapLayoutDictionary : NSDictionary = NSUserDefaults.standardUserDefaults().dictionaryForKey("MapLayout")!
        
        let defaultRegion = MKCoordinateRegionMake(
            CLLocationCoordinate2DMake(
                (mapLayoutDictionary.valueForKey("MapDefaultCenterLatitude") as NSNumber).doubleValue,
                (mapLayoutDictionary.valueForKey("MapDefaultCenterLongitude") as NSNumber).doubleValue
            ),
            MKCoordinateSpanMake(
                (mapLayoutDictionary.valueForKey("MapDefaultZoomLatitudeDelta") as NSNumber).doubleValue,
                (mapLayoutDictionary.valueForKey("MapDefaultZoomLongitudeDelta") as NSNumber).doubleValue
            )
        )
        
        // Now set the mapview to use it.
        self.mapView?.setRegion(defaultRegion, animated: animated)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Necessary to get it to center and zoom properly when first shown.
        self.centerAndZoomMap(false)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        coordinator.animateAlongsideTransition(
            nil,
            completion: {
                _ in
                // UI operations should always be done on the main thread.
                NSOperationQueue.mainQueue().addOperationWithBlock({
                    // Re-center the map after the rotation is complete.
                    self.centerAndZoomMap(true)
                })
        })
    }
    
    
    // MARK: - Shuttle status update handling
    
    func shuttleAdded(shuttle: STShuttle) {
        self.mapView?.addAnnotation(shuttle)
    }
    
    func shuttleUpdated(newShuttle: STShuttle) {
        if var existingShuttle = self.getShuttleAnnotationWithIdentifier(newShuttle.identifier!) {
            // Existing annotation needs to be updated.
            
            let animationDuration: NSTimeInterval = (NSUserDefaults.standardUserDefaults().valueForKey("ShuttleAnimationDuration") as NSNumber).doubleValue
            
            let animateChanges = (animationDuration > 0)
            
            if animateChanges {
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationCurve(.Linear)
                UIView.setAnimationDuration(animationDuration)
            }
            
            existingShuttle.coordinate = newShuttle.coordinate
            existingShuttle.title = newShuttle.title
            existingShuttle.subtitle = newShuttle.subtitle
            
            existingShuttle.heading = newShuttle.heading
            existingShuttle.shuttleType = newShuttle.shuttleType
            let annotationView = self.mapView?.viewForAnnotation(existingShuttle)
            annotationView?.setNeedsLayout()
            annotationView?.layoutIfNeeded()
            
            if animateChanges {
                UIView.commitAnimations()
            }
        }
    }
    
    func shuttleRemoved(shuttle: STShuttle) {
        if let existingShuttle = self.getShuttleAnnotationWithIdentifier(shuttle.identifier!) {
            self.mapView?.removeAnnotation(existingShuttle)
        }
    }
    
    func shuttleStatusUpdateFailed(notification: NSNotification) {
        // Increment failure counter.
        self.consecutiveStatusUpdateFailures++
        
        // See if anything should be done about it.
        self.evaluateConsecutiveStatusUpdateFailures()
    }
    
    func updateVisibleDeviceCount() {
        // The visible device count will only show a count of shuttles visible in the mapView.
        
        if !self.shuttleStatusDataLoadedAtLeastOnce {
            // The status label should be blank. We don't want it showing "No Shuttles Shown" prior to even getting any shuttles.
            self.shuttleStatusLabel?.text = ""
            return
        }
        
        // Get all visible annotations in the current mapView.
        let annotationSet = self.mapView?.annotationsInMapRect(self.mapView!.visibleMapRect).allObjects
        
        // We need an array of these shuttles, since we'll be passing them in a notification to other objects.
        var visibleShuttleArray = [STShuttle]()
        
        for eachAnnotation in annotationSet as [MKAnnotation] {
            if eachAnnotation is STShuttle {
                visibleShuttleArray.append(eachAnnotation as STShuttle)
            }
        }
        
        let visibleShuttleCount = visibleShuttleArray.count
        var newStatusText : String
        
        if visibleShuttleCount == 0 {
            newStatusText = NSLocalizedString("No Shuttles Shown", comment:"")
        }
        else if visibleShuttleCount == 1 {
            newStatusText = String(format: NSLocalizedString("%d Shuttle Shown", comment: "Number of shuttles shown (singular)") , 1)
        }
        else {
            newStatusText = String(format: NSLocalizedString("%d Shuttles Shown", comment: "Number of shuttles shown (plural)") , visibleShuttleCount)
        }
        
        // Set the text of the label.
        self.shuttleStatusLabel?.text = newStatusText
        
        // Post notification to any listening objects about the now-visible shuttles.
        NSNotificationCenter.defaultCenter().postNotificationName(
            kVisibleShuttlesUpdatedNotification,
            object: nil,
            userInfo: [
                "shuttles" : visibleShuttleArray
            ]
        )
    }
    
    // MARK: - Direct notification handling
    
    func shuttleStatusUpdateReceivedNotificationReceived(notification: NSNotification) {
        
        // Reset consecutive status update failure count.
        self.consecutiveStatusUpdateFailures = 0
        self.evaluateConsecutiveStatusUpdateFailures()
        
        // Pull out the notification. Find whether it was added, updated, or deleted, and then call the appropriate method.
        let userInfo = (notification.userInfo! as NSDictionary)
        
        for eachNumberKey in userInfo.allKeys as [NSNumber] {
            if let eachChangeType = ShuttleStatusChangeType(rawValue: eachNumberKey.integerValue) {
                for eachShuttle in userInfo[eachNumberKey] as [STShuttle] {
                    
                    if !self.shuttleStatusDataLoadedAtLeastOnce {
                        // This is the first time we've loaded shuttles since they've been clear, so anything but a removal should be treated as an "add."
                        if eachChangeType != .Removed {
                            self.shuttleAdded(eachShuttle)
                        }
                        continue
                    }
                    
                    switch eachChangeType {
                    case .Added:
                        self.shuttleAdded(eachShuttle)
                    case .Updated:
                        self.shuttleUpdated(eachShuttle)
                    case .Removed:
                        self.shuttleRemoved(eachShuttle)
                    default:
                        ""
                    }
                }
            }
        }
        
        // Set flag that we've received data at least once.
        self.shuttleStatusDataLoadedAtLeastOnce = true
        
        // Set last successful status update to now.
        self.lastSuccessfulStatusUpdate = NSDate()
        
        // Update visible device count.
        self.updateVisibleDeviceCount()
    }
    
    func evaluateConnectionErrorViewVisibility() {
        
        // If there's no Internet connection, the view should be visible.
        let internetConnectionReachable = (self.internetReachability.currentReachabilityStatus() != NetworkStatus.NotReachable)
        
        if !internetConnectionReachable {
            // Set the subtitle label's text on the connection error view indicating that the Internet connection is unreachable.
            self.connectionErrorSubtitleLabel?.text = NSLocalizedString("You must connect to a Wi-Fi or cellular data network to view shuttle positions.", comment:"")
            
            // Clear the shuttle status text label. We don't want it saying "3 Shuttles Shown" if that's just their old locations and we don't have Internet now.
            self.shuttleStatusLabel?.text = ""
        }
        
        if internetConnectionReachable && !self.shuttleStatusDataLoadedAtLeastOnce {
            // Reset failure count. Internet just came back on, so let's give it a chance to succeed before showing the "You have Internet, but still couldn't update shuttle data" message.
            self.consecutiveStatusUpdateFailures = 0
        }
        
        self.connectionErrorView?.hidden = internetConnectionReachable
        
        // Let's make sure the logic for handling consecutive status update failures is also checked.
        self.evaluateConsecutiveStatusUpdateFailures()
    }
    
    func reachabilityStatusChanged(notification: NSNotification) {
        self.evaluateConnectionErrorViewVisibility()
    }
    
    // Implement behavior for handling if there have been enough consecutive status update failures to alert the user.
    func evaluateConsecutiveStatusUpdateFailures() {
        
        if self.consecutiveStatusUpdateFailures == 0 {
            // Everything is normal. Hide any error notices, etc.
            if self.internetReachability.currentReachabilityStatus() != NetworkStatus.NotReachable {
                self.connectionErrorView?.hidden = true
            }
        }
        else if self.consecutiveStatusUpdateFailures > maxAllowableConsecutiveStatusUpdateFailures || !self.shuttleStatusDataLoadedAtLeastOnce {
            // We've failed to get status updates too many times, or we've never actually retrieved data and failed on the first try.
            
            // The shuttle annotations should be removed. We don't want to lead the user to believe the shuttles may have just stopped.
            self.removeAllShuttles()
            
            // Clear the shuttle status text label.
            self.shuttleStatusLabel?.text = ""
            
            // Check if Internet is reachable.
            if self.internetReachability.currentReachabilityStatus() == NetworkStatus.NotReachable {
                // If the Internet connection is down, they already have a big warning view in their face about that. Don't do anything differently.
            }
            else {
                // The user has an Internet connection, so if we do no further notification, the user won't know why the shuttles disappeared. 
                // Let's show the connection error view and update the subtitle label's text so they know something is wrong.
                self.connectionErrorSubtitleLabel?.text = NSLocalizedString("Unable to fetch shuttle status data. Will keep trying.", comment:"")
                self.connectionErrorView?.hidden = false
            }
        }
    }
    
    func defaultMapLayoutChanged(notification: NSNotification) {
        println("Default map layout changed. Re-centering map.")
        self.centerAndZoomMap(true)
    }
    
    func staticOverlaysChanged(notification: NSNotification) {
        // Only load overlays immediately if they've been loaded before and have now changed.
        if self.loadedStaticOverlays {
            self.loadStaticOverlays()
            
            self.evaluateOverlayVisibility()
        }
    }
    
    func userSelectedShowMap(notification: NSNotification) {
        self.centerAndZoomMap(true)
    }
    
    func applicationWillEnterForeground(notification: NSNotification) {
        
        // Let's see if it's been long enough to assume our shuttle locations are out-of-date.
        let timeSinceLastSuccessfulUpdate = NSDate().timeIntervalSinceDate(self.lastSuccessfulStatusUpdate)
        let maxTimeIntervalAllowable : NSTimeInterval = NSUserDefaults.standardUserDefaults().doubleForKey("ShuttleDataRefreshInterval") * Double(maxAllowableConsecutiveStatusUpdateFailures+1)
        
        if timeSinceLastSuccessfulUpdate > maxTimeIntervalAllowable {
            println("Assuming shuttle locations are out-of-date. Clearing.")
            self.removeAllShuttles()
        }
    }
    
    func shuttleSelected(notification: NSNotification) {
        
        var selectedShuttle = notification.userInfo!["shuttle"] as STShuttle
        
        // Just to be safe, let's load the specific annotation instance from the mapView.
        if let annotationFromShuttle = self.getShuttleAnnotationWithIdentifier(selectedShuttle.identifier!) {
            self.mapView?.selectAnnotation(annotationFromShuttle, animated: true)
        }
    }
    
    // MARK: - MKMapViewDelegate methods
    
    func mapViewWillStartLoadingMap(mapView: MKMapView!) {
        STAppDelegate.didStartNetworking()
    }
    
    func mapViewDidFinishLoadingMap(mapView: MKMapView!) {
        STAppDelegate.didStopNetworking()
    }
    
    func mapViewDidFailLoadingMap(mapView: MKMapView!, withError error: NSError!) {
        STAppDelegate.didStopNetworking()
    }
    
    func mapViewDidFinishRenderingMap(mapView: MKMapView!, fullyRendered: Bool) {
        
        // Only add overlays if the map rendered. Otherwise, we'll be drawing additional roads that won't make sense without the map tiles.
        if fullyRendered {
            if !self.loadedStaticOverlays {
                
                // Add the additional road overlays.
                self.loadStaticOverlays()
                
                // Evaluate their visibility (based on map type).
                self.evaluateOverlayVisibility()
                
                // Set flag so we don't add them again.
                self.loadedStaticOverlays = true
            }
        }
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        
        // Only provide annotations for shuttle annotations.
        if annotation is STShuttle {
            var thisAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(kShuttleAnnotationViewIdentifier)
            if thisAnnotationView == nil {
                thisAnnotationView = STShuttleAnnotationView(annotation as STShuttle)
            }
            else {
                thisAnnotationView.annotation = annotation
                thisAnnotationView?.setNeedsLayout()
                thisAnnotationView?.layoutIfNeeded()
            }
            return thisAnnotationView
        }
        
        return nil
    }
    
    func mapViewWillStartLocatingUser(mapView: MKMapView!) {
        
        // Check authorization status
        let authStatus = CLLocationManager.authorizationStatus()
        
        // User has never been asked to decide on location authorization
        if authStatus == .NotDetermined {
            self.locationManager.requestWhenInUseAuthorization()
        }
        else if (authStatus == .Restricted) {
            // This app is not authorized to use location services. 
            // The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
            let newAlertView = UIAlertView()
            newAlertView.title = NSLocalizedString("Location Services restricted", comment:"")
            newAlertView.message = NSLocalizedString("This device is restricted from allowing you to authorize showing its location.", comment:"")
            newAlertView.addButtonWithTitle(NSLocalizedString("OK", comment:""))
            newAlertView.show()
        }
        else if (authStatus == .Denied) {
            // User has denied location use (either for this app or for all apps).
            let newAlertView = UIAlertView()
            newAlertView.title = NSLocalizedString("Turn on Location Services", comment:"")
            newAlertView.message = NSLocalizedString("Open the Settings app and enable Location Services for this app to show your location.", comment:"");
            newAlertView.addButtonWithTitle(NSLocalizedString("OK", comment:""))
            newAlertView.show()
            
            // NOTE: Some apps will offer more specific instructions, but those seem to change a little with each iOS version, so being a little more vague will hopefully future-proof things a little.
        }
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        self.updateVisibleDeviceCount()
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is STPolyline {
            let lineRenderer = STPolylineRenderer(customPolyline: overlay as STPolyline)
            return lineRenderer
        }
        else if overlay is STPolygon {
            let polygonRenderer = STPolygonRenderer(customPolygon: overlay as STPolygon)
            return polygonRenderer
        }
        
        return nil
    }
    
    // MARK: - Custom setters and getters
    
    dynamic var mapType:MKMapType {
        get {
            return self.mapView!.mapType
        }
        set {
            self.mapView?.mapType = newValue
            
            self.evaluateOverlayVisibility()
            
            NSUserDefaults.standardUserDefaults().setInteger(Int(newValue.rawValue), forKey: kLastSelectedMapTypeKey)
        }
    }
    
    // MARK: - Convenience methods
    
    func getShuttleAnnotationWithIdentifier(identifier : NSString) -> STShuttle? {
        // TODO: Keep separate NSDictionary for quick lookup of shuttle annotations based on identifier?
        
        for eachMapAnnotation in self.mapView!.annotations {
            if eachMapAnnotation is STShuttle {
                var existingShuttleAnnotation = eachMapAnnotation as STShuttle
                if existingShuttleAnnotation.identifier == identifier {
                    return existingShuttleAnnotation
                }
            }
        }
        return nil
    }
    
    func removeAllShuttles() {
        var annotationsToRemove: [MKAnnotation] = []
        
        for eachMapAnnotation in self.mapView!.annotations as [MKAnnotation] {
            if eachMapAnnotation is STShuttle {
                annotationsToRemove.append(eachMapAnnotation)
            }
        }
        
        self.mapView?.removeAnnotations(annotationsToRemove)
        
        // Reset "loaded data at least once" flag.
        self.shuttleStatusDataLoadedAtLeastOnce = false
    }
    
    func evaluateOverlayVisibility() {
        
        for eachOverlay in self.mapView?.overlays as [MKOverlay] {
            var newAlpha : CGFloat = 1
            
            if let thisMapView = self.mapView {
                switch thisMapView.mapType {
                case .Standard:
                    // This is the standard view, where roads are clearly highlighted.
                    newAlpha = 1
                case .Satellite:
                    // This is the satellite view, where roads are only visible from satellite imagery.
                    newAlpha = 0
                case .Hybrid:
                    // This is the hybrid view, where road labels are kinda translucent.
                    newAlpha = 0.5
                default:
                    // Shouldn't be reached, unless a new map type is added in a future SDK.
                    newAlpha = 1
                }
            }
            
            if let thisRenderer = self.mapView?.rendererForOverlay(eachOverlay) {
                thisRenderer.alpha = newAlpha
            }
        }
        
    }

}
