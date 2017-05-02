//
//  ViewController.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 13/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

class PlayerViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Properties
    var playerItemContext: Int = 0
    
    var player: AVPlayer? {
        didSet {
            playerView.player = player
        }
    }
    
    var playerItem: AVPlayerItem?
    
    lazy var playerView: PlayerView = {
        let playerView = PlayerView(frame: .zero)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        
        return playerView
    }()
    
    lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.red, for: .normal)
        button.setTitle("Play", for: .normal)
        
        button.addTarget(self, action: #selector(respondsToPlayButton), for: .touchUpInside)
        return button
    }()
    
    var asset: AVURLAsset?
    lazy var mediaUI: UIImagePickerController? = {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            let mediaUI = UIImagePickerController()
            mediaUI.sourceType = .savedPhotosAlbum
            mediaUI.mediaTypes = [kUTTypeMovie as String]
            
            mediaUI.delegate = self
            
            return mediaUI
        }
        else {
            return nil
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Load Asset", style: .plain, target: self, action: #selector(respondsToLoadAsset))
        
        view.addSubview(playerView)
        view.addSubview(playButton)
        
        configureConstraintsForPlayerView()
        configureConstraintsForPlayerButton()
        
        syncUI()
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItemStatus
            
            // Get the status change from the change dictionary
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            }
            else {
                status = .unknown
            }
            
            // Switch over the status
            switch status {
            case .readyToPlay:
                DispatchQueue.main.async {
                    self.syncUI()
                }
            case .failed:
            // Player item failed. See error.
                print("Failed to prepare asset player item to play!")
            case .unknown:
                // Player item is not yet ready.
                print("Status for prepare asset player item to play is unknown!")
            }
        }
    }
    
    // MARK: - Event Responder
    
    @objc func respondsToLoadAsset() -> Void {
        if mediaUI != nil {
            present(mediaUI!, animated: true, completion: nil)
        }
        else {
            print("Unable to access to save photo album")
        }
    }
    
    @objc func respondsToPlayButton() -> Void {
        if let p = player {
            if p.rate > 0 {
                p.pause()
                
                playButton.setTitle("Play", for: .normal)
            }
            else {
                p.play()
                
                playButton.setTitle("Pause", for: .normal)
            }
        }
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) -> Void {
        player?.seek(to: kCMTimeZero)
        
        playButton.setTitle("Play", for: .normal)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let mediaType: String = info[UIImagePickerControllerMediaType] as! String
        
        if mediaType == kUTTypeMovie as String {
            asset = AVURLAsset(url: info[UIImagePickerControllerMediaURL] as! URL, options: nil)
            
            if asset != nil {
                let tracksKey = "tracks"
                asset?.loadValuesAsynchronously(forKeys: [tracksKey], completionHandler: {
                    DispatchQueue.main.async(execute: {
                        [unowned self] in

                        let assetKeys = [
                            "playable",
                            "hasProtectedContent"
                        ]
                        // Create a new AVPlayerItem with the asset and an
                        // array of asset keys to be automatically loaded
                        self.playerItem = AVPlayerItem(asset: self.asset!,
                                                       automaticallyLoadedAssetKeys: assetKeys)
                        
                        // Register as an observer of the player item's status property
                        self.playerItem?.addObserver(self,
                                                     forKeyPath: #keyPath(AVPlayerItem.status),
                                                     options: [.old, .new],
                                                     context: &self.playerItemContext)
                        
                        NotificationCenter.`default`.addObserver(self, selector: #selector(self.playerItemDidReachEnd(notification:)), name: .AVPlayerItemDidPlayToEndTime, object: self.playerItem)
                        
                        // Associate the player item with the player
                        self.player = AVPlayer(playerItem: self.playerItem)
                    })
                })
            }
            else {
                print("Instance asset failed!")
            }
            
        }
        else {
            print("Picked media isn't movie!")
        }
        
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Private Methods
    func configureConstraintsForPlayerView() -> Void {
        view.addConstraint(NSLayoutConstraint(item: playerView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: playerView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: playerView, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: playerView, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0))
    }
    
    func configureConstraintsForPlayerButton() -> Void {
        view.addConstraint(NSLayoutConstraint(item: playButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: playButton, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0))
    }
    
    func syncUI() -> Void {
        if player?.currentItem != nil && player?.currentItem?.status == .readyToPlay {
            playButton.isEnabled = true
        }
        else {
            playButton.isEnabled = false
        }
    }
}

