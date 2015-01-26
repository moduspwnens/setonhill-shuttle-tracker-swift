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

class STMapViewController: UIViewController, MKMapViewDelegate, UISplitViewControllerDelegate, UIAlertViewDelegate {
    
    var shuttleDataManager: STShuttleDataManager?
    @IBOutlet weak var mapView: MKMapView?
    @IBOutlet weak var toolbar: UIToolbar?
    @IBOutlet weak var connectionErrorView: UIView?
    @IBOutlet weak var connectionErrorTitleLabel: UILabel?
    @IBOutlet weak var connectionErrorSubtitleLabel: UILabel?
    private weak var shuttleStatusLabel: UILabel?
    private var mapLayoutObserver : NSObjectProtocol?
    private var internetReachability: Reachability = Reachability.reachabilityForInternetConnection()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the labels' text on the connection error view.
        self.connectionErrorTitleLabel?.text = NSLocalizedString("Cannot Connect", comment:"")
        self.connectionErrorSubtitleLabel?.text = NSLocalizedString("You must connect to a Wi-Fi or cellular data network to view shuttle positions.", comment:"")
        
        // Set the left bar button item.
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        self.navigationItem.leftItemsSupplementBackButton = true
        
        // Setup the toolbar items that couldn't quite be laid out in Interface Builder right.
        self.loadToolbarItems()
        
        // Center and zoom the map to the right spot.
        self.centerAndZoomMap(false)
        
        // Listen for notification and act appropriately if the remotely-specified MapLayout variable changes.
        self.mapLayoutObserver = NSNotificationCenter.defaultCenter()
            .addObserverForRemoteConfigurationNotificationName(
                "MapLayout",
                object: nil,
                queue: NSOperationQueue.mainQueue(),
                usingBlock:
                { _ in
                    println("Default map layout changed. Re-centering map.")
                    self.centerAndZoomMap(true)
                }
        )
        
        // Listen for notification of shuttle status updates and failures.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "shuttleStatusChangedNotificationReceived:",
            name: kShuttleStatusChangedNotification,
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
            selector: "evaluateConnectionErrorViewVisibility:",
            name: kReachabilityChangedNotification,
            object: nil
        )
        
        // Check now, in case the app loaded with no Internet connection.
        self.evaluateConnectionErrorViewVisibility(nil)
        
        // Start Internet reachability notifier.
        self.internetReachability.startNotifier()
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
        if self.mapLayoutObserver != nil {
            NSNotificationCenter.defaultCenter().removeObserver(self.mapLayoutObserver!)
        }
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
    
    func evaluateConnectionErrorViewVisibility(notification: NSNotification?) {
        
        // If there's no Internet connection, it should be visible.
        let internetConnectionReachable = (self.internetReachability.currentReachabilityStatus() != NetworkStatus.NotReachable)
        self.connectionErrorView?.hidden = internetConnectionReachable
    }
    
    // MARK: - Shuttle status update handling
    func shuttleAdded(shuttleStatusInstance: STShuttleStatusInstance) {
        self.mapView?.addAnnotation(shuttleStatusInstance.shuttle)
    }
    
    func shuttleUpdated(shuttleStatusInstance: STShuttleStatusInstance) {
        let newShuttle = shuttleStatusInstance.shuttle
        
        if var existingShuttle = self.getShuttleAnnotationWithIdentifier(newShuttle.identifier!) {
            // Existing annotation needs to be updated.
            existingShuttle.coordinate = newShuttle.coordinate
            existingShuttle.title = newShuttle.title
            existingShuttle.subtitle = newShuttle.subtitle
        }
    }
    
    func shuttleRemoved(shuttleStatusInstance: STShuttleStatusInstance) {
        if let existingShuttle = self.getShuttleAnnotationWithIdentifier(shuttleStatusInstance.shuttle.identifier!) {
            self.mapView?.removeAnnotation(existingShuttle)
        }
    }
    
    func shuttleStatusUpdateFailed(notification: NSNotification) {
        println("Shuttles update failed. \n\(notification.userInfo!)")
        self.shuttleStatusLabel?.text = ""
    }
    
    // MARK: - Shuttle status notification handling
    // These methods are basically just to allow for shuttles to be added/removed without necessarily using an NSNotification.
    
    func shuttleStatusChangedNotificationReceived(notification: NSNotification) {
        // Pull out the notification. Find whether it was added, updated, or deleted, and then call the appropriate method.
        
        let userInfo = (notification.userInfo! as NSDictionary)
        let thisShuttleStatusInstance = userInfo.objectForKey("shuttleStatus")! as STShuttleStatusInstance
        let changeType = ShuttleStatusChangeType(rawValue: (userInfo.objectForKey("type")! as NSNumber).integerValue)!
        
        switch changeType {
        case .Added:
            self.shuttleAdded(thisShuttleStatusInstance)
        case .Updated:
            self.shuttleUpdated(thisShuttleStatusInstance)
        case .Removed:
            self.shuttleRemoved(thisShuttleStatusInstance)
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
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

}
