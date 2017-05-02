//
//  FileManager+DMLAdditions.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 01/04/2017.
//  Copyright © 2017 Meiliang Dong. All rights reserved.
//

import Foundation

extension FileManager {
    
    static func UUIDFileURLWithMPEG4TypeUnderDocument() -> URL? {
        let possibleURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        if possibleURLs.count > 0 {
            var fileURL = possibleURLs.first!
            
            fileURL = fileURL.appendingPathComponent(UUID().uuidString)
            
            fileURL = fileURL.appendingPathExtension("mp4")
            
            return fileURL
        }
        else {
            print("There isn't possible URLs in document directory!")
            return nil
        }
    }
}
