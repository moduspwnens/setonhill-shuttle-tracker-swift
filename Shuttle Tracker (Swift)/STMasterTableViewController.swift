//
//  STMasterTableViewController.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 1/19/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import UIKit

let kShuttleTableSectionIndex = 0

let kTableViewShuttleCellReuseIdentifier = "kTableViewShuttleCellReuseIdentifier"

let kShuttleSelectedNotification = "kShuttleSelected"

class STMasterTableViewController: UITableViewController, UISplitViewControllerDelegate {
    
    @IBOutlet var doneBarButtonItem: UIBarButtonItem?
    private var detailViewController : UIViewController?
    private var visibleShuttleArray = [STShuttle]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set this instance as the split view controller's delegate.
        self.splitViewController?.delegate = self
        
        // Back button should be blank (icon with no text)
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Plain, target: nil, action: nil)
        
        // Keep a reference to our detail view controller so it doesn't need to be reloaded if the split view controller collapses.
        self.detailViewController = self.splitViewController?.viewControllers[1] as UIViewController!
        
        // Set up listener for when the array of visible shuttles changes. This'll happen if shuttles go off-screen, disappear completely, or the user pans the map away from them.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "visibleShuttlesUpdated:",
            name: kVisibleShuttlesUpdatedNotification,
            object: nil
        )
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
    
    @IBAction func doneButtonPressed(sender: AnyObject?) {
        // Show the detail view controller again.
        self.splitViewController?.showDetailViewController(self.detailViewController, sender: self)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        // Overriding this method is necessary to detect when the "Done" button should disappear on the iPhone 6+.
        
        if self.splitViewController!.collapsed {
            // We're shifting out of a collapsed view, so the "Done" button should be removed.
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Split view controller delegate
    
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController!, ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool {
        // This makes sure that on devices that show a collapsed split view controller (iPhones other than 6+ in landscape), the map view controller is shown by default.
        return false
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if section == kShuttleTableSectionIndex {
            return self.visibleShuttleArray.count
        }
        
        return 0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == kShuttleTableSectionIndex {
            return NSLocalizedString("Shuttles", comment:"")
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        // The cell we return will vary based on what's section it's in.
        var cell : UITableViewCell?
        
        if indexPath.section == kShuttleTableSectionIndex {
            cell = tableView.dequeueReusableCellWithIdentifier(kTableViewShuttleCellReuseIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: .Subtitle, reuseIdentifier: kTableViewShuttleCellReuseIdentifier)
            }
            
            let thisShuttle = self.visibleShuttleArray[indexPath.row]
            cell?.textLabel?.text = thisShuttle.title
            cell?.detailTextLabel?.text = thisShuttle.subtitle
            cell?.imageView?.image = UIImage(named: thisShuttle.getBlipImageName())
        }

        return cell!
    }

    // MARK: - Table view delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        // What action we'll take depends on what section the selected row is in.
        if indexPath.section == kShuttleTableSectionIndex {
            
            // The user tapped a shuttle's table cell.
            let thisShuttle = self.visibleShuttleArray[indexPath.row]
            
            // Post notification that the shuttle was selected.
            NSNotificationCenter.defaultCenter().postNotificationName(
                kShuttleSelectedNotification,
                object: nil,
                userInfo: [
                    "shuttle" : thisShuttle
                ]
            )
            
            // If the split view controller is showing a collapsed view, we'll want to make sure the map view controller is being shown.
            if self.splitViewController!.collapsed {
                self.splitViewController?.showDetailViewController(self.detailViewController, sender: self)
            }
            
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

}
