//
//  AVAssetWriterHelper.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 31/03/2017.
//  Copyright © 2017 Meiliang Dong. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox

open class AVAssetWriterHelper {
    open var assertWriter: AVAssetWriter?
    open var assertWriterInput: AVAssetWriterInput?
    open var outputFileURL: URL?
    
    init() {
        let possibleURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        if possibleURLs.count > 0 {
            var fileURL = possibleURLs.first!
            
            fileURL = fileURL.appendingPathComponent(UUID().uuidString)
            
            fileURL = fileURL.appendingPathExtension(".mp4")
            
            self.outputFileURL = fileURL
            
            do {
                let assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: AVFileTypeMPEG4)
                
                self.assertWriter = assetWriter
                
                // Setting Up the Asset Writer Inputs
                /*
                 after outputSettingsOptional([AnyHashable("AVVideoCodecKey"): avc1, AnyHashable("AVVideoHeightKey"): 944, AnyHashable("AVVideoCompressionPropertiesKey"): {
                 
                 AverageBitRate = 700000;
                 
                 ExpectedFrameRate = 30;
                 
                 MaxKeyFrameIntervalDuration = 1;
                 
                 Priority = 80;
                 
                 ProfileLevel = "H264_Baseline_3_0";
                 
                 RealTime = 1;
                 
                 }, AnyHashable("AVVideoWidthKey"): 540])
                 */
                
                let videoCompressionProperties = [
                    AVVideoAverageBitRateKey: NSNumber(value: 700000),
                    AVVideoExpectedSourceFrameRateKey: NSNumber(value: 30),
                    AVVideoMaxKeyFrameIntervalDurationKey: NSNumber(value: 1),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
                    kVTCompressionPropertyKey_RealTime as String: kCFBooleanTrue
                    ] as [String : Any]
                
                
                let settings = [
                    AVVideoCodecKey: AVVideoCodecH264,
                    AVVideoHeightKey: NSNumber(value: 944),
                    AVVideoWidthKey: NSNumber(value: 540),
                    AVVideoCompressionPropertiesKey: videoCompressionProperties
                ] as [String : Any]
                
                print("outputSetings:\(settings)")
                
//                let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: [
//                    AVVideoCodecKey: AVVideoCodecH264,
//                    AVVideoHeightKey: NSNumber(value: 944),
//                    AVVideoWidthKey: NSNumber(value: 540),
//                    AVVideoCompressionPropertiesKey: videoCompressionProperties
//                    ])
                
                let availableOutputSettingsPresets = AVOutputSettingsAssistant.availableOutputSettingsPresets()
                
                if availableOutputSettingsPresets.count < 1 {
                    print("There isn't availableOutputSettingsPresets for out put settings")
                    return
                }
                
                print("availableOutputSettingsPresets:\(availableOutputSettingsPresets)\n")
                
                guard let settingsAssistant = AVOutputSettingsAssistant(preset: availableOutputSettingsPresets.first!) else {
                    print("Instance AVOutputSettingsAssistant failed")
                    return
                }
                
                let outputSettings = settingsAssistant.videoSettings
                print("outputSettings:\(outputSettings)")
                
                let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
                
                assetWriterInput.expectsMediaDataInRealTime = true
                
                if assetWriter.canAdd(assetWriterInput) {
                    assetWriter.add(assetWriterInput)
                    
                    self.assertWriterInput = assetWriterInput
                }
                else {
                    print("asset writer can't add asset writer input\n")
                }
                
            } catch {
                print("Instantion asset write failed: \(error)")
            }
            
        }
        else {
            print("There isn't possible URLs in document directory!")
        }

    }
}
