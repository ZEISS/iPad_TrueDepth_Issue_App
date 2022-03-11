//
//  WebServer.swift
//  VtkWaPrototype
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit
import Foundation
import GCDWebServer

/**
 Delegate methods to notifiy when compression state has changed.
 */
protocol CompressionDelegate {
    func onCompressionStarted()

    func onCompressionCompleted()
}

/**
 The web server is used to download the datasets from the device to the user's machine.
 The project's README.md has instructions how the data can be downloaded.
 */
class WebServer: NSObject {
    private let webServer = GCDWebServer()
    weak var uiController: UIViewController? = nil
    public var delegate: CompressionDelegate? = nil
    private static let PORT: UInt = 8080

    func getServerUrl() -> URL? {
        return webServer.serverURL
    }

    private func readFileFromBundle(_ name: String, ext: String) -> (Data?, Error?) {
        guard let path = Bundle.main.path(forResource: name, ofType: ext) else {
            print("WARN: No such file!")
            return (nil, nil)
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return (data, nil)
        }
        catch {
            print("readFileFromBundle Error: \(error)")
            return (nil, error)
        }
    }

    private func readFileFromDocumentsDirectory(_ name: String) -> (Data?, Error?) {
        let fileURL = FileUtils.getDocumentsDirectory().appendingPathComponent(name)
        var data: Data? = nil
        do {
            data = try Data(contentsOf: fileURL)
            return (data, nil)
        }
        catch {
            print("readFileFromDocumentsDirectory Error: \(error)")
            return (nil, error)
        }
    }

    func initWebServer() {
        webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {request in
            print("path: \(request.path)")
            var name = ""
            var ext = ""
            var isBundle = true
            if (request.path == "/") {
                name = "index"
                ext = "html"
            } else if (request.path.contains(".js")) {
                name = "index"
                ext = "js"
            } else if (request.path.contains(".png")) {
                name = "test"
                ext = "png"
                isBundle = false
            } else if (request.path.contains(".ico")) {
                name = "favicon"
                ext = "ico"
            } else if (request.path.contains(".zip")) {
                self.delegate?.onCompressionStarted()
                if let controller = self.uiController {
                    let alert = UiUtils.showLoading(controller)
                    let progress = Progress()
                    DispatchQueue.main.async {
                        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
                            DispatchQueue.main.async {
                                let percent = Int(progress.fractionCompleted * 100)
                                alert?.message = "Compressed \(percent)%"
                            }

                            if progress.fractionCompleted == 1.0 {
                                print("Stopping timer!")
                                timer.invalidate()
                            }
                        }
                    }
                    FileUtils.compressAppDirectory(progress: progress, uiController: controller)
                }
                name = "Archive"
                ext = "zip"
                isBundle = false
                if let controller = self.uiController {
                    UiUtils.hideLoading(controller)
                }
                self.delegate?.onCompressionCompleted()
            } else {
                print("WARN: No such file: \(request)")
            }
            var (data, error) = isBundle ? self.readFileFromBundle(name, ext: ext) : self.readFileFromDocumentsDirectory("\(name).\(ext)")
            if let data = data {
                return GCDWebServerDataResponse(data: data, contentType: ext)
            } else {
                print("No file data. Error:", error)
                DispatchQueue.main.async {
                    if let uiController = self.uiController, let error = error {
                        UiUtils.showMessage(title: "File reading error",
                                            message: "\(error.localizedDescription)", pController: uiController)
                    }
                }
                let errorData = "Error, cannot read file. Sending corrupted file".data(using: .utf8)
                return GCDWebServerDataResponse(data: errorData!, contentType: ext)
            }
        })
        webServer.start(withPort: WebServer.PORT, bonjourName: "GCD Web Server")

        print("Visit \(webServer.serverURL) in your web browser")
    }

    func stop() {
        print("Stopping server")
        webServer.stop()
    }
}
