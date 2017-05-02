//
//  EditingViewController.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 14/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import AssetsLibrary

class EditingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Properties
    
    lazy var selectFirstVideoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Select First Video", for: .normal)
        button.addTarget(self, action: #selector(respondsToButtonTapped(sender:)), for: .touchUpInside)
        
        return button
    }()
    
    lazy var selectSecondVideoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Select Second Video", for: .normal)
        button.addTarget(self, action: #selector(respondsToButtonTapped(sender:)), for: .touchUpInside)
        
        return button
    }()
    
    lazy var exportButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Export Merge Video", for: .normal)
        button.addTarget(self, action: #selector(respondsToButtonTapped(sender:)), for: .touchUpInside)
        
        return button
    }()
    
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
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return formatter
    }()
    
    var currentTappedButton: UIButton?
    
    var firstVideoAsset: AVURLAsset?
    var secondVideoAsset: AVURLAsset?
    var audioAsset: AVURLAsset? {
        get {
            if let audioFileURL = Bundle.main.url(forResource: "ye_qu_jay_chou", withExtension: ".m4a") {
                return AVURLAsset(url: audioFileURL)
            }
            return nil
        }
    }
    
//    var mutableComposition: AVMutableComposition = AVMutableComposition()
//    var videoCompositionTrack: AVMutableCompositionTrack
//    var audioCompositionTrack: AVMutableCompositionTrack
    
    var mutableComposition: AVMutableComposition!
    var videoCompositionTrack: AVMutableCompositionTrack!
    var audioCompositionTrack: AVMutableCompositionTrack!
    
//    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
//        videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
//        audioCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
//        
//        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
//    }
//    
//    required init?(coder aDecoder: NSCoder) {
//        mutableComposition = aDecoder.decodeObject(forKey: "mutableComposition") as! AVMutableComposition
//        videoCompositionTrack = aDecoder.decodeObject(forKey: "videoCompositionTrack") as! AVMutableCompositionTrack
//        audioCompositionTrack = aDecoder.decodeObject(forKey: "audioCompositionTrack") as! AVMutableCompositionTrack
//        
//        super.init(coder: aDecoder)
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(selectFirstVideoButton)
        view.addSubview(selectSecondVideoButton)
        view.addSubview(exportButton)
        
        configureConstraintsForSelectFirstVideoButton()
        configureConstraintsForSelectSecondVideoButton()
        configureConstraintsForExportButton()
    }

    // MARK: - UIImagePickerViewControllerDelegate
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        switch currentTappedButton! {
        case selectFirstVideoButton, selectSecondVideoButton:
            let mediaType: String = info[UIImagePickerControllerMediaType] as! String
            
            if mediaType == kUTTypeMovie as String {
                if currentTappedButton === selectFirstVideoButton {
                    firstVideoAsset = AVURLAsset(url: info[UIImagePickerControllerMediaURL] as! URL, options: nil)
                }
                else if currentTappedButton === selectSecondVideoButton {
                    secondVideoAsset = AVURLAsset(url: info[UIImagePickerControllerMediaURL] as! URL, options: nil)
                }
            }
            else {
                print("Picked media isn't movie!")
            }
            
        default:
            break
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Event Responder
    
    @objc func respondsToButtonTapped(sender: UIButton) {
        currentTappedButton = sender
        
        switch sender {
        case selectFirstVideoButton, selectSecondVideoButton:
            if let mediaBrowser = mediaUI {
                present(mediaBrowser, animated: true, completion: nil)
            }
        
        case exportButton:
            if firstVideoAsset == nil {
                presentAlert(title: "Error!", message: "First Video Asset doesn't exist!")
            }
            else if secondVideoAsset == nil {
                presentAlert(title: "Error!", message: "Second Video Asset doesn't exist!")
            }
            else if audioAsset == nil {
                presentAlert(title: "Error!", message: "Audio Asset doesn't exist!")
            }
            else {
                let firstVideoAssetTrack = firstVideoAsset!.tracks(withMediaType: AVMediaTypeVideo)[0]
                let secondVideoAssetTrack = secondVideoAsset!.tracks(withMediaType: AVMediaTypeVideo)[0]
                
                var isFirstVideoPortrait = false
                
                let firstTransform = firstVideoAsset!.preferredTransform
                
                // Check the first video track's preferred transform to determine if it was recorded in portrait mode.
                if (firstTransform.a == 0 && firstTransform.d == 0 && (firstTransform.b == 1.0 || firstTransform.b == -1.0) && (firstTransform.c == 1.0 || firstTransform.c == -1.0)) {
                    isFirstVideoPortrait = true
                }
                
                var isSecondVideoPortrait = false
                let secondTransform = secondVideoAsset!.preferredTransform
                
                // Check the second video track's preferred transform to determine if it was recorded in portrait mode.
                if (secondTransform.a == 0 && secondTransform.d == 0 && (secondTransform.b == 1.0 || secondTransform.b == -1.0) && (secondTransform.c == 1.0 || secondTransform.c == -1.0)) {
                    isSecondVideoPortrait = true;
                }
                
                if ((isFirstVideoPortrait && !isSecondVideoPortrait) || (!isFirstVideoPortrait && isSecondVideoPortrait)) {
                    presentAlert(title: "Error!", message: "Cannot combine a video shot in portrait mode with a video shot in landscape mode.")
                    
                    break
                }
                
                do {
                    
                    mutableComposition = AVMutableComposition()
                    
                    videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
                    
                    audioCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    
                    try videoCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstVideoAssetTrack.timeRange.duration), of: firstVideoAssetTrack, at: kCMTimeZero)
                    try videoCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondVideoAssetTrack.timeRange.duration), of: secondVideoAssetTrack, at: firstVideoAssetTrack.timeRange.duration)
                    
                    try audioCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstVideoAssetTrack.timeRange.duration, secondVideoAssetTrack.timeRange.duration)), of: audioAsset!.tracks(withMediaType: AVMediaTypeAudio)[0], at: kCMTimeZero)
                    
                    // Applying the Video Composition Layer Instructions
                    let firstVideoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
                    firstVideoLayerInstruction.setTransform(firstVideoAssetTrack.preferredTransform, at: kCMTimeZero)
                    
                    let firstVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
                    
                    // Set the time range of the first instruction to span the duration of the first video track.
                    firstVideoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, firstVideoAssetTrack.timeRange.duration)
                    firstVideoCompositionInstruction.layerInstructions = [firstVideoLayerInstruction]
                    
                    let secondVideoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
                    secondVideoLayerInstruction.setTransform(secondVideoAssetTrack.preferredTransform, at: firstVideoAssetTrack.timeRange.duration)
                    
                    let secondVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
                    secondVideoCompositionInstruction.timeRange = CMTimeRangeMake(firstVideoAssetTrack.timeRange.duration, CMTimeAdd(firstVideoAssetTrack.timeRange.duration, secondVideoAssetTrack.timeRange.duration))
                    secondVideoCompositionInstruction.layerInstructions = [secondVideoLayerInstruction]
                    
                    let mutableVideoComposition = AVMutableVideoComposition()
                    mutableVideoComposition.instructions = [firstVideoCompositionInstruction, secondVideoCompositionInstruction]
                    
                    // Setting the Render Size and Frame Duration
                    var naturalSizeFirst: CGSize, naturalSizeSecond: CGSize
                    // If the first video asset was shot in portrait mode, then so was the second one if we made it here.
                    if isFirstVideoPortrait {
                        // Invert the width and height for the video tracks to ensure that they display properly.
                        naturalSizeFirst = CGSize(width: firstVideoAssetTrack.naturalSize.height, height: firstVideoAssetTrack.naturalSize.width)
                        
                        naturalSizeSecond = CGSize(width: secondVideoAssetTrack.naturalSize.height, height: secondVideoAssetTrack.naturalSize.width)
                    }
                    else {
                        // If the videos weren't shot in portrait mode, we can just use their natural sizes.
                        naturalSizeFirst = firstVideoAssetTrack.naturalSize
                        naturalSizeSecond = secondVideoAssetTrack.naturalSize
                    }
                    
                    // Set the renderWidth and renderHeight to the max of the two videos widths and heights.
                    var renderWidth: CGFloat, renderHeight: CGFloat
                    if naturalSizeFirst.width > naturalSizeSecond.width {
                        renderWidth = naturalSizeFirst.width
                    }
                    else {
                        renderWidth = naturalSizeSecond.width
                    }
                    
                    if naturalSizeFirst.height > naturalSizeSecond.height {
                        renderHeight = naturalSizeFirst.height
                    }
                    else {
                        renderHeight = naturalSizeSecond.height
                    }
                    
                    mutableVideoComposition.renderSize = CGSize(width: renderWidth, height: renderHeight)
                    mutableVideoComposition.frameDuration = CMTimeMake(1, 30)
                    
                    // Exporting the Composition and Saving it to the Camera Roll
                    // Create the export session with the composition and set the preset to the highest quality.
                    if let exporter = AVAssetExportSession(asset: mutableComposition, presetName: AVAssetExportPresetHighestQuality), let pathExtension = UTTypeCopyPreferredTagWithClass(AVFileTypeQuickTimeMovie as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as? String {
                        // Set the desired output URL for the file created by the export process.
                        do {
                            try exporter.outputURL = FileManager.`default`.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(dateFormatter.string(from: NSDate() as Date)).appendingPathExtension(pathExtension)
                            
                            // Set the output file type to be a QuickTime movie.
                            exporter.outputFileType = AVFileTypeQuickTimeMovie
                            exporter.shouldOptimizeForNetworkUse = true
                            exporter.videoComposition = mutableVideoComposition
                            
                            // Asynchronously export the composition to a video file and save this file to the camera roll once export completes.
                            exporter.exportAsynchronously(completionHandler: {
                                DispatchQueue.main.async {
                                    if exporter.status == .completed {
                                        let assetsLibrary = ALAssetsLibrary()
                                        if assetsLibrary.videoAtPathIs(compatibleWithSavedPhotosAlbum:exporter.outputURL) {
                                            assetsLibrary.writeVideoAtPath(toSavedPhotosAlbum: exporter.outputURL, completionBlock:{ [unowned self] (outputURL: URL?, error: Error?) -> Void in
                                                
                                                if error != nil {
                                                    self.presentAlert(title: "Error!", message: error!.localizedDescription)
                                                }
                                                else {
                                                    self.presentAlert(title: "Success", message: "Write video to photos album successfully!")
                                                }
                                            })
                                        }
                                    }
                                    else {
                                        self.presentAlert(title: "Error", message: "Export failed with status: \(exporter.status.rawValue), error: \(exporter.error) message: \(exporter.error?.localizedDescription) ")
                                    }
                                }
                            })
                        } catch let error as NSError {
                            presentAlert(title: "Error!", message: error.localizedDescription)
                        }
                        
                    }
                    else {
                        // #Error Instanlation asset failed!
                        presentAlert(title: "Error!", message: "Instanlation asset failed!")
                    }
                    
                } catch let error as NSError {
                    presentAlert(title: "Error!", message: error.localizedDescription)
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    func configureConstraintsForSelectFirstVideoButton() {
        view.addConstraint(NSLayoutConstraint(item: selectFirstVideoButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: selectFirstVideoButton, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: 20))
    }
    
    func configureConstraintsForSelectSecondVideoButton() {
        view.addConstraint(NSLayoutConstraint(item: selectSecondVideoButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: selectSecondVideoButton, attribute: .top, relatedBy: .equal, toItem: selectFirstVideoButton, attribute: .bottom, multiplier: 1.0, constant: 20))
    }
    
    func configureConstraintsForExportButton() {
        view.addConstraint(NSLayoutConstraint(item: exportButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: exportButton, attribute: .top, relatedBy: .equal, toItem: selectSecondVideoButton, attribute: .bottom, multiplier: 1.0, constant: 20))
    }
}
