//
//  UIInterfaceOrientation+DMLAdditions.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 16/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}
