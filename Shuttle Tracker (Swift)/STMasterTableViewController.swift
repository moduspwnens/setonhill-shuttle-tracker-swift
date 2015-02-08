//
//  STMasterTableViewController.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/19/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit
import MapKit

let kShowMapTableSectionIndex = 0
let kShuttleTableSectionIndex = 1
let kSchedulesTableSectionIndex = 2
let kMapTypeSelectSectionIndex = 3

let kTableViewShowMapCellReuseIdentifier = "kTableViewShowMapCellReuseIdentifier"
let kTableViewShuttleCellReuseIdentifier = "kTableViewShuttleCellReuseIdentifier"
let kTableViewScheduleCellReuseIdentifier = "kTableViewScheduleCellReuseIdentifier"
let kTableViewMapTypeCellReuseIdentifier = "kTableViewMapTypeCellReuseIdentifier"

let kSegmentedControlViewTag = 14

let kShuttleSelectedNotification = "kShuttleSelected"

class STMasterTableViewController: UITableViewController, UISplitViewControllerDelegate {
    
    @IBOutlet var doneBarButtonItem: UIBarButtonItem?
    private var detailNavController : UINavigationController?
    private var mapViewController : STMapViewController?
    private var visibleShuttleArray = [STShuttle]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set this instance as the split view controller's delegate.
        self.splitViewController?.delegate = self
        
        // Back button should be blank (icon with no text)
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Plain, target: nil, action: nil)
        
        // Keep a reference to our detail nav controller so we can manipulate its view controllers.
        self.detailNavController = self.splitViewController?.viewControllers[1] as UINavigationController!
        
        // Keep a reference to our map view controller so it doesn't need to be reloaded if we replace it in our nav controller.
        self.mapViewController = self.detailNavController?.viewControllers.first as STMapViewController!
        
        // Set up listener for when the array of visible shuttles changes. This'll happen if shuttles go off-screen, disappear completely, or the user pans the map away from them.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "visibleShuttlesUpdated:",
            name: kVisibleShuttlesUpdatedNotification,
            object: nil
        )
        
        // Set up listener for when the shuttle schedule links (from remote configuration variables) are updated.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "shuttleScheduleLinksChanged:",
            name: "ShuttleScheduleLinks",
            object: nil
        )
        
        // Listen for notification and act appropriately if the remotely-specified ShowMapTypeSelector variable changes.
        NSNotificationCenter.defaultCenter().addObserverForRemoteConfigurationUpdate(
            self,
            selector: "shouldShowMapTypeSelectorChanged:",
            name: "ShowMapTypeSelector",
            object: nil
        )
        
        // Fix for the quick "jump" it otherwise makes to scoot itself under the navigation bar when it's first shown.
        self.edgesForExtendedLayout = .None
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add/remove the "Done" button based on whether or not the split view controller is collapsed.
        self.navigationItem.rightBarButtonItem = self.splitViewController!.collapsed ? self.doneBarButtonItem : nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func mapTypeControlValueChanged(sender: UISegmentedControl) {
        // Assign new map type.
        self.mapViewController?.mapType = MKMapType(rawValue: UInt(sender.selectedSegmentIndex))!
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Split view controller delegate
    
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController!, ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool {
        // This makes sure that on devices that show a collapsed split view controller (iPhones other than 6+ in landscape), the map view controller is shown by default.
        return false
    }
    
    func primaryViewControllerForExpandingSplitViewController(splitViewController: UISplitViewController) -> UIViewController? {
        // The delegate is being asked for the primary view controller for the purpose of showing both. The "Done" button should be hidden if both view controllers will be visible.
        self.navigationItem.rightBarButtonItem = nil
        
        // Returning nil allows the split view controller to do what it'd do if we hadn't implemented this method.
        return nil
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        var numberOfSections = 3
        
        if self.shouldShowMapTypeSelector {
            numberOfSections++
        }
        
        return numberOfSections
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if section == kShowMapTableSectionIndex {
            return 1
        }
        else if section == kShuttleTableSectionIndex {
            return self.visibleShuttleArray.count
        }
        else if section == kSchedulesTableSectionIndex {
            return self.getShuttleScheduleLinks().count
        }
        else if section == kMapTypeSelectSectionIndex {
            return 1
        }
        
        return 0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == kShowMapTableSectionIndex {
            return NSLocalizedString("Show", comment:"Make appear on the screen")
        }
        else if section == kShuttleTableSectionIndex {
            return NSLocalizedString("Shuttles", comment:"")
        }
        else if section == kSchedulesTableSectionIndex {
            return NSLocalizedString("Schedules", comment:"")
        }
        else if section == kMapTypeSelectSectionIndex {
            return NSLocalizedString("Map Type", comment:"")
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        // The cell we return will vary based on what's section it's in.
        var cell : UITableViewCell?
        
        if indexPath.section == kShowMapTableSectionIndex {
            
            
            cell = tableView.dequeueReusableCellWithIdentifier(kTableViewShowMapCellReuseIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: .Subtitle, reuseIdentifier: kTableViewShowMapCellReuseIdentifier)
            }
            
            cell?.textLabel?.text = NSLocalizedString("Main Campus", comment:"")
            cell?.accessoryType = .DisclosureIndicator
        }
        else if indexPath.section == kShuttleTableSectionIndex {
            // This is a table view cell for a specific shuttle.
            
            cell = tableView.dequeueReusableCellWithIdentifier(kTableViewShuttleCellReuseIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: .Subtitle, reuseIdentifier: kTableViewShuttleCellReuseIdentifier)
            }
            
            let thisShuttle = self.visibleShuttleArray[indexPath.row]
            cell?.textLabel?.text = thisShuttle.title
            cell?.detailTextLabel?.text = thisShuttle.subtitle
            cell?.imageView?.image = UIImage(named: thisShuttle.getBlipImageName())
            cell?.accessoryType = .DisclosureIndicator
        }
        else if indexPath.section == kSchedulesTableSectionIndex {
            // This is a table view cell for a shuttle schedule link.
            
            cell = tableView.dequeueReusableCellWithIdentifier(kTableViewScheduleCellReuseIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: .Default, reuseIdentifier: kTableViewScheduleCellReuseIdentifier)
            }
            
            let thisScheduleLink = self.getShuttleScheduleLinks()[indexPath.row] as [String:String]
            cell?.textLabel?.text = thisScheduleLink["title"]!
            cell?.accessoryType = .DisclosureIndicator
        }
        else if indexPath.section == kMapTypeSelectSectionIndex {
            // This is a table view cell for the map type selector.
            
            cell = tableView.dequeueReusableCellWithIdentifier(kTableViewMapTypeCellReuseIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: .Default, reuseIdentifier: kTableViewMapTypeCellReuseIdentifier)
                
                // This cell will not be tapped directly. It'll have a control inside that does things.
                cell?.selectionStyle = .None
                
                // Define what the segmented control buttons will say.
                // Note that, for simplicity's sake, these strings' indexes match the MKMapViewType enum order.
                let segmentedControlItems = [
                    NSLocalizedString("Standard", comment:"Referring to the default map type."),
                    NSLocalizedString("Satellite", comment:"Referring to the map type that just shows satellite imagery."),
                    NSLocalizedString("Hybrid", comment:"Referring to the map type that shows satellite imagery with road and POI overlays.")
                ]
                
                // Create the new segmented control.
                let newSegmentedControl = UISegmentedControl(items: segmentedControlItems)
                let defaultPadding : CGFloat = 20
                newSegmentedControl.frame = CGRectMake(
                    0,
                    0,
                    cell!.frame.size.width - defaultPadding,
                    cell!.frame.size.height - defaultPadding
                )
                newSegmentedControl.center = cell!.center
                newSegmentedControl.autoresizingMask = .FlexibleHeight | .FlexibleWidth
                
                // Assign tag (so we can access this control quickly later).
                newSegmentedControl.tag = kSegmentedControlViewTag
                
                // Add callback.
                newSegmentedControl.addTarget(self, action: "mapTypeControlValueChanged:", forControlEvents: .ValueChanged)
                
                // Add segmented control to cell.
                cell?.addSubview(newSegmentedControl)
            }
            
            // This cell may or may not have been created before. Get its segmented control button to make sure its state is accurate.
            let thisSegmentedControl = cell?.viewWithTag(kSegmentedControlViewTag) as UISegmentedControl
            
            // Assign existing value as currently selected.
            thisSegmentedControl.selectedSegmentIndex = Int(self.mapViewController!.mapType.rawValue)
        }

        return cell!
    }

    // MARK: - Table view delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        // What action we'll take depends on what section the selected row is in.
        if indexPath.section == kShowMapTableSectionIndex {
            // The user tapped the cell for showing the main campus.
            
            // Set map view controller as main view controller of detail nav controller.
            self.detailNavController?.setViewControllers([self.mapViewController!], animated: false)
            
            // Send focus to detail view controller.
            self.splitViewController?.showDetailViewController(self.detailNavController!, sender: self)
            
            // Re-center the map on main campus.
            NSNotificationCenter.defaultCenter().postNotificationName(
                kUserSelectedShowMapNotification,
                object: nil,
                userInfo: nil
            )
            
            // De-select this cell.
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        else if indexPath.section == kShuttleTableSectionIndex {
            // The user tapped a shuttle's table cell.
            
            let thisShuttle = self.visibleShuttleArray[indexPath.row]
            
            // Set map view controller as main view controller of detail nav controller.
            self.detailNavController?.setViewControllers([self.mapViewController!], animated: false)
            
            // Send focus to detail view controller.
            self.splitViewController?.showDetailViewController(self.detailNavController!, sender: self)
            
            // Post notification that the shuttle was selected.
            NSNotificationCenter.defaultCenter().postNotificationName(
                kShuttleSelectedNotification,
                object: nil,
                userInfo: [
                    "shuttle" : thisShuttle
                ]
            )
            
            // De-select this cell.
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        else if indexPath.section == kSchedulesTableSectionIndex {
            // The user tapped the name of a shuttle schedule.
            
            let thisScheduleLink = self.getShuttleScheduleLinks()[indexPath.row] as [String:String]
            let scheduleName = thisScheduleLink["title"]!
            let scheduleURL = NSURL(string: thisScheduleLink["url"]!)!
            
            let newWebViewController = STWebViewController(url: scheduleURL, title: scheduleName)
            
            // Set this web view controller as main view controller of detail nav controller.
            self.detailNavController?.setViewControllers([newWebViewController], animated: false)
            
            // Send focus to detail view controller.
            self.splitViewController?.showDetailViewController(self.detailNavController!, sender: self)
            
            // De-select this cell.
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        else if indexPath.section == kMapTypeSelectSectionIndex {
            // Do nothing. This cell has a control inside of it and tapping the cell itself should do nothing.
            
            // De-select this cell.
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        else {
            // This is a section that doesn't support selection. Just de-select immediately.
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }

    // MARK: - Direct notification handling
    
    func visibleShuttlesUpdated(notification: NSNotification) {
        
        // Update cached shuttle array.
        let newShuttleArray = notification.userInfo!["shuttles"] as [STShuttle]
        self.visibleShuttleArray.removeAll(keepCapacity: false)
        self.visibleShuttleArray += newShuttleArray
        
        // Tell table view to reload the table section that shows shuttles.
        self.tableView.reloadSections(NSIndexSet(index: kShuttleTableSectionIndex), withRowAnimation: .None)
    }
    
    func shouldShowMapTypeSelectorChanged(notification: NSNotification) {
        
        if !self.shouldShowMapTypeSelector {
            // If we're about to hide the map type selector, reset it to the default map type.
            self.mapViewController?.mapType = .Standard
        }
        
        // Reload the map type selection table view section.
        self.tableView.beginUpdates()
        
        if self.shouldShowMapTypeSelector {
            self.tableView.insertSections(NSIndexSet(index: kMapTypeSelectSectionIndex), withRowAnimation: .Automatic)
        }
        else {
            self.tableView.deleteSections(NSIndexSet(index: kMapTypeSelectSectionIndex), withRowAnimation: .Automatic)
        }
        
        self.tableView.endUpdates()
    }
    
    func shuttleScheduleLinksChanged(notification: NSNotification) {
        // Tell table view to reload the table section that shows shuttle schedules.
        self.tableView.reloadSections(NSIndexSet(index: kSchedulesTableSectionIndex), withRowAnimation: .None)
    }
    
    // MARK: - Convenience methods
    
    func getShuttleScheduleLinks() -> [AnyObject] {
        return NSUserDefaults.standardUserDefaults().arrayForKey("ShuttleScheduleLinks")!
    }
    
    dynamic var shouldShowMapTypeSelector:Bool {
    get {
        return NSUserDefaults.standardUserDefaults().boolForKey("ShowMapTypeSelector")
    }
    }

}
