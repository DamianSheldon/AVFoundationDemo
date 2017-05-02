//
//  PlayerView.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 13/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var player: AVPlayer? {
        get {
            let playerLayer: AVPlayerLayer = self.layer as! AVPlayerLayer
            
            return playerLayer.player
        }
        set {
            let playerLayer: AVPlayerLayer = self.layer as! AVPlayerLayer

            playerLayer.player = newValue
        }
    }
    
}
