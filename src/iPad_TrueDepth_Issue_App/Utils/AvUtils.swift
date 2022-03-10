//
//  AvUtils.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit
import AVFoundation
import VideoToolbox

/**
 This file provides some extensions for easier access to AV data.
 */

extension CVPixelBuffer{
    var uiImage: UIImage {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        return UIImage.init(cgImage: cgImage!)
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        if let image = cgImage {
            self.init(cgImage: image)
        } else {
            return nil
        }
    }
}

extension ARCamera.TrackingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Not Available"
        case .limited(.initializing):
            return "Initializing"
        case .limited(.excessiveMotion):
            return "Excessive Motion"
        case .limited(.insufficientFeatures):
            return "Insufficient Features"
        case .limited(.relocalizing):
            return "Relocalizing"
        case .limited:
            return "Unspecified Reason"
        }
    }
}

extension AVCaptureDevice.Format.AutoFocusSystem {
    public var description: String {
        switch self {
        case .none:
            return "None"
        case .contrastDetection:
            return "ContrastDetection"
        case .phaseDetection:
            return "PhaseDetection"
        default:
            return "unknown"
        }
    }
}
