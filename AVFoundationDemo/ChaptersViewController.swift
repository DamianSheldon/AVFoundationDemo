//
//  ChaptersViewController.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 13/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import UIKit

class ChaptersViewController: UITableViewController {

    // MARK: - Properties
    lazy var chapters = [
        "Playback",
        "Editing",
        "Capture",
    ]
    
    lazy var controllers: [String: UIViewController] = [
        "Playback": PlayerViewController(),
        "Editing" : EditingViewController(),
        "Capture": CaptureViewController(),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        title = "AVFoundationDemo"
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return chapters.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChapterCell", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = chapters[indexPath.row]
        
        return cell
    }

    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = chapters[indexPath.row]
        
        if let vc = controllers[key] {
            vc.title = key
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
