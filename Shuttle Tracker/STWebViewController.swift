//
//  STWebViewController.swift
//  Shuttle Tracker
//
//  Created by Benn Linger on 2/4/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import WebKit
import MBProgressHUD

let kDefaultTimeoutTimeInterval : NSTimeInterval = 10

class STWebViewController: UIViewController, UIWebViewDelegate, UIAlertViewDelegate {
    
    @IBOutlet weak var webView : UIWebView?
    private var url : NSURL
    private var linkTitle : String
    
    // Custom initializer requiring what's necessary to show the view controller.
    init(url: NSURL, title: String) {
        
        // Initialize instance variables
        self.url = url
        self.linkTitle = title
        
        // Call super's init with nib to be sure the rest of this loads the normal view controller way.
        super.init(nibName: "STWebViewController", bundle: nil)
        
        // Fixes the web view appearing under the navigation bar in iOS 7+.
        self.edgesForExtendedLayout = .None
    }
    
    // The compiler is requiring me to implement this even though it won't be called.
    required init?(coder: NSCoder) {
        fatalError("NSCoder initialization not supported.")
    }
    
    override func viewDidLoad() {
        
        // Call parent method.
        super.viewDidLoad()
        
        // Set title.
        self.navigationItem.title = self.linkTitle
        
        // Should show the split view controller's display mode bar button item.
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        self.navigationItem.leftItemsSupplementBackButton = true
        
        // Start loading specified URL in web view.
        let newRequest = NSURLRequest(
            URL: self.url,
            cachePolicy: .ReturnCacheDataElseLoad,
            timeoutInterval: kDefaultTimeoutTimeInterval
        )
        self.webView?.loadRequest(newRequest)
    }
    
    deinit {
        // Need to unset our display mode button item to avoid a crash if the split view controller tries to access this view controller and it's gone.
        self.navigationItem.leftBarButtonItem = nil
    }
    
    // Shared functionality that happens when it's finished, whether it did so successfully or error'd out.
    func webViewDidFinishOrFailLoad(webView: UIWebView) {
        STAppDelegate.didStopNetworking()
        
        NSOperationQueue.mainQueue().addOperationWithBlock({
            MBProgressHUD.hideHUDForView(self.view, animated: true)
            return
        })
    }
    
    // MARK: - Web view delegate
    
    func webViewDidStartLoad(webView: UIWebView) {
        STAppDelegate.didStartNetworking()
        
        // Show progress indicator.
        MBProgressHUD.showHUDAddedTo(self.view, animated: true)
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        
        // Perform shared finished/failed functionality.
        self.webViewDidFinishOrFailLoad(webView)
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        
        // Perform shared finished/failed functionality.
        self.webViewDidFinishOrFailLoad(webView)
        
        // Create alert view to give notice to the user that the request failed.
        let newAlertView = UIAlertView()
        newAlertView.title = NSLocalizedString("Oops!", comment:"In the context of an error having occurrred.")
        newAlertView.message = NSLocalizedString("Unable to load schedule. Please try again later.", comment:"")
        newAlertView.addButtonWithTitle(NSLocalizedString("OK", comment:""))
        newAlertView.show()
    }
}
