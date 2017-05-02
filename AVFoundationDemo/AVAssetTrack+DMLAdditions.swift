//
//  AVAssetTrack+DMLAdditions.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 14/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAssetTrack {
    open class func isCompatibleVideoOrientation(firstVideoAsset: AVAssetTrack, secondVideoAsset: AVAssetTrack) -> Bool {
        var isFirstVideoPortrait = false
        let firstTransform = firstVideoAsset.preferredTransform
        
        // Check the first video track's preferred transform to determine if it was recorded in portrait mode.
        if (firstTransform.a == 0 && firstTransform.d == 0 && (firstTransform.b == 1.0 || firstTransform.b == -1.0) && (firstTransform.c == 1.0 || firstTransform.c == -1.0)) {
            isFirstVideoPortrait = true
        }
        
        var isSecondVideoPortrait = false
        let secondTransform = secondVideoAsset.preferredTransform
        
        // Check the second video track's preferred transform to determine if it was recorded in portrait mode.
        if (secondTransform.a == 0 && secondTransform.d == 0 && (secondTransform.b == 1.0 || secondTransform.b == -1.0) && (secondTransform.c == 1.0 || secondTransform.c == -1.0)) {
            isSecondVideoPortrait = true;
        }
        
        if ((isFirstVideoPortrait && !isSecondVideoPortrait) || (!isFirstVideoPortrait && isSecondVideoPortrait)) {
            return false;
        }
        
        return true
    }
}
