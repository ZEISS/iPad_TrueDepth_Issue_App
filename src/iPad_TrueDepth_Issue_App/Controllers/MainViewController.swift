//
//  MainViewController.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit

/**
 The main screen of the app.
 Pose (diff), Pose (delay) or Stream mode can be selected.
 The datasets recorded can be cleared by clicking "Clear Data".
 */
class MainViewController: UIViewController {

    @IBOutlet weak var streamBtn: UIButton!
    @IBOutlet weak var clearDataBtn: UIButton!
    @IBOutlet weak var depthSensorAnalysisButton: UIButton!

    private func updateButton(_ button: UIButton) {
        button.contentEdgeInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        button.layer.borderWidth = 1
        button.layer.borderColor = button.tintColor.cgColor
        button.layer.cornerRadius = 5
    }

    @IBAction func clearData(_ sender: Any) {
        let alert = UIAlertController(title: "Clear data", message: "All data will be lost!", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            FileUtils.clearAppData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

//    TODO: Refer for info, https://developer.apple.com/library/archive/samplecode/Reachability/Introduction/Intro.html
//    private func checkWiFi() {
//        let reachability = Reachability()
//        let netStatus = reachability.currentReachabilityStatus()
//        let connectionRequired = reachability.connectionRequired()
//        var statusString = ""
//        switch netStatus {
//            case NotReachable:
//                statusString = "Network connection not reachable"
//                break
//            case ReachableViaWWAN:
//                //DATA
//                statusString = "Mobile data is being used. Web Server will be disabled!"
//                break
//            case ReachableViaWiFi:
//                //WIFI
//                break
//        default:
//            statusString = "Invalid wifi status"
//        }
//        print(statusString)
//        if statusString != "" {
//            UiUtils.showMessage(title: "Warning", message: statusString, pController: self)
//        }
//    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateButton(streamBtn)
        updateButton(clearDataBtn)
        updateButton(depthSensorAnalysisButton)
    }
}
