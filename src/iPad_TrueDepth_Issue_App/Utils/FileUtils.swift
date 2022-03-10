//
//  FileUtils.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//


import UIKit
import ZIPFoundation

class FileUtils: NSObject {
    private static let APP_DIRECTORY_NAME = "AppData"
    private static let DATASET_DIRECTORY_NAME = "Datasets"
    private static let DEFAULTS_KEY_ARCHIVE_NUM = "ArchiveNum"

    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    static func getDocumentsDirectoryInString() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].path
    }

    static func getArchiveFileUrl() -> URL {
        var destinationURL = getDocumentsDirectory()
        destinationURL.appendPathComponent("Archive.zip")
        return destinationURL
    }

    static func getArchiveFileUrlInString() -> String {
        return getArchiveFileUrl().path
    }

    static func clearDataset() {
        let fileManager = FileManager.default
        do {
            if (fileManager.fileExists(atPath: getDatasetDirectoryInString())) {
                try fileManager.removeItem(at: getDatasetDirectory())
            }
        } catch {
            print("clearDataset, error: \(error)")
        }
    }

    static func clearAppData() {
        let fileManager = FileManager.default
        do {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil)
                for fileUrl in fileURLs {
                    try fileManager.removeItem(at: fileUrl)
                }
            } catch {
                print("Error while enumerating files \(getDocumentsDirectoryInString()): \(error.localizedDescription)")
            }
            if (fileManager.fileExists(atPath: getArchiveFileUrlInString())) {
                try fileManager.removeItem(at: getArchiveFileUrl())
            }
        } catch {
            print("clearAppData, error: \(error)")
        }
    }

    static func getAppDirectoryInString() -> String {
        guard var stringPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return "" }
        stringPath += "/" + APP_DIRECTORY_NAME
        return stringPath
    }

    static func getDatasetDirectoryInString() -> String {
        guard var stringPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return "" }
        stringPath += "/" + APP_DIRECTORY_NAME + "/" + DATASET_DIRECTORY_NAME
        return stringPath
    }

    static func createAppDirectoryIfNeeded() {
        let fileManager = FileManager.default
        let stringPath = getAppDirectoryInString()
        if (!fileManager.fileExists(atPath: stringPath)) {
            do {
                try fileManager.createDirectory(atPath: stringPath, withIntermediateDirectories: false, attributes: nil)
            } catch let error {
                print("createAppDirectoryIfNeeded, error: \(error)")
            }
        }
    }

    static func createDatasetDirectoryIfNeeded() {
        let fileManager = FileManager.default
        let stringPath = getDatasetDirectoryInString()
        if (!fileManager.fileExists(atPath: stringPath)) {
            do {
                try fileManager.createDirectory(atPath: stringPath, withIntermediateDirectories: false, attributes: nil)
            } catch let error {
                print("createDatasetDirectoryIfNeeded, error: \(error)")
            }
        }
    }

    static func getAppDirectory() -> URL {
        return URL(fileURLWithPath: getAppDirectoryInString())
    }

    static func getDatasetDirectory() -> URL {
        return URL(fileURLWithPath: getDatasetDirectoryInString())
    }

    static func fileExists(_ fileName: String) -> Bool {
        var fileURL = FileUtils.getDatasetDirectory()
        fileURL.appendPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func appendToFile(_ fileName: String, content: String) {
        var fileURL = FileUtils.getDatasetDirectory()
        fileURL.appendPathComponent(fileName)
        do {
            try content.appendLine(to: fileURL)
        } catch {
            print("Error: \(error)")
        }
    }

    static func writeToFile(_ fileName: String, content: String) {
        var fileURL = FileUtils.getDatasetDirectory()
        fileURL.appendPathComponent(fileName)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error: \(error)")
        }
    }

    static func clearFile(_ fileName: String, content: String) {
        var fileURL = FileUtils.getDatasetDirectory()
        fileURL.appendPathComponent(fileName)
        FileManager.default.createFile(atPath: fileURL.absoluteString, contents: nil, attributes: nil)
    }

    static func isKeyPresentInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    static func getDefaultsNum(_ key: String) -> Int {
        return UserDefaults.standard.integer(forKey: key)
    }

    static func storeNum(_ key: String, value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func buildDataset(withPrefix prefix: String) {
        let fileManager = FileManager()
        let sourceURL = getDatasetDirectory()

        var archiveNum = isKeyPresentInUserDefaults(key: "\(prefix)\(DEFAULTS_KEY_ARCHIVE_NUM)") ? getDefaultsNum("\(prefix)\(DEFAULTS_KEY_ARCHIVE_NUM)") : 0
        archiveNum += 1
        let datasetName = String.init(format: "\(prefix)Dataset_%02d", archiveNum)

        let newDatasetURL = URL(fileURLWithPath: getDocumentsDirectoryInString() + "/" + datasetName)
        do {
            try fileManager.moveItem(at: sourceURL, to: newDatasetURL)
        } catch { print("Error moving") }

        storeNum("\(prefix)\(DEFAULTS_KEY_ARCHIVE_NUM)", value: archiveNum)
    }

    static func compressAppDirectory(progress: Progress? = nil, uiController: UIViewController? = nil) {
        let fileManager = FileManager()
        let sourceURL = getDocumentsDirectory()
        let archiveUrl = getArchiveFileUrl()
        do {
            if (fileManager.fileExists(atPath: archiveUrl.path)) {
                try fileManager.removeItem(at: archiveUrl)
            }
            try fileManager.zipItem(at: sourceURL, to: archiveUrl, progress: progress)
        } catch {
            print("Creation of ZIP archive failed with error:\(error)")
            DispatchQueue.main.async {
                if let uiController = uiController {
                    UiUtils.showMessage(title: "Creation of ZIP error",
                                        message: "\(error.localizedDescription)", pController: uiController)
                }
            }
        }
    }
}

extension String {
    func appendLine(to url: URL) throws {
        try self.appending("\n").append(to: url)
    }
    func append(to url: URL) throws {
        let data = self.data(using: String.Encoding.utf8)
        try data?.append(to: url)
    }
}

extension Data {
    func append(to url: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url)
        }
    }
}
