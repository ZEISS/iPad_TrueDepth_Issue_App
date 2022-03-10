//
//  UiUtils.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit

/**
 This class provides utility methods for preseting UI components.
 */
class UiUtils: NSObject {
    static var player: AVAudioPlayer?

    static func showLoading(_ controller: UIViewController) -> UIAlertController? {
        var alert: UIAlertController? = nil
        let block = {
            alert = UIAlertController(title: "Please wait...", message: "", preferredStyle: .alert)

            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = UIActivityIndicatorView.Style.medium
            loadingIndicator.startAnimating();

            alert!.view.addSubview(loadingIndicator)
            controller.present(alert!, animated: true, completion: nil)
        }
        if Thread.current == Thread.main {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
        return alert
    }

    static func hideLoading(_ controller: UIViewController) {
        let block = {
            controller.dismiss(animated: true, completion: nil)
        }
        if Thread.current == Thread.main {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }

    static func alertOnRecord() {
        guard let url = Bundle.main.url(forResource: "notification", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            guard let player = player else { return }
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }

    static func showMessage(title: String, message: String, pController: UIViewController, autoDismiss: Bool = false) {
        guard pController.view.window != nil else { return }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if autoDismiss {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { _ in
                alertController.dismiss(animated: true, completion: nil)
            } )
        } else {
            let cancelAction = UIAlertAction(title: "OK", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(cancelAction)
        }
        pController.present(alertController, animated: true, completion: nil)
    }
}

extension UIColor {
    static let system = UIView().tintColor!
}
