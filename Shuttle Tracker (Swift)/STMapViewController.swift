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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the main label's text on the connection error view.
        self.connectionErrorTitleLabel?.text = NSLocalizedString("Cannot Connect", comment:"")
        
        // Set the left bar button item.
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        self.navigationItem.leftItemsSupplementBackButton = true
        
        // Setup the toolbar items that couldn't quite be laid out in Interface Builder right.
        self.loadToolbarItems()
        
        // Center and zoom the map to the right spot.
        self.centerAndZoomMap(false)
        
        // Listen for notification and act appropriately if the remotely-specified MapLayout variable changes.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "defaultMapLayoutChanged:",
            name: "MapLayout",
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
        
        // We'll make this tappable, so we can have it be the "secret" way of re-centering the map.
        toolbarLabel.userInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: "shuttleStatusLabelPressed:")
        toolbarLabel.addGestureRecognizer(tapGesture)
        
        // We can't just add a label as a bar button item, so we'll need to create a bar button item as a container for it.
        let labelBarButtonItem = UIBarButtonItem(customView: toolbarLabel)
        toolbarItems.append(labelBarButtonItem)
        
        // And another flexible item for space between the label and info button.
        toolbarItems.append(UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil))
        
        // The final item will be an "info" style button on the right side of the toolbar.
        let infoButton = UIButton.buttonWithType(.InfoDark) as UIButton
        infoButton.hidden = true
        infoButton.addTarget(self, action: "infoButtonPressed:", forControlEvents: .TouchUpInside)
        let infoBarButtonItem = UIBarButtonItem(customView: infoButton)
        toolbarItems.append(infoBarButtonItem)
        
        // Now set the toolbar's items to the array we've created.
        self.toolbar?.setItems(toolbarItems, animated: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func infoButtonPressed(sender: UIButton) {
        println("Info button pressed.")
    }
    
    func shuttleStatusLabelPressed(sender: UILabel) {
        // I'm not sure if tapping the label is intuitive or not. Regardless, it needs to be somewhere, so it's here for now.
        self.centerAndZoomMap(true)
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

}
