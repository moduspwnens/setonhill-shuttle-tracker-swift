//
//  STWebViewController.swift
//  Shuttle Tracker (Swift)
//
//  Created by Benn Linger on 2/4/15.
//  Copyright (c) 2015 Seton Hill University. All rights reserved.
//

import WebKit

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
    required init(coder: NSCoder) {
        fatalError("NSCoder initialization not supported.")
    }
    
    override func viewDidLoad() {
        
        // Call parent method.
        super.viewDidLoad()
        
        // Set title.
        self.navigationItem.title = self.linkTitle
        
        // Start loading specified URL in web view.
        let newRequest = NSURLRequest(
            URL: self.url,
            cachePolicy: .ReturnCacheDataElseLoad,
            timeoutInterval: kDefaultTimeoutTimeInterval
        )
        self.webView?.loadRequest(newRequest)
    }
    
    // MARK: - Web view delegate
    
    func webViewDidStartLoad(webView: UIWebView) {
        STAppDelegate.didStartNetworking()
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        STAppDelegate.didStopNetworking()
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        STAppDelegate.didStopNetworking()
        
        let newAlertView = UIAlertView()
        newAlertView.title = NSLocalizedString("Oops!", comment:"In the context of an error having occurrred.")
        newAlertView.message = NSLocalizedString("Unable to load schedule. Please try again later.", comment:"")
        newAlertView.delegate = self
        newAlertView.addButtonWithTitle(NSLocalizedString("OK", comment:""))
        newAlertView.show()
    }
    
    // MARK: - Alert view delegate
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        self.navigationController?.popViewControllerAnimated(true)
    }
}
