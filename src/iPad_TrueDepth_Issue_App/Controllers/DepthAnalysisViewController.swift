//
//  DepthAnalysisViewController.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//

import SceneKit
import ARKit

class DepthAnalysisViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, StreamDepthSensorDelegate {

    @IBOutlet weak var sceneView: ARSCNView!

    @IBOutlet weak var depthMode: UISegmentedControl!

    @IBOutlet weak var sessionSelection: UISegmentedControl!

    @IBOutlet weak var depthLensDistortionCenterLabel: UILabel!

    var context = CIContext()
    var tFilter : CIFilter? = nil
    var mFilter : CIFilter? = nil
    var viewTrans : CGAffineTransform? = nil

    @IBOutlet weak var hasDepthLookupTable: UILabel!

    let gradientImage = CIImage(cgImage: #imageLiteral(resourceName: "Gradient.png").cgImage!)

    private var avDepthSensor : StreamDepthSensor? = nil

    @IBAction func depthModeIndexChanged(_ sender: Any) {

    }

    @IBAction func sessionSelectionChanged(_ sender: Any) {
        print("Session Selection changed " + self.sessionSelection.selectedSegmentIndex.description)

        self.depthLensDistortionCenterLabel.text = ""
        if (self.sessionSelection.selectedSegmentIndex == 0) {
            startARKitSession()
        } else {
            startAVSession()
        }

    }

    func startAVSession() {
        self.sceneView.session.pause()
        self.sceneView.session.delegate = nil
        self.avDepthSensor = StreamDepthSensor()
        self.avDepthSensor!.delegate = self
        self.avDepthSensor!.configure()

        self.avDepthSensor!.start()
    }

    func startARKitSession() {
        self.avDepthSensor?.stop()
        self.avDepthSensor = nil

        let configuration = ARFaceTrackingConfiguration()
        configuration.worldAlignment = .camera
        for conf in ARFaceTrackingConfiguration.supportedVideoFormats {
            print(conf)
            if conf.imageResolution.height == 640 {
                configuration.videoFormat = conf
            }
        }
        print("using the following video format")
        print(configuration.videoFormat)

        self.sceneView.session.delegate = self

        self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors] )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self

        sceneView.showsStatistics = true

        sceneView.scene.background.contents = UIColor.black

        tFilter = CIFilter(name: "CIColorMap")!
        tFilter!.setValue(gradientImage, forKey: kCIInputGradientImageKey)
        mFilter = CIFilter(name: "CIMultiplyBlendMode")!
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        hasDepthLookupTable.text = ""
        depthLensDistortionCenterLabel.text = ""
        depthLensDistortionCenterLabel.numberOfLines = 0

        startARKitSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - StreamDepthSensorDelegate

    func onNewFrame(depthData: AVDepthData, colorCameraIntrinsics: simd_float3x3, colorBuffer: CVPixelBuffer) {

        print("on new frame: " + colorCameraIntrinsics.debugDescription)
        self.displayCalibrationData(depthData: (depthData.cameraCalibrationData)!, colorData: colorCameraIntrinsics)

        let depthBuffer : CVPixelBuffer = depthData.depthDataMap

        // Output scene dimensions
        let frameWidth = sceneView.frame.size.width
        let frameHeight = sceneView.frame.size.height
        let targetSize = CGSize(width: frameWidth, height: frameHeight)

        renderDepthColorOverlay(depthBuffer: depthBuffer, colorBuffer: colorBuffer, viewTrans: self.viewTrans!, targetSize: targetSize)
    }

    func onImagesCaptured() {

    }

    func onNewImageCaptured(_ count: Int) {

    }



    // MARK: - ARSCNViewDelegate

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user

    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay

    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required

    }



    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor){
    }

    func displayCalibrationData(depthData: AVCameraCalibrationData, colorData: simd_float3x3) {

        let depthLensDistortionLookupTable = depthData.lensDistortionLookupTable
        let depthLensDistortionCenter = depthData.lensDistortionCenter

        if (depthLensDistortionLookupTable != nil) {
            hasDepthLookupTable.text = "has lookup table"
            hasDepthLookupTable.textColor = UIColor.green
        } else {
            hasDepthLookupTable.text = "has no lookup table"
            hasDepthLookupTable.textColor = UIColor.red
        }

        var intrinsics : String = ""
        if (depthLensDistortionCenter != nil) {
            intrinsics += "Lens distortion center:\n" + depthLensDistortionCenter.debugDescription
            self.depthLensDistortionCenterLabel.textColor = UIColor.green
        } else {
            intrinsics += "no lens distortion center"
            self.depthLensDistortionCenterLabel.textColor = UIColor.red
        }
        let refDim = depthData.intrinsicMatrixReferenceDimensions
        intrinsics += "\nIntrinsic matrix reference dimensions:\n\t" + refDim.debugDescription
        let px = depthData.intrinsicMatrix.transpose.columns.0.z
        let py = depthData.intrinsicMatrix.transpose.columns.1.z
        let fx = depthData.intrinsicMatrix.transpose.columns.0.x
        let fy = depthData.intrinsicMatrix.transpose.columns.1.y
        intrinsics += "\nDepth intrinsics (unscaled)\n\tfx=" + fx.description + " fy=" + fy.description + "\n\tcx=" + px.description + " cy=" + py.description

        let colorpx = colorData.transpose.columns.0.z
        let colorpy = colorData.transpose.columns.1.z
        let colorfx = colorData.transpose.columns.0.x
        let colorfy = colorData.transpose.columns.1.y
        intrinsics += "\nColor intrinsics \n\tfx=" + colorfx.description + " fy=" + colorfy.description + "\n\tcx=" + colorpx.description + " cy=" + colorpy.description

        // do task in background queue like
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                self.depthLensDistortionCenterLabel.text = intrinsics
                self.depthLensDistortionCenterLabel.sizeToFit()
                self.depthLensDistortionCenterLabel.setNeedsDisplay()
            }
        }
    }

    func renderDepthColorOverlay(depthBuffer: CVPixelBuffer, colorBuffer: CVPixelBuffer, viewTrans: CGAffineTransform, targetSize: CGSize) {
        let wd = CVPixelBufferGetWidth(depthBuffer)
        let hd = CVPixelBufferGetHeight(depthBuffer)
        let wc = CVPixelBufferGetWidth(colorBuffer)
        let hc = CVPixelBufferGetHeight(colorBuffer)

        let depthImage = CIImage(cvImageBuffer: depthBuffer)
        let colorImage = CIImage(cvImageBuffer: colorBuffer)

        let normalizeDepthTrans = CGAffineTransform(a: 1.0 / CGFloat(wd), b: 0, c: 0, d: -1.0 / CGFloat(hd), tx: 0, ty: 1.0)
        let normalizeColorTrans = CGAffineTransform(a: 1.0 / CGFloat(wc), b: 0, c: 0, d: -1.0 / CGFloat(hc), tx: 0, ty: 1.0)
        let scaleTrans = CGAffineTransform(a: CGFloat(targetSize.width), b: 0, c: 0, d: CGFloat(targetSize.height), tx: 0, ty: 0)
        let depthTransform = normalizeDepthTrans.concatenating(viewTrans).concatenating(scaleTrans)
        let colorTransform = normalizeColorTrans.concatenating(viewTrans).concatenating(scaleTrans)

        if (self.depthMode.selectedSegmentIndex == 0) {
            let depthImageTransformed = depthImage.transformed(by: depthTransform)
            tFilter!.setValue(depthImageTransformed, forKey: kCIInputImageKey)
            let mappedImage = tFilter!.outputImage!

            let colorImageTransformed = colorImage.transformed(by: colorTransform)
            mFilter!.setValue(mappedImage, forKey: kCIInputImageKey)
            mFilter!.setValue(colorImageTransformed, forKey: kCIInputBackgroundImageKey)

            let renderedBackground : CGImage = context.createCGImage(mFilter!.outputImage!, from: CGRect(x: 0, y: 0, width: CGFloat(targetSize.width), height: CGFloat(targetSize.height)))!
            let texture = SKTexture(cgImage: renderedBackground)

            sceneView.scene.background.contents = texture
            sceneView.scene.background.contentsTransform = SCNMatrix4Identity

        } else if (self.depthMode.selectedSegmentIndex == 1) {

            let depthImageTransformed = depthImage.transformed(by: depthTransform)

            let renderedBackground : CGImage = context.createCGImage(depthImageTransformed, from: CGRect(x: 0, y: 0, width: CGFloat(targetSize.width), height: CGFloat(targetSize.height)))!
            let texture = SKTexture(cgImage: renderedBackground)

            sceneView.scene.background.contents = texture
            sceneView.scene.background.contentsTransform = SCNMatrix4Identity
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        let depthData = frame.capturedDepthData
        if depthData != nil {

            self.displayCalibrationData(depthData: (frame.capturedDepthData?.cameraCalibrationData)!, colorData: frame.camera.intrinsics)

            // Render depth data to background texture (not quite as fast as using Metal textures)
            let depthBuffer : CVPixelBuffer = depthData!.depthDataMap
            let colorBuffer : CVPixelBuffer = frame.capturedImage
            // Output scene dimensions
            let frameWidth = sceneView.frame.size.width
            let frameHeight = sceneView.frame.size.height
            let targetSize = CGSize(width: frameWidth, height: frameHeight)
            self.viewTrans = frame.viewTrans(for: UIInterfaceOrientation.portrait, viewportSize: targetSize)

            renderDepthColorOverlay(depthBuffer: depthBuffer, colorBuffer: colorBuffer, viewTrans: self.viewTrans!, targetSize: targetSize)
        }
    }
}
