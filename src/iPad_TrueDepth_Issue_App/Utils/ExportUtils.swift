//
//  ExportUtils.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit
import ARKit
import VideoToolbox

/**
 This class provides utility methods for saving camera images & metadata.
 */
class ExportUtils: NSObject {
    private static let DEPTH_COLOR_SPACE = "Gray"

    public static func convertLensDistortionLookupTable(lookupTable: Data) -> [Float] {
        let tableLength = lookupTable.count / MemoryLayout<Float>.size
        var floatArray: [Float] = Array(repeating: 0, count: tableLength)
        _ = floatArray.withUnsafeMutableBytes{lookupTable.copyBytes(to: $0)}
        return floatArray
    }

    public static func getDepthMetadataJson(_ depthData: AVDepthData, bitsPerComponent: Int,
                                            timeStamp: Int64) -> String {
        let stringOfSimd3 = SensorUtils.stringOfSimd3
        let stringOfSimd4 = SensorUtils.stringOfSimd4
        let dict : NSMutableDictionary = NSMutableDictionary()

        let pixelBuffer = depthData.depthDataMap
        var depthFormatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                      imageBuffer: pixelBuffer,
                                                      formatDescriptionOut: &depthFormatDescription)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        dict.setValue(timeStamp, forKey: "Timestamp")
        dict.setValue(depthData.cameraCalibrationData!.lensDistortionCenter.debugDescription, forKey: "LensDistortionCenter")
        dict.setValue(convertLensDistortionLookupTable(lookupTable: depthData.cameraCalibrationData!.lensDistortionLookupTable!), forKey: "LensDistortionLookupTable")
        dict.setValue(convertLensDistortionLookupTable(lookupTable: depthData.cameraCalibrationData!.inverseLensDistortionLookupTable!), forKey: "LensDistortionInverseLookupTable")

        dict.setValue(depthData.cameraCalibrationData!.pixelSize, forKey: "PixelSize")
        dict.setValue(depthData.cameraCalibrationData!.intrinsicMatrixReferenceDimensions.debugDescription, forKey: "IntrinsicMatrixReferenceDimensions")
        let refX = Float(depthData.cameraCalibrationData!.intrinsicMatrixReferenceDimensions.width) / Float(depthFormatDescription!.dimensions.width)
        let refY = Float(depthData.cameraCalibrationData!.intrinsicMatrixReferenceDimensions.height) / Float(depthFormatDescription!.dimensions.height)

        let px = depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.0.z / refX
        let py = depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.1.z / refY
        let fx = depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.0.x / refX
        let fy = depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.1.y / refY
        var intrinsicMatrix0 = simd_make_float3(depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.0)
        intrinsicMatrix0.z = px
        intrinsicMatrix0.x = fx
        var intrinsicMatrix1 = simd_make_float3(depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.1)
        intrinsicMatrix1.z = py
        intrinsicMatrix1.y = fy
        let intrinsicMatrix2 = simd_make_float3(depthData.cameraCalibrationData!.intrinsicMatrix.transpose.columns.2)

        // Row major
        dict.setValue(stringOfSimd3(intrinsicMatrix0), forKey: "IntrinsicMatrix.0")
        dict.setValue(stringOfSimd3(intrinsicMatrix1), forKey: "IntrinsicMatrix.1")
        dict.setValue(stringOfSimd3(intrinsicMatrix2), forKey: "IntrinsicMatrix.2")

        dict.setValue(stringOfSimd4(depthData.cameraCalibrationData!.extrinsicMatrix.transpose.columns.0),
                      forKey: "ExtrinsicMatrix.0")
        dict.setValue(stringOfSimd4(depthData.cameraCalibrationData!.extrinsicMatrix.transpose.columns.1),
                      forKey: "ExtrinsicMatrix.1")
        dict.setValue(stringOfSimd4(depthData.cameraCalibrationData!.extrinsicMatrix.transpose.columns.2),
                      forKey: "ExtrinsicMatrix.2")

        dict.setValue(depthData.depthDataAccuracy.rawValue, forKey: "Accuracy") //absolute (wrt phy world) = 1
        dict.setValue(depthData.depthDataQuality.rawValue, forKey: "Quality")   //high = 1
        dict.setValue(depthData.depthDataType, forKey: "DataType")  //DepthFloat32 = 1717855600
        dict.setValue(depthData.isDepthDataFiltered, forKey: "DepthDataFiltered")
        dict.setValue(depthFormatDescription!.dimensions.width, forKey: "Width")
        dict.setValue(depthFormatDescription!.dimensions.height, forKey: "Height")
        dict.setValue(depthFormatDescription!.mediaType.description.replacingOccurrences(of: "'", with: ""), forKey: "MediaType")
        dict.setValue(depthFormatDescription!.mediaSubType.description.replacingOccurrences(of: "'", with: ""), forKey: "MediaSubType")
        dict.setValue(bytesPerRow, forKey: "BytesPerRow")
        dict.setValue(DEPTH_COLOR_SPACE, forKey: "ColorSpace")
        dict.setValue(bitsPerComponent, forKey: "BitsPerComponent")

        let optionPretty = JSONSerialization.WritingOptions.prettyPrinted
        let optionSorted = JSONSerialization.WritingOptions.sortedKeys
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [optionPretty, optionSorted])
        let content = String(data: jsonData, encoding: String.Encoding.utf8)!

        return content
    }

    public static func getCameraMetaDataJson(_ timeStamp: Int64,
                                             device: AVCaptureDevice) -> String {
        let dict : NSMutableDictionary = NSMutableDictionary()

        dict.setValue(timeStamp, forKey: "Timestamp")
        dict.setValue(device.activeColorSpace.rawValue == 0 ? "sRGB" : "P3_D65", forKey: "ColorSpace")
        dict.setValue(device.lensAperture, forKey: "LensAperture")
        dict.setValue(device.lensPosition, forKey: "LensPosition")
        dict.setValue(device.deviceType.rawValue, forKey: "DeviceType")
        dict.setValue(device.exposurePointOfInterest.debugDescription, forKey: "ExposurePointOfInterest")
        dict.setValue(device.focusPointOfInterest.debugDescription, forKey: "FocusPointOfInterest")
        dict.setValue(device.isGeometricDistortionCorrectionEnabled, forKey: "GeometricDistortionCorrectionEnabled")
        dict.setValue(device.focusMode.rawValue, forKey: "FocusMode")
        dict.setValue(device.exposureTargetBias, forKey: "ExposureTargetBias")
        dict.setValue(device.maxExposureTargetBias, forKey: "MaxExposureTargetBias")
        dict.setValue(device.minExposureTargetBias, forKey: "MinExposureTargetBias")

        dict.setValue(device.activeFormat.isVideoHDRSupported, forKey: "VideoHDRSupported")
        dict.setValue(device.activeFormat.isVideoBinned, forKey: "VideoBinned")
        dict.setValue(device.isVideoHDREnabled, forKey: "VideoHDREnabled")
        dict.setValue(device.activeFormat.isMultiCamSupported, forKey: "MultiCamSupported")
        dict.setValue(device.activeFormat.videoFieldOfView, forKey: "VideoFieldOfView")
        dict.setValue(device.activeFormat.videoMaxZoomFactor, forKey: "VideoMaxZoomFactor")
        let hrsiDims = device.activeFormat.highResolutionStillImageDimensions
        dict.setValue("\(hrsiDims.width)x\(hrsiDims.height)", forKey: "HRSI")

        dict.setValue("[\(device.activeVideoMaxFrameDuration.timescale)-\(device.activeVideoMaxFrameDuration.timescale)]", forKey: "FpsRange")
        dict.setValue(device.activeFormat.isHighestPhotoQualitySupported, forKey: "isHighestPhotoQualitySupported")
        dict.setValue(device.isLowLightBoostEnabled, forKey: "isLowLightBoostEnabled")
        dict.setValue(device.isSmoothAutoFocusEnabled, forKey: "isSmoothAutoFocusEnabled")
        dict.setValue(device.isGlobalToneMappingEnabled, forKey: "isGlobalToneMappingEnabled")
        dict.setValue(device.isGeometricDistortionCorrectionSupported, forKey: "isGeometricDistortionCorrectionSupported")

        let formatDescription = device.activeFormat.formatDescription
        dict.setValue(formatDescription.dimensions.width, forKey: "Width")
        dict.setValue(formatDescription.dimensions.height, forKey: "Height")
        dict.setValue(formatDescription.mediaType.description.replacingOccurrences(of: "'", with: ""), forKey: "MediaType")
        dict.setValue(formatDescription.mediaSubType.description.replacingOccurrences(of: "'", with: ""), forKey: "MediaSubType")

        let optionPretty = JSONSerialization.WritingOptions.prettyPrinted
        let optionSorted = JSONSerialization.WritingOptions.sortedKeys
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [optionPretty, optionSorted])
        let content = String(data: jsonData, encoding: String.Encoding.utf8)!

        return content
    }

    public static func getARCameraMetaDataJson(_ timeStamp: Int64,
                                               currentFrame: ARFrame) -> String {
        let stringOfSimd3 = SensorUtils.stringOfSimd3
        let stringOfSimd4 = SensorUtils.stringOfSimd4
        let dict : NSMutableDictionary = NSMutableDictionary()
        let intrinsics = currentFrame.camera.intrinsics
        let transform = currentFrame.camera.transform
        let projectionMatrix = currentFrame.camera.projectionMatrix
        dict.setValue(timeStamp, forKey: "Timestamp")

//      Row major matrices
        dict.setValue(stringOfSimd3(intrinsics.transpose.columns.0), forKey: "IntrinsicMatrix.0")
        dict.setValue(stringOfSimd3(intrinsics.transpose.columns.1), forKey: "IntrinsicMatrix.1")
        dict.setValue(stringOfSimd3(intrinsics.transpose.columns.2), forKey: "IntrinsicMatrix.2")

        dict.setValue(stringOfSimd4(transform.transpose.columns.0), forKey: "Transform.0")
        dict.setValue(stringOfSimd4(transform.transpose.columns.1), forKey: "Transform.1")
        dict.setValue(stringOfSimd4(transform.transpose.columns.2), forKey: "Transform.2")
        dict.setValue(stringOfSimd4(transform.transpose.columns.3), forKey: "Transform.3")

        dict.setValue(stringOfSimd4(projectionMatrix.transpose.columns.0), forKey: "ProjectionMatrix.0")
        dict.setValue(stringOfSimd4(projectionMatrix.transpose.columns.1), forKey: "ProjectionMatrix.1")
        dict.setValue(stringOfSimd4(projectionMatrix.transpose.columns.2), forKey: "ProjectionMatrix.2")
        dict.setValue(stringOfSimd4(projectionMatrix.transpose.columns.3), forKey: "ProjectionMatrix.3")

        dict.setValue(currentFrame.camera.imageResolution.width, forKey: "Width")
        dict.setValue(currentFrame.camera.imageResolution.height, forKey: "Height")


        dict.setValue(currentFrame.capturedDepthData!.cameraCalibrationData!.lensDistortionCenter.debugDescription, forKey: "LensDistortionCenter")
        dict.setValue(convertLensDistortionLookupTable(lookupTable: currentFrame.capturedDepthData!.cameraCalibrationData!.lensDistortionLookupTable!), forKey: "LensDistortionLookupTable")
        dict.setValue(convertLensDistortionLookupTable(lookupTable: currentFrame.capturedDepthData!.cameraCalibrationData!.inverseLensDistortionLookupTable!), forKey: "LensDistortionInverseLookupTable")

        let optionPretty = JSONSerialization.WritingOptions.prettyPrinted
        let optionSorted = JSONSerialization.WritingOptions.sortedKeys
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: [optionPretty, optionSorted])
        let content = String(data: jsonData, encoding: String.Encoding.utf8)!

        return content
    }

    public static func saveRgb(withBuffer buffer: CVImageBuffer, timeStamp: Int64) {
        let image = UIImage(pixelBuffer: buffer)
        if (!saveImagePng(image: image!, fileName: "rgb_\(timeStamp).png")) {
            print("Error with saving rgb image!")
        }
    }

    public static func saveDepthPng(withData data: AVDepthData, timeStamp: Int64) {
        var fileURL = FileUtils.getDatasetDirectory()
        fileURL.appendPathComponent("depth_\(timeStamp).png")
        CvHelper.writeDepthPng(fileURL.path, with: data)
    }

    public static func saveImagePng(image: UIImage, fileName: String) -> Bool {
        guard let data = image.pngData() else {
            print("No png data!")
            return false
        }
        let directory = FileUtils.getDatasetDirectory()
        do {
            try data.write(to: directory.appendingPathComponent(fileName))
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }

}
