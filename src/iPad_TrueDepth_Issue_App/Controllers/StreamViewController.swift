//
//  StreamViewController.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit
import NetworkExtension
import AudioToolbox

/***
 Stream mode allows saving depth images captured from the TrueDepth camera. If TrueDepth camera is unavailable, an error is displayed.
 Both rgb & depth data are saved in the same resolution & camera intrinsic data is saved.
 Currently, images are saved in 640x480 resolution.
 */
class StreamViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, StreamDepthSensorDelegate {

    @IBOutlet weak var previewView: CameraView!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var numImagePicker: UIPickerView!
    @IBOutlet weak var delayPicker: UIPickerView!
    @IBOutlet weak var imagesLabel: UILabel!

    @IBOutlet weak var serverStatusLabel: UILabel!

    private let depthSensor = StreamDepthSensor()
    private let webServer = WebServer()
    private var isRunning = false

    /*
     The number of maximum images that can be recorded show on the UI can be modified.
     */
    private static let MAX_IMAGES = 100

//    Delay values from 33 to 3000
    private static let MAX_DELAY_ELEMENTS = 90
    private static let FPS_DELAY: Float = 1000.0 / 30.0
    private let DEFAULT_IMAGES_INDEX = 9
    private let DEFAULT_DELAY_INDEX = 1

    struct DefaultsKeys {
        static let KEY_IMAGES = "StreamKeyImages"
        static let KEY_DELAY = "StreamKeyDelay"
    }

    private func startApp() {
        FileUtils.clearDataset()
        FileUtils.createAppDirectoryIfNeeded()
        FileUtils.createDatasetDirectoryIfNeeded()

        webServer.uiController = self
        webServer.initWebServer()

        depthSensor.delegate = self
        depthSensor.configure()

        self.previewView.videoPreviewLayer.session = depthSensor.getCaptureSession()
        depthSensor.start()
    }

    private func updateViews() {
        let color = 0.15 as CGFloat
        startStopButton.backgroundColor = UIColor.init(red: color, green: color, blue: color, alpha: 1)
        startStopButton.layer.cornerRadius = 10.0

        numImagePicker.delegate = self
        numImagePicker.dataSource = self
        delayPicker.delegate = self
        delayPicker.dataSource = self

        let defaults = UserDefaults.standard
        let imgIndex = FileUtils.isKeyPresentInUserDefaults(key: DefaultsKeys.KEY_IMAGES) ?
            defaults.integer(forKey: DefaultsKeys.KEY_IMAGES) : DEFAULT_IMAGES_INDEX

        let delayIndex = FileUtils.isKeyPresentInUserDefaults(key: DefaultsKeys.KEY_DELAY) ?
            defaults.integer(forKey: DefaultsKeys.KEY_DELAY) : DEFAULT_DELAY_INDEX

        numImagePicker.selectRow(imgIndex, inComponent: 0, animated: true)
        delayPicker.selectRow(delayIndex, inComponent: 0, animated: true)
        self.imagesLabel.isHidden = true
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    private func isImagePicker(_ pv: UIPickerView) -> Bool {
        return pv == numImagePicker
    }

    private func getDelayFromRow(_ row: Int) -> String {
        return String.init(format: "%d", Int(Float(row + 1) * (StreamViewController.FPS_DELAY)))
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return isImagePicker(pickerView) ? StreamViewController.MAX_IMAGES : StreamViewController.MAX_DELAY_ELEMENTS
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return isImagePicker(pickerView) ? "\(row + 1)" : getDelayFromRow(row)
    }

    override func viewDidLoad() {
        print("viewDidLoad")
        super.viewDidLoad()
        if let navigationController = self.navigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
        }

        updateViews()
//        Hotspot creation cannot work w/o Apple dev account.
//        startStopButton.tintColor = UIColor.white
//        let config = NEHotspotConfiguration.init(ssid: "TheWindsForSensors")
//        config.joinOnce = true

//        NEHotspotConfigurationManager.shared.apply(config) { (err) in
//            print("Error: \(err)")
//
////            startApp()
//        }
        startApp()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(updateServerStatus), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func updateServerStatus() {
        print("Updating server status")

        if let serverStatus = webServer.getServerUrl() {
            serverStatusLabel.text = "\(serverStatus)"
        } else {
            serverStatusLabel.text = "Server error (WiFi not connected?)"
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateServerStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        print("viewWillDisappear!")
        depthSensor.stop()
        webServer.stop()
        super.viewWillDisappear(animated)
    }

//    When Start/Stop button is clicked or all the images are captured, the recording state is toggled.
    @IBAction func toggleStartStop(_ sender: Any) {
        print("toggleStartStop")
        UiUtils.alertOnRecord()

        isRunning = !isRunning
        startStopButton.setTitle(isRunning ? "Stop" : "Start", for: .normal)
        imagesLabel.isHidden = !isRunning
        if (isRunning) {
            self.imagesLabel.text = "0"
            let defaults = UserDefaults.standard
            defaults.set(numImagePicker.selectedRow(inComponent: 0), forKey: DefaultsKeys.KEY_IMAGES)
            defaults.set(delayPicker.selectedRow(inComponent: 0), forKey: DefaultsKeys.KEY_DELAY)

            //    bad logic, but simpler
            let delay = Int(getDelayFromRow(delayPicker.selectedRow(inComponent: 0)))!
            let numImages = numImagePicker.selectedRow(inComponent: 0) + 1

            depthSensor.setNumImages(numImages)
            depthSensor.setCaptureDelay(delay)

            numImagePicker.isUserInteractionEnabled = false
            delayPicker.isUserInteractionEnabled = false
            startStopButton.tintColor = UIColor.red
            depthSensor.setRecordData(enabled: true)
        } else {
            depthSensor.setRecordData(enabled: false)
            numImagePicker.isUserInteractionEnabled = true
            delayPicker.isUserInteractionEnabled = true
            startStopButton.tintColor = UIColor.system
            buildDataset()
        }
    }

    func onImagesCaptured() {
        DispatchQueue.main.async {
            self.toggleStartStop(self)
        }
    }

    func onNewImageCaptured(_ count: Int) {
        DispatchQueue.main.async {
            self.imagesLabel.text = "\(count)"
        }
    }

    func onNewFrame(depthData: AVDepthData, colorCameraIntrinsics: simd_float3x3, colorBuffer: CVPixelBuffer) {

    }

    func setXYDiffLabel(_ xdiff: Float, ydiff: Float) {
    }

//    Builds the dataset. The current temporary dataset folder is renamed into the final dataset name.
    func buildDataset() {
        _ = UiUtils.showLoading(self)
        print("Building Dataset..")
        DispatchQueue.global(qos: .userInitiated).async {
            let start = DispatchTime.now()
            FileUtils.buildDataset(withPrefix: "Stream")
            FileUtils.createDatasetDirectoryIfNeeded()
            let end = DispatchTime.now()
            print("Compression completed, time taken: \((end.uptimeNanoseconds - start.uptimeNanoseconds) / (1000 * 1000)) ms")
            DispatchQueue.main.async {
                UiUtils.hideLoading(self)
            }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get { return .portrait }
    }
}
