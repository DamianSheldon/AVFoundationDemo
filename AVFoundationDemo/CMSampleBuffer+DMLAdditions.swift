//
//  CMSampleBuffer+DMLAdditions.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 19/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import Foundation
import UIKit
import CoreMedia

extension CMSampleBuffer {
    // Create a UIImage from sample buffer data
    open static func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        
        // Create a Quartz image from the pixel data in the bitmap graphics context
        guard let quartzImage = context.makeImage() else {
            return nil
        }
        
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer,CVPixelBufferLockFlags(rawValue: 0))
        
        // Create an image object from the Quartz image
        let image = UIImage(cgImage: quartzImage)
        
        return image
    }
}
