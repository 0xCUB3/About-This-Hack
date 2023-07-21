//
//  HCBootloader.swift
//  About This Hack
//
//  Created by Felix on 16.07.23.
//

import Foundation

class HCBootloader {
    
    
    static func getBootloader() -> String {
        var BootloaderInfo: String = ""
        BootloaderInfo = run("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version | awk '{print $2}' | awk -F'-' '{print $2}'")
        if BootloaderInfo != "" {
            BootloaderInfo = run("echo \"OpenCore - Version \" $(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version | awk '{print $2}' | awk -F'-' '{print $2}' | sed -e 's/ */./g' -e s'/^.//g' -e 's/.$//g' -e 's/ .//g' -e 's/. //g' | tr -d '\n') $( nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version | awk '{print $2}' | awk -F'-' '{print $1}' | sed -e 's/REL/(Release)/g' -e s'/N\\/A//g' -e 's/DEB/(Debug)/g' | tr -d '\n')")
        }
        else {
            BootloaderInfo = run("cat ~/.ath/scr.txt | grep \"Clover\" | awk '{print $4,\"r\" $6,\"(\" $9,\" \"}' | tr -d '\n'")
            if BootloaderInfo  != "" {
                BootloaderInfo += run("echo \"(\"$(/usr/local/bin/bdmesg | grep -i \"Build with: \\[Args:\" | awk -F '\\-b' '{print $NF}' |  awk -F '\\-t' '{print $1 $2}' | awk  '{print $2}' | awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}') $(/usr/local/bin/bdmesg | grep -i \"Build with: \\[Args:\" | awk -F '\\-b' '{print $NF}' |  awk -F '\\-t' '{print $1 $2}' | awk  '{print $1}' | awk '{print toupper(substr($0,0,1))tolower(substr($0,2))}')\")\"")
            }
            else {
                BootloaderInfo = "Apple UEFI"
            }
        }
        return BootloaderInfo
    }
    
    
}