//
//  CaptureViewController.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 16/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: Properties
    var previewView = PreviewView()
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil) // Communicate with the session and other session objects on this queue.
    
    private let sampleBufferCallbackQueue = DispatchQueue(label: "sampleBufferCallbackQueue")
    
    private var setupResult: SessionSetupResult = .success
    
    private var movieSetupResult: SessionSetupResult = .success
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    var videoDeviceInput: AVCaptureDeviceInput!

    private var captureEnable = false
    private var isCapturing = false
    
    private var recordingEndTime = Date.distantPast
    
    fileprivate var exporter: AVAssetExportSession!

    let photoAndVideoSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["Photo", "Video"])
        segmentedControl.sizeToFit()
        segmentedControl.addTarget(self, action: #selector(respondsToPhotoAndVideoSegmentedControl), for: .valueChanged)
        segmentedControl.selectedSegmentIndex = 0
        
        return segmentedControl
    }()
    
    let movieFileOutput: AVCaptureMovieFileOutput = {
        let aMovieFileOutput = AVCaptureMovieFileOutput()
        aMovieFileOutput.maxRecordedDuration = CMTimeMake(60, 1)
        aMovieFileOutput.minFreeDiskSpaceLimit = Int64(20 * 1024 * 1024)
        
        return aMovieFileOutput
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Capture", style: .plain, target: self, action: #selector(respondsToCapture))
        
        // Set up the video preview view.
        previewView.session = session
        
        view.addSubview(previewView)
        configureConstraintsForPreviewView()
        
        /*
         Check video authorization status. Video access is required and audio
         access is optional. If audio access is denied, audio is not recorded
         during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async { [unowned self] in
            self.configureSession()
        }
        
        navigationItem.titleView = photoAndVideoSegmentedControl
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("AVFoundationDemo doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVFoundationDemo", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                        if #available(iOS 10.0, *) {
                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                        } else {
                            // Fallback on earlier versions
                        }
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                    let alertController = UIAlertController(title: "AVFoundationDemo", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: Event Responder
    @objc func respondsToCapture() {
        
        if photoAndVideoSegmentedControl.selectedSegmentIndex == 0 {
            captureEnable = true
            recordingEndTime = Date().addingTimeInterval(60)
        }
        else {
            // Record a video
            if movieFileOutput.isRecording {
                return
            }
            
            if setupResult != .notAuthorized, movieSetupResult != .success {
                print("set up failed: setupResult\(setupResult)\nmovieSetupResult\(movieSetupResult)")
                return
            }
            
            let possibleURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            
            if possibleURLs.count > 0 {
                var fileURL = possibleURLs.first!
                
                fileURL = fileURL.appendingPathComponent(UUID().uuidString)
                
                fileURL = fileURL.appendingPathExtension("mp4")
                
                movieFileOutput.startRecording(toOutputFileURL: fileURL, recordingDelegate: self)
                
                // Set up timer
                Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(respondsToRecordTimerFired), userInfo: nil, repeats: false)
            }
            else {
                print("There isn't possible URLs in document directory!")
            }
        }
    }
    
    @objc func respondsToPhotoAndVideoSegmentedControl() {
        
    }
    
    @objc func respondsToRecordTimerFired() {
        movieFileOutput.stopRecording()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    var assetWriterHelper: AVAssetWriterHelper?
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if captureEnable {
//            isCapturing = true
            
            let resetCaptureState = {
                DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                    [unowned self] in
                    self.assetWriterHelper = nil
                    
                    self.captureEnable = false
                    self.recordingEndTime = Date.distantPast
                    self.isCapturing = false

                })
            }
            
            // Writing Media Data
            if assetWriterHelper == nil {
                assetWriterHelper = AVAssetWriterHelper()
            }
            
            if assetWriterHelper!.assertWriter == nil || assetWriterHelper!.assertWriterInput == nil {
                
                print("assertWriter or assertWriterInput is nil")
                resetCaptureState()
                return
            }
            
            if !isCapturing {
                isCapturing = true
                // Prepare the asset writer for writing.

                assetWriterHelper!.assertWriter!.startWriting()
                
                // Start a sample-writing session.
                assetWriterHelper!.assertWriter!.startSession(atSourceTime: kCMTimeZero)
            }
            
            if assetWriterHelper!.assertWriterInput!.isReadyForMoreMediaData {
                if Date() < recordingEndTime {
                    if assetWriterHelper!.assertWriterInput!.append(sampleBuffer) {
                        print("append sampleBuffer success!\n")
                    }
                    else {
                        print("append sampleBuffer status:\(assetWriterHelper!.assertWriter!.status.rawValue) error:\(assetWriterHelper!.assertWriter!.error)")
                    }
                }
                else {
                    assetWriterHelper!.assertWriterInput!.markAsFinished()
                    
                    assetWriterHelper!.assertWriter!.finishWriting { [unowned self] in
                        switch(self.assetWriterHelper!.assertWriter!.status) {
                        case .unknown:
                                print("unknow:\(self.assetWriterHelper!.assertWriter!.error)")
                                resetCaptureState()

                        case .writing:
                                print("writing:\(self.assetWriterHelper!.assertWriter!.error)")
                                resetCaptureState()

                        case .failed:
                                print("failed:\(self.assetWriterHelper!.assertWriter!.error)")
                                resetCaptureState()

                        case .cancelled:
                                print("cancelled:\(self.assetWriterHelper!.assertWriter!.error)")
                                resetCaptureState()

                        case .completed:
                            
                                let destinationFileURL = self.assetWriterHelper!.outputFileURL!
                                
                                let exportVideoToPhotoLibrary = {
                                    // Export video to Photos
                                    PHPhotoLibrary.shared().performChanges({
                                        // Request creating an asset from the image.
                                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationFileURL)
                                        
                                    }, completionHandler: { success, error in
                                        
                                        if !success {
                                            NSLog("error creating video asset: \(error)")
                                        }
                                        else {
                                            print("Export video asset successfully!")
                                        }
                                    })
                                }
                                
                                resetCaptureState()
                                
                                // Export video to Photo Library if app has permission to access Photo Library otherwise request allow
                                if PHPhotoLibrary.authorizationStatus() != .authorized {
                                    PHPhotoLibrary.requestAuthorization({ (authorizationStatus: PHAuthorizationStatus) in
                                        if authorizationStatus == .authorized {
                                            exportVideoToPhotoLibrary()
                                        }
                                    })
                                }
                                else {
                                    exportVideoToPhotoLibrary()
                            }
                        }
                    }
                }
            }
            else {
                print("assetWriterHelper!.assertWriterInput!.isReadyForMoreMediaData false\n")
            }
            
//            guard let image = CMSampleBuffer.imageFromSampleBuffer(sampleBuffer) else {
//                resetCaptureState()
//                print("Create image from CMSampleBuffer failed!")
//                return
//            }
//            
//            let exportImageToPhotoLibrary = {
//                // Export image to Photos
//                PHPhotoLibrary.shared().performChanges({
//                    // Request creating an asset from the image.
//                    PHAssetChangeRequest.creationRequestForAsset(from: image)
//                }, completionHandler: { [unowned self] success, error in
//                    self.isCapturing = false
//                    if !success {
//                        NSLog("error creating asset: \(error)")
//                    }
//                    else {
//                        print("Export asset successfully!")
//                    }
//                })
//            }
//            
//            
//            // Export image to Photo Library if app has permission to access Photo Library otherwise request allow
//            if PHPhotoLibrary.authorizationStatus() != .authorized {
//                PHPhotoLibrary.requestAuthorization({ (authorizationStatus: PHAuthorizationStatus) in
//                    if authorizationStatus == .authorized {
//                        exportImageToPhotoLibrary()
//                    }
//                })
//            }
//            else {
//                exportImageToPhotoLibrary()
//            }
        }
    }
    
    // MARK: Private Methods
    func configureConstraintsForPreviewView() -> Void {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addConstraint(NSLayoutConstraint(item: previewView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: previewView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: previewView, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: previewView, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0))
    }
    
    // Call this on the session queue.
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        /*
         We do not create an AVCaptureMovieFileOutput when setting up the session because the
         AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto.
         */
        if (session.canSetSessionPreset(AVCaptureSessionPresetMedium)) {
            session.sessionPreset = AVCaptureSessionPresetMedium
        }
        
        // Add video input.
        do {
            let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            
            if videoDevice == nil {
                print("There isn't video capture device!")
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice!)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    /*
                     Why are we dispatching this to the main queue?
                     Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
                     can only be manipulated on the main thread.
                     Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.previewView.videoPreviewLayer.connection.videoOrientation = initialVideoOrientation
                }
            }
            else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add video data output.
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
//            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA]
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA]

//            videoDataOutput.videoSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(withOutputFileType: AVFileTypeMPEG4)
//            videoDataOutput.minFrameDuration = CMTimeMake(1, 15)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            
            let captureConnection = videoDataOutput.connection(withMediaType: AVMediaTypeVideo)
            
            if captureConnection!.isVideoOrientationSupported {
                captureConnection!.videoOrientation = AVCaptureVideoOrientation.portrait
            }
            else {
                print("capture connection\(captureConnection!) doesn't support video orientation")
            }

        }
        else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add movie file output
//        if session.canAddOutput(movieFileOutput) {
//            session.addOutput(movieFileOutput)
//            
////            if #available(iOS 10.0, *) {
////                let captureConnection = movieFileOutput.connection(withMediaType: AVMediaTypeVideo)
////
////                var outputSettings = movieFileOutput.outputSettings(for: captureConnection)
////                
////                print("before outputSettings\(outputSettings)\n")
////                
////                outputSettings![AVVideoWidthKey] = NSNumber(value: 540)
////                outputSettings![AVVideoHeightKey] = NSNumber(value: 944)
////                
////                print("after outputSettings\(outputSettings)\n")
////
////                movieFileOutput.setOutputSettings(outputSettings!, for: captureConnection)
////                
////            } else {
////                // Fallback on earlier versions
////            }
//            
//        }
//        else {
//            movieSetupResult = .configurationFailed
//        }
        
        session.commitConfiguration()
    }
    
    var exportCommand: AVSEExportCommand?
}

extension CaptureViewController: AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        
        // Check for any errors that might have occurred
        var recordedSuccessfully = true
        
        var aNSError: NSError = NSError(domain: NSCocoaErrorDomain, code: NSNotFound, userInfo: nil)
        
        if (error != nil) {
            aNSError = error! as NSError
            
            if aNSError.code != 0 {
                if let value = aNSError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? NSNumber {
                    recordedSuccessfully = value.boolValue
                }
            }
        }
        
        // Write the resulting movie to the Camera Roll album
        guard recordedSuccessfully else {
            print("Record video failed:\(aNSError.localizedDescription)")
            return
        }
        
        // Editing
        let cropCommand = AVSECropCommand()
        
        cropCommand.perform(with: AVURLAsset(url: outputFileURL, options: nil))
        
        var audioMix: AVMutableAudioMix!
        
        exportCommand = AVSEExportCommand(composition: cropCommand.mutableComposition, videoComposition: cropCommand.mutableVideoComposition, audioMix: audioMix)
        
        if exportCommand != nil {
            var asset: AVAsset!
            
            exportCommand!.perform(with: asset)
        }
        else {
            print("Instance exportCommand failed\n")
        }
        
        // Creating the Composition
//        let mutableComposition = AVMutableComposition()
//        
//        let videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
//        
//        let audioCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
//        
//        // Adding the Assets
//        let videoAsset = AVAsset(url: outputFileURL)
//        
//        if !videoAsset.isComposable {
//            print("Video asset isn't composable!\n")
//            
//            return
//        }
//        
//        let videoAssetTrack = videoAsset.tracks(withMediaType: AVMediaTypeVideo).first!
//        
//        let audioAssetTrack = videoAsset.tracks(withMediaType: AVMediaTypeAudio).first
//        
//        do {
//            try videoCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, videoAsset.duration), of: videoAssetTrack, at: kCMTimeZero)
//            
//            if audioAssetTrack != nil {
//                try audioCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, videoAsset.duration), of: audioAssetTrack!, at: kCMTimeZero)
//            }
//            
//            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
//            layerInstruction.setTransform(videoAsset.preferredTransform, at: kCMTimeZero)
//            
//            let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
////            videoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoAssetTrack.timeRange.duration)
//            videoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, mutableComposition.duration)
//            videoCompositionInstruction.layerInstructions = [layerInstruction]
//            
//            let mutableVideoComposition = AVMutableVideoComposition()
//            
//            mutableVideoComposition.renderSize = CGSize(width: 540, height: 944)
//            //            mutableVideoComposition.renderSize = videoAssetTrack.naturalSize
//            
//            // Set the frame duration to an appropriate value (i.e. 30 frames per second for video).
//            mutableVideoComposition.frameDuration = CMTimeMake(1, 30)
//            
//            mutableVideoComposition.instructions = [videoCompositionInstruction]
//            
//            let presetNames = AVAssetExportSession.exportPresets(compatibleWith: mutableComposition)
//            
//            if presetNames.count < 1 {
//                print("There isn't compatible preset with this asset\n")
//                
//                return
//            }
//            
//            print("Compatible presets:\(presetNames)")
//            
//            if let exporter = AVAssetExportSession(asset: mutableComposition, presetName: /*presetNames[0]*/AVAssetExportPreset1920x1080) {
//                exporter.outputURL = FileManager.UUIDFileURLWithMPEG4TypeUnderDocument()
//                
//                self.exporter = exporter
//                
//                if exporter.outputURL == nil {
//                    print("exporter.outputURL is nil\n")
//                    return
//                }
//                
//                exporter.outputFileType = AVFileTypeMPEG4
////                exporter.outputFileType = AVFileTypeQuickTimeMovie
//
////                exporter.shouldOptimizeForNetworkUse = true
//                exporter.videoComposition = mutableVideoComposition
//                
//                let exportVideoToPhotoLibrary = {
//                    // Export video to Photos
//                    PHPhotoLibrary.shared().performChanges({
//                        // Request creating an asset from the image.
//                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: exporter.outputURL!)
//                    }, completionHandler: { success, error in
//                        if !success {
//                            NSLog("error creating video asset: \(error)")
//                        }
//                        else {
//                            print("Export video asset successfully!")
//                        }
//                    })
//                }
//                
//                exporter.exportAsynchronously {
//                    
//                    switch(exporter.status) {
//                        case .unknown:
//                            print("Status: unknow\n");
//                        
//                        case .waiting:
//                            print("Status: waiting\n");
//
//                        case .exporting:
//                            print("Status: exporting\n");
//
//                        case .completed:
//                            // Export video to Photo Library if app has permission to access Photo Library otherwise request allow
//                            if PHPhotoLibrary.authorizationStatus() != .authorized {
//                                PHPhotoLibrary.requestAuthorization({ (authorizationStatus: PHAuthorizationStatus) in
//                                    if authorizationStatus == .authorized {
//                                        exportVideoToPhotoLibrary()
//                                    }
//                                })
//                            }
//                            else {
//                                exportVideoToPhotoLibrary()
//                            }
//                        case .failed:
//                            print("failed:\(exporter.error)\n")
//
//                        case .cancelled:
//                            print("cancelled:\(exporter.error)\n")
//
//                    }
//                }
//            }
//            else {
//                print("Instance AVAssetExportSession failed\n")
//            }
//            
//        } catch  {
//            print("insertTimeRange error:\(error)\n")
//            
//            return
//        }
        
//        // Write the resulting movie to the Camera Roll album
//        guard recordedSuccessfully else {
//            print("Record video failed:\(aNSError.localizedDescription)")
//            return
//        }
//        
//        let exportVideoToPhotoLibrary = {
//            // Export video to Photos
//            PHPhotoLibrary.shared().performChanges({
//                // Request creating an asset from the image.
//                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
//            }, completionHandler: { success, error in
//                if !success {
//                    NSLog("error creating video asset: \(error)")
//                }
//                else {
//                    print("Export video asset successfully!")
//                }
//            })
//        }
//        
//        
//        // Export video to Photo Library if app has permission to access Photo Library otherwise request allow
//        if PHPhotoLibrary.authorizationStatus() != .authorized {
//            PHPhotoLibrary.requestAuthorization({ (authorizationStatus: PHAuthorizationStatus) in
//                if authorizationStatus == .authorized {
//                    exportVideoToPhotoLibrary()
//                }
//            })
//        }
//        else {
//            exportVideoToPhotoLibrary()
//        }
    }
}
