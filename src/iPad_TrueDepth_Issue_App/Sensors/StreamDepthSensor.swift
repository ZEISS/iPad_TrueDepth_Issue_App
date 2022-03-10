//
//  StreamDepthSensor.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit
import AVFoundation
import VideoToolbox

protocol StreamDepthSensorDelegate {
    //    Invoked when all images are captured.
    func onImagesCaptured()

    //    Invoked when a single images has been captured.
    func onNewImageCaptured(_ count: Int)

     //    Invoked when a single frame has been captured.
    func onNewFrame(depthData: AVDepthData, colorCameraIntrinsics: simd_float3x3, colorBuffer: CVPixelBuffer)
}

/*
 BITS_PER_COMPONENT specifies the number of bits to be used for the depth data.
 32 bits are used for saving PFM files & PNG files. This retains the "depth" information, regarding distance.
 16 bits are used for saving PNG files using libpng.
 This approach caused scaling the depth data into png scale, i.e., (2^16 - 1) range.
*/
class StreamDepthSensor: NSObject {
    private static let BITS_PER_COMPONENT = 32
    private static let DEPTH_DATA_TYPE = BITS_PER_COMPONENT == 16 ? kCVPixelFormatType_DepthFloat16 : kCVPixelFormatType_DepthFloat32
    private static let DEPTH_BYTE_ORDER = BITS_PER_COMPONENT == 16 ? CGBitmapInfo.byteOrder16Little.rawValue : CGBitmapInfo.byteOrder32Little.rawValue

    private static let DEPTH_METADATA_FNAME = "DepthMetadata.json"
    private static let CAMERA_METADATA_FNAME = "CameraMetadata.json"

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private let sessionQueue = DispatchQueue(label: "depthSessionQueue",
                                             attributes: [], autoreleaseFrequency: .workItem)
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private var renderingEnabled = true
    private let dataOutputQueue = DispatchQueue(label: "videoDataQueue",
                                                qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera],
                                                                               mediaType: .video,
                                                                               position: .front)
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?

    private var setupResult: SessionSetupResult = .success

    private var recordDataEnabled = false
    private var numImages = 10
    private var captureDelayInMs: Int = 33
    private var numCapturedImages = 0
    private var capturedTimeStamp: Int64 = -1

    private var cameraMetadataContent = ""
    private var depthMetadataContent = ""

    public var delegate: StreamDepthSensorDelegate? = nil
    private let group = DispatchGroup()
    private let saveQueue = DispatchQueue(label: "SaveQueue", qos: .default, attributes: .concurrent)

    public func setRecordData(enabled: Bool) {
        recordDataEnabled = enabled

        if (!enabled) {
            depthMetadataContent.remove(at: depthMetadataContent.index(before: depthMetadataContent.endIndex))
            cameraMetadataContent.remove(at: cameraMetadataContent.index(before: cameraMetadataContent.endIndex))

            FileUtils.appendToFile(StreamDepthSensor.DEPTH_METADATA_FNAME, content: "[\n\(depthMetadataContent)\n]")
            FileUtils.appendToFile(StreamDepthSensor.CAMERA_METADATA_FNAME, content: "[\n\(cameraMetadataContent)\n]")

            cameraMetadataContent = ""
            depthMetadataContent = ""
            numCapturedImages = 0
        }
    }

    public func setNumImages(_ num: Int) {
         numImages = num
    }

    public func setCaptureDelay(_ delay: Int) {
        captureDelayInMs = delay
    }

    public func getCaptureSession() -> AVCaptureSession {
        return session
    }

    /*
     Configure the capture session.
     The TrueDepth camera device is added to the session as an input.
     A depth & video output is attached to the session.
     */
    private func configureSession() {
        if setupResult != .success {
            return
        }

        let defaultVideoDevice: AVCaptureDevice? = videoDeviceDiscoverySession.devices.first

        guard let videoDevice = defaultVideoDevice else {
            print("Could not find any video device")
            setupResult = .configurationFailed
            return
        }

        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }

        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.vga640x480

        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)

        // Add a video data output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            if #available(iOS 11.0, *) {
                videoDataOutput.connection(with: .video)?.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        } else {
            print("Could not add video data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = false
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
            } else {
                print("No AVCaptureConnection")
            }
        } else {
            print("Could not add depth data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Search for highest resolution with half-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        let filtered = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == StreamDepthSensor.DEPTH_DATA_TYPE
        })
        let selectedFormat = filtered.max(by: {
            first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
        })

        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
        session.commitConfiguration()
    }

    /*
     A wrapper for configuring the capture session.
     It checks if the camera permission has been granted.
     */
    func configure() {
        print("Configuring..")
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            // The user has previously granted access to the camera
            break

        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant video access
             We suspend the session queue to delay session setup until the access request has completed
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })

        default:
            // The user has previously denied access
            setupResult = .notAuthorized
        }
        sessionQueue.async {
            self.configureSession()
        }
    }

    func start() {
        print("Starting session..")
        sessionQueue.async {
        switch self.setupResult {
            case .success:
                self.dataOutputQueue.async {
                    self.renderingEnabled = true
                }
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning

            case .notAuthorized:
                print("notAuthorized!")
            case .configurationFailed:
                print("configurationFailed")
            }
        }
    }


    func stop() {
        print("Stopping session..")
        dataOutputQueue.async {
            self.renderingEnabled = false
        }
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
}

/**
 The synchronized depth & video output is obtained.
 Only when both the data is available, they are processed.
 */
extension StreamDepthSensor: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        if !renderingEnabled {
            return
        }
        guard renderingEnabled,
            let syncedDepthData: AVCaptureSynchronizedDepthData =
            synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
            let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
            synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }

        let depthData = syncedDepthData.depthData
        let sampleBuffer = syncedVideoData.sampleBuffer

        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        let timeStamp = (1000 * presentationTimeStamp.value) / Int64(presentationTimeStamp.timescale)

        var convertedDepth: AVDepthData
        let depthDataType = StreamDepthSensor.DEPTH_DATA_TYPE
        if depthData.depthDataType != depthDataType {
            convertedDepth = depthData.converting(toDepthDataType: depthDataType)
        } else {
            convertedDepth = depthData
        }

        var colorMatrix = matrix_identity_float3x3
        guard let rgbPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else  { return }
        if #available(iOS 11.0, *) {
            if let camData = CMGetAttachment(sampleBuffer, key:kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut:nil) as? Data {
                colorMatrix = camData.withUnsafeBytes { $0.pointee }
            }
        }

        delegate?.onNewFrame(depthData: convertedDepth, colorCameraIntrinsics: colorMatrix, colorBuffer: rgbPixelBuffer)

        if (capturedTimeStamp == -1) {
            capturedTimeStamp = timeStamp
        }
        let diff = timeStamp - capturedTimeStamp
        if (recordDataEnabled && diff >= captureDelayInMs) {
            capturedTimeStamp = timeStamp

//            IO operations are dispatched into a separate queue.
            saveQueue.async(group: group) {
                let start = DispatchTime.now()
                self.depthMetadataContent += ExportUtils.getDepthMetadataJson(convertedDepth, bitsPerComponent: StreamDepthSensor.BITS_PER_COMPONENT, timeStamp: timeStamp) + ","
                ExportUtils.saveDepthPng(withData: convertedDepth, timeStamp: timeStamp)    // uses OpenCV
//                ExportUtils.saveDepthLibpng can be used to save with libpng.

                self.cameraMetadataContent += ExportUtils.getCameraMetaDataJson(timeStamp, device: self.videoDeviceInput.device) + ","
                ExportUtils.saveRgb(withBuffer: rgbPixelBuffer, timeStamp: timeStamp)
                let end = DispatchTime.now()
                print("Saved images, timestamp: \(timeStamp), time taken: \((end.uptimeNanoseconds - start.uptimeNanoseconds) / (1000 * 1000)) ms")
            }

            numCapturedImages += 1

            if (numCapturedImages == numImages) {
                numCapturedImages = 0
                recordDataEnabled = false

//                Wait until all the IO operations dispatched are complete, block until finished.
                group.wait()
                delegate?.onImagesCaptured()
            } else {
                delegate?.onNewImageCaptured(numCapturedImages)
            }
        }
    }
}
