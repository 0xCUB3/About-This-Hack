//
//  UpdateController.swift
//

import Foundation
import AppKit
import Cocoa
import UserNotifications

class UpdateController {
    
    static var thisComponent: String {
        return String(describing: self)
    }

    static var lastTagVersion    :String = ""
    static var marketVersion     :String = ""
    static var minSystemVersion  :String = "Unknown"
    static var exeToSearch       :String = ""
    static var kindToSearch      :String = "app"
    static var isUpdateAvailable :Bool   = false
    static var alertheader       :String = ""
    static var alertdetail       :Any    = ""
    static var notificationID    :Int    = 0
    static var unzippedFile      :Bool   = false

    static func checkForUpdates() -> Bool {
        print("\(thisComponent) : Checking for updates...")
        lastTagVersion = run("GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs \(InitGlobVar.athrepositoryURL) | grep \"/tags/[0-9]\" | awk -F'/' '{print  $NF}' | sort -u | tail -n1 | tr -d '\n'")
        if lastTagVersion != "" && !lastTagVersion.starts(with: "fatal") {
            let pbxProjLocat = InitGlobVar.athlasttagpbxproj.replacingOccurrences(of: "[LASTTAG]", with: lastTagVersion)
            marketVersion = run("\(InitGlobVar.curlLocation) -s \(InitGlobVar.athrepositoryURL)\(pbxProjLocat) | sed -e 's?,?\\n?g' -e 's?;?\\n?g' | grep \"MARKETING_VERSION = \" | awk '{print $NF}' | sort -u | tail -n1 | tr -d '\n' 2>/dev/null")
// Postulat : there is one and only one target in pbxproj
            if marketVersion == "" {
                marketVersion = thisApplicationVersion  // fake marketVersion (ie. = localVersion) so no Update and no app. crash
            }
            print("\(thisComponent) : Local version (\(thisApplicationVersion)) and Remote version (\(marketVersion)) in .pbxproj from tag (\(lastTagVersion))")
            if thisApplicationVersion < marketVersion {
                //MARK: newer app found
                print("\(thisComponent) : Newer version (\(marketVersion)) available")
                let prompt = updateAlert(message: "Update found!", text: "The latest version is \(marketVersion).\nYou are currently running \(thisApplicationVersion).", buttonArray: ["Update", "Skip"])
                print("\(thisComponent) : Done")
                return prompt
            }
        } else {
            alertheader = "Can't get version from last remote repo tag"
            alertdetail = "\(InitGlobVar.athrepositoryURL)"
            print("\(thisComponent) : \(alertheader) \(alertdetail)")
            _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
        }
        return false
    }

    static func updateATH() {
        isUpdateAvailable = true
        
        //MARK: DownLoad new app.zip from repo
        print("\(thisComponent) : Starting Download v\(marketVersion) Update...")
        notify(title: "Starting Download... v\(marketVersion) Update...", informativeText: "")
        guard run("\(InitGlobVar.curlLocation) -L \(InitGlobVar.lastAthreleaseURL)\(lastTagVersion)/\(InitGlobVar.newAthziprelease) -o \(InitGlobVar.newAthreleasezip)") == "" else {
            alertheader = "Can't Download Update"
            alertdetail = "\(InitGlobVar.lastAthreleaseURL)\(lastTagVersion)/\(InitGlobVar.newAthziprelease)"
            print("\(thisComponent) : \(alertheader) \(alertdetail)")
            _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
            isUpdateAvailable = false
            return
        }

        //MARK: unzip new app.zip
        if isUpdateAvailable {
            while (!InitGlobVar.defaultfileManager.fileExists(atPath: InitGlobVar.newAthreleasezip)) {
                Thread.sleep(forTimeInterval: 0.2)
            }
            print("\(thisComponent) : Unzipping Archive...")
            notify(title: "Unzipping Archive...", informativeText: "")
            guard run("/usr/bin/unzip -q -o \(InitGlobVar.newAthreleasezip) -d \(InitGlobVar.athDirectory)") == "" else {
                alertheader = "Can't unzip Archive"
                alertdetail = "\(InitGlobVar.newAthreleasezip) into \(InitGlobVar.athDirectory)"
                print("\(thisComponent) : \(alertheader) \(alertdetail)")
                _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                isUpdateAvailable = false
                return
            }
            // what kind of extracted component a ".app" or a ".dmg" and man try 5 times
            var notFoundLoop : Int = 0
            while (!unzippedFile) && (notFoundLoop < 5) {
                Thread.sleep(forTimeInterval: 0.2)
                exeToSearch = checkFileExtension(atPath: InitGlobVar.athDirectory, withExtensions: [".app", ".dmg"])
                if exeToSearch != "" {
                    unzippedFile = true
                    notFoundLoop = 5
                    kindToSearch = String(exeToSearch.suffix(3))
                } else {
                    notFoundLoop += 1
                }
            }
            if (!unzippedFile) && (notFoundLoop > 4) {
                alertheader = "Can't find .app or .dmg extension on files name extracted from Archive"
                alertdetail = "\(InitGlobVar.newAthreleasezip) into \(InitGlobVar.athDirectory)"
                print("\(thisComponent) : \(alertheader) \(alertdetail)")
                _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                isUpdateAvailable = false
                return
            }
            print("\(thisComponent) : From archive was extracted : \(exeToSearch)")
        }
        
        //MARK: from new app.zip extracted .dmg or .app
        if isUpdateAvailable && kindToSearch == "dmg" {
            while (!InitGlobVar.defaultfileManager.fileExists(atPath: exeToSearch)) {
                Thread.sleep(forTimeInterval: 0.2)
            }
            //MARK: from new app.zip a .dmg extracted must be attached
            print("\(thisComponent) : Try to mount dmg \(exeToSearch)")
            notify(title: "Try to mount dmg...", informativeText: "")
            guard run("/usr/bin/hdiutil attach \"\(exeToSearch)\" -nobrowse -quiet") == "" else {
                alertheader = "Can't mount dmg"
                alertdetail = "\(exeToSearch)"
                print("\(thisComponent) : \(alertheader) \(alertdetail)")
                _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                isUpdateAvailable = false
                return
            }
            if isUpdateAvailable {
                while (!InitGlobVar.defaultfileManager.fileExists(atPath: "/Volumes/\(thisApplicationName)")) {
                    Thread.sleep(forTimeInterval: 2)
                }
                //MARK: .dmg is mounted containing a .app so we copy it to temp Dir
                print("\(thisComponent) : \(exeToSearch) mounted in /Volumes/\(thisApplicationName)!\n\(thisComponent) : Try to copy application /Volumes/\"\(thisApplicationName)/\(thisApplicationName).app\" to \(InitGlobVar.athDirectory)")
                guard run("/bin/cp -prf /Volumes/\"\(thisApplicationName)/\(thisApplicationName).app\" \(InitGlobVar.athDirectory)/\"\(thisApplicationName).app\"") == "" else {
                    alertheader = "Can't copy application"
                    alertdetail = "/Volumes/\"\(thisApplicationName)/\(thisApplicationName).app\" to \(InitGlobVar.athDirectory)"
                    print("\(thisComponent) : \(alertheader) \(alertdetail)")
                    _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                    isUpdateAvailable = false
                    return
                }
            }
            if isUpdateAvailable {
                while (!InitGlobVar.defaultfileManager.fileExists(atPath: "\(InitGlobVar.athDirectory)/\(thisApplicationName).app")) {
                    Thread.sleep(forTimeInterval: 0.2)
                }
                //MARK: .app from .dmg copied to temp Dir .dmg is detached
                print("\(thisComponent) : /Volumes/\"\(thisApplicationName)/\(thisApplicationName).app\" copied to \(InitGlobVar.athDirectory)!")
                print("\(thisComponent) : Try to umount Volume \"/Volumes/\(thisApplicationName)\"")
                notify(title: "Try to umount dmg...", informativeText: "")
                guard run("/usr/bin/hdiutil detach  /Volumes/\"\(thisApplicationName)\" -force -quiet") == "" else {
                    alertheader = "Can't umount \(thisApplicationName)dmg"
                    alertdetail = "/Volumes/\"\(thisApplicationName)\""
                    print("\(thisComponent) : \(alertheader) \(alertdetail)")
                    _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                    isUpdateAvailable = false
                    return
                }
                print("\(thisComponent) : /Volumes/\"\(thisApplicationName)\" ejected!")
            }
        }
        
        //MARK: does this new .app alowed on this OS version
        if isUpdateAvailable {
            while (!InitGlobVar.defaultfileManager.fileExists(atPath: "\(InitGlobVar.athDirectory)/\(thisApplicationName).app")) {
                Thread.sleep(forTimeInterval: 0.2)
            }
            print("\(thisComponent) : Is new app v\(marketVersion) allowed on current OS \(HCVersion.OSnum)?")
            notify(title: "Is new app v\(marketVersion) allowed...", informativeText: "")
            let plistNewVersion = "\(InitGlobVar.athDirectory)/\(thisApplicationName).app/Contents/Info.plist"
            if InitGlobVar.defaultfileManager.fileExists(atPath: "\(plistNewVersion)") {
                if let resourceFileDictionaryContent = NSDictionary(contentsOfFile: "\(plistNewVersion)") {
                    // Get "LSMinimumSystemVersion" value by key
                    minSystemVersion = resourceFileDictionaryContent.object(forKey: "LSMinimumSystemVersion")! as! String
                }
            }
            if minSystemVersion == "Unknown" || minSystemVersion == "" { //plistNewVersion not found or LSMinimumSystemVersion key not found
                alertheader = "Can't get Minimum OS Version"
                alertdetail = "LSMinimumSystemVersion not found in\n\"\(plistNewVersion)\""
                print("\(thisComponent) : \(alertheader) \(alertdetail)")
                _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                isUpdateAvailable = false
                return
            } else {
                let arrayMinOSVersion:[String] = minSystemVersion.components(separatedBy: ".")
                let arrayCurOSVersion:[String] = HCVersion.OSnum.components(separatedBy: ".")
                var minCountIndex:Int = 0
                var allowed:Bool = true
                if arrayMinOSVersion.count > arrayCurOSVersion.count {
                    minCountIndex = arrayCurOSVersion.count
                } else {
                    minCountIndex = arrayMinOSVersion.count
                }
                print("\(thisComponent) : Current OS version \(HCVersion.OSnum) and Minimum OS Version \(minSystemVersion)")
                for index in 0...minCountIndex-1 {
                    if arrayCurOSVersion[index] < arrayMinOSVersion[index] {
                        allowed = false
                        break
                    } else {
                        if arrayCurOSVersion[index] > arrayMinOSVersion[index] {
                            break
                        }
                    } // if arrayCurOSVersion[index] = arrayMinOSVersion[index] go on to check with next index (next part of tows versions)
                    print("\(thisComponent) : Index (\(index)) : Current OS version \(arrayCurOSVersion[index]) and Minimum OS Version \(arrayMinOSVersion[index])")
                }
                if !allowed {
                    alertheader = "Update can't be achieved"
                    alertdetail = "Minimum OS Version \(minSystemVersion) is greater than current OS version \(HCVersion.OSnum)"
                    print("\(thisComponent) : \(alertheader) \(alertdetail)")
                    _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                    isUpdateAvailable = false
                    return
                } else {
                    print("\(thisComponent) : Update (with \(minSystemVersion) as minimum OS version ) is allowed on current OS version \(HCVersion.OSnum)")
                }
            }
        }

        //MARK: this new .app allowed current app is removed before installing new one
        if isUpdateAvailable && InitGlobVar.defaultfileManager.fileExists(atPath: InitGlobVar.thisAppliLocation) {
            while (!InitGlobVar.defaultfileManager.fileExists(atPath: exeToSearch)) {
                Thread.sleep(forTimeInterval: 0.2)
            }
            print("\(thisComponent) : Removing Old App...")
            notify(title: "Removing Old App...", informativeText: "")
            if InitGlobVar.defaultfileManager.fileExists(atPath: InitGlobVar.thisAppliLocation) {
                do {
                    try InitGlobVar.defaultfileManager.removeItem(atPath: "\(InitGlobVar.thisAppliLocation)")
                    print("\(thisComponent) : Directory \(InitGlobVar.thisAppliLocation) deleted successfully")
                } catch {
                    print("\(thisComponent) : Error deleting Directory \(InitGlobVar.thisAppliLocation) with error : (\(error))")
                    alertheader = "Failed to delete the old copy of"
                    alertdetail = "\(InitGlobVar.thisAppliLocation)\nPlease make sure it is in \(InitGlobVar.allAppliLocation) folder!!!"
                    print("\(thisComponent) : \(alertheader) \(alertdetail)")
                    _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                    isUpdateAvailable = false
                    return
                }
            }
        }

        //MARK: current app removed new one replaces it
        if isUpdateAvailable {
            print("\(thisComponent) : Copying New Version \"/\(thisApplicationName).app\" Almost there!")
            notify(title: "New Version Install...", informativeText: "")
            guard run("/bin/mv -f \(InitGlobVar.athDirectory)\"/\(thisApplicationName).app\" \(InitGlobVar.allAppliLocation)") == "" else {
                alertheader = "Can't replace application"
                alertdetail = "\"\(thisApplicationName)\""
                print("\(thisComponent) : \(alertheader) \(alertdetail)")
                _ = updateAlert(message: "\(alertheader)", text: "\(alertdetail)", buttonArray: ["Return"])
                isUpdateAvailable = false
                return
            }
        }

        //MARK: update complete, that's all folks
        if isUpdateAvailable {
            while (!InitGlobVar.defaultfileManager.fileExists(atPath: InitGlobVar.thisAppliLocation)) {
                Thread.sleep(forTimeInterval: 0.2)
            }
            if isUpdateAvailable {
                print("\(thisComponent) : Update Complete!...Launching New \"\(thisApplicationName).app\" Version...")
                notify(title: "Update Complete...Launching  New Version...", informativeText: "")
                _ = run("/usr/bin/open \"\(InitGlobVar.thisAppliLocation)\"")
                exit(0)
            }
        }
    }
    
    static func updateAlert(message: String, text: String, buttonArray: [String]) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = text
        alert.alertStyle = .critical
        buttonArray.forEach { buttonAlerte in
            alert.addButton(withTitle: buttonAlerte)
        }
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }

    static func notify(title: String, informativeText: String) -> Void {
        notificationID += 1
        if #available(macOS 10.14, *) {
            let notification   = UNMutableNotificationContent()
            notification.title = title
            notification.body  = informativeText
            notification.sound = UNNotificationSound.default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "ATH \(notificationID)", content: notification, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { (error) in
                if (error != nil) {
                    print("\(thisComponent) : \(String(describing: error))!")
                }
            }
        } else { // macOS 10.13 and less
            let notification = NSUserNotification()
            notification.identifier = "ATH \(notificationID)"
            notification.title = title
            notification.informativeText = informativeText
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }

    static func checkFileExtension(atPath path: String, withExtensions fileExtensionInArray:[String]) -> String {
        let pathURL = NSURL(fileURLWithPath: path, isDirectory: true)
        var fileNameToReturn: String = ""
        if let enumerator = InitGlobVar.defaultfileManager.enumerator(atPath: path) {
            for file in enumerator {
                let pathElement = NSURL(fileURLWithPath: file as! String, relativeTo: pathURL as URL).path
                print("\(thisComponent) : Element from archive : \(String(describing: pathElement))")
                if pathElement?.replacingOccurrences(of: "%20", with: " ").contains("\(InitGlobVar.athDirectory)/\(thisApplicationName)") ?? false {
                    fileExtensionInArray.forEach { extention in
                        if pathElement?.hasSuffix(extention) ?? false {
                            fileNameToReturn = pathElement?.replacingOccurrences(of: "%20", with: " ") ?? ""
                        }
                    }
                }
           }
        }
        print("\(thisComponent) : Element returned \(fileNameToReturn)")
        return fileNameToReturn
    }
}
