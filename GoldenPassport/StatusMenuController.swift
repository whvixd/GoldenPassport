//
//  StatusMenuController.swift
//  GoldenPassport
//
//  Created by StanZhai on 2017/2/25.
//  Copyright © 2017年 StanZhai. All rights reserved.
//

import Cocoa
import Swifter

class StatusMenuController: NSObject {
    var addVerifyKeyWindow: AddVerifyKeyWindow!
    var httpPortConfigWindow: HTTPPortConfigWindow!
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var addMenuItem: NSMenuItem!
    @IBOutlet weak var deleteMenuItem: NSMenuItem!
    @IBOutlet weak var httpUrlMenuItem: NSMenuItem!
    var statusItem: NSStatusItem!
    var timerMenuItem: NSMenuItem!
    var authCodeMenuItems: [NSMenuItem] = []
    
    var statusIcon: NSImage!
    var copyIcon: NSImage!
    var removeIcon: NSImage!
    
    var markDeleteVerifiedKey: Bool = false
    var needRefreshCodeMenus: Bool = true
    let authCodeMenuItemTagStartIndex = 100
    var http: HttpServer!
    
    override func awakeFromNib() {
        addVerifyKeyWindow = AddVerifyKeyWindow()
        httpPortConfigWindow = HTTPPortConfigWindow()
        
        loadIcons()
        initStatusItem()
        initStatusMenuItems()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(verifyCodeAdded),
                                       name: NSNotification.Name(rawValue: "VerifyKeyAdded"),
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(httpServerPortChanged),
                                       name: NSNotification.Name(rawValue: "HTTPServerPortChanged"),
                                       object: nil)

        checkAutoStartHttpServer()
    }
    
    private func loadIcons() {
        statusIcon = NSImage(named: "statusIcon")
        statusIcon.size = NSMakeSize(20, 20)
        statusIcon.isTemplate = true
        
        let iconSize = NSMakeSize(14, 14)
        copyIcon = NSImage(named: "copyIcon")
        copyIcon.size = iconSize
        copyIcon.isTemplate = true
        
        removeIcon = NSImage(named: "removeIcon")
        removeIcon.size = iconSize
        removeIcon.isTemplate = true
    }
    
    private func initStatusItem() {
        statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
        statusItem.image = statusIcon
        statusItem.target = self
        statusItem.action = #selector(openMenu)
    }
    
    private func initStatusMenuItems() {
        statusMenu.insertItem(NSMenuItem.separator(), at: 0)
        timerMenuItem = NSMenuItem()
        statusMenu.insertItem(timerMenuItem, at: 0)
    }
    
    func openMenu(_ sender: AnyObject?) {
        updateMenu()
        updateHttpURLMenuItem()
        let runLoop = RunLoop.current
        let timer = Timer(timeInterval: TimeInterval(1), target: self, selector: #selector(updateMenu), userInfo: nil, repeats: true)
        runLoop.add(timer, forMode: RunLoopMode.eventTrackingRunLoopMode)
        statusItem.popUpMenu(statusMenu)
        timer.invalidate()
    }
    
    func updateMenu() {
        let now = Date()
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let dateComponents = calendar.dateComponents([.second], from: now)
        let second = 30 - dateComponents.second! % 30
        
        timerMenuItem.title = "\(EXPIRE_TIME_STR)\(second)s"
        
        let authCodes = DataManager.shared.allAuthCode()
        
        if needRefreshCodeMenus {
            authCodeMenuItems.removeAll()
            
            for menuItem in statusMenu.items {
                if menuItem.tag >= authCodeMenuItemTagStartIndex {
                    statusMenu.removeItem(menuItem)
                }
            }
            
            var idx = 0
            for codeInfo in authCodes {
                let authCodeMenuItem = NSMenuItem()
                authCodeMenuItem.title = "\(codeInfo.key): \(codeInfo.value)"
                authCodeMenuItem.target = self
                authCodeMenuItem.action = #selector(authCodeMenuItemClicked)
                authCodeMenuItem.tag = authCodeMenuItemTagStartIndex + idx
                authCodeMenuItem.toolTip = markDeleteVerifiedKey ? DELETE_VERIFY_KEY_STR : COPY_AUTH_CODE_STR
                authCodeMenuItem.image = markDeleteVerifiedKey ? removeIcon : copyIcon
                authCodeMenuItem.keyEquivalent = "\(idx)"
                authCodeMenuItem.keyEquivalentModifierMask = [.command, .shift]
                authCodeMenuItems.append(authCodeMenuItem)
                statusMenu.insertItem(authCodeMenuItem, at: idx)
                idx = idx + 1
            }
            needRefreshCodeMenus = false
        } else {
            var idx = 0
            for codeInfo in authCodes {
                authCodeMenuItems[idx].title = "\(codeInfo.key): \(codeInfo.value)"
                idx = idx + 1
            }
        }
    }

    func authCodeMenuItemClicked(_ sender: NSMenuItem) {
        let authCodes = DataManager.shared.allAuthCode()
        let dataIdx = sender.tag - authCodeMenuItemTagStartIndex
        if dataIdx < authCodes.count {
            var idx = 0
            for codeInfo in authCodes {
                if idx == dataIdx {
                    if markDeleteVerifiedKey {
                        DataManager.shared.removeOTPAuthURL(tag: codeInfo.key)
                        needRefreshCodeMenus = true
                        updateMenu()
                    } else {
                        let pasteboard = NSPasteboard.general()
                        pasteboard.clearContents()
                        pasteboard.setString(codeInfo.value, forType: NSStringPboardType)
                    }
                    break
                }
                idx = idx + 1
            }
        }
    }
    
    func verifyCodeAdded() {
        needRefreshCodeMenus = true
    }
    
    func httpServerPortChanged() {
        updateHttpURLMenuItem()
        restartHttpServer()
    }
    
    private func updateHttpURLMenuItem() {
        let serverPort = DataManager.shared.getHttpServerPort()
        let url = "http://localhost:\(serverPort)"
        httpUrlMenuItem.title = url
    }

    private func checkAutoStartHttpServer() {
        if (DataManager.shared.getHttpServerAutoStart()) {
            restartHttpServer()
        }
    }
    
    private func restartHttpServer() {
        let serverPort = DataManager.shared.getHttpServerPort()
        if http != nil {
            http.stop()
        }
        
        http = httpServer()
        do {
            try http.start(UInt16(serverPort)!)
        } catch {
            let alert = NSAlert()
            alert.messageText = "HTTP服务启动失败:\n\(error)"
            alert.runModal()
        }
    }
    
    @IBAction func addVerifyClicked(_ sender: NSMenuItem) {
        addVerifyKeyWindow.showWindow(nil)
        addVerifyKeyWindow.window?.makeKeyAndOrderFront(nil)
        addVerifyKeyWindow.clearTextField()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func urlClicked(_ sender: NSMenuItem) {
        let serverPort = DataManager.shared.getHttpServerPort()
        if let url = URL(string: "http://localhost:\(serverPort)") {
            NSWorkspace.shared().open(url)
        }
    }
    
    @IBAction func aboutClicked(sender: NSMenuItem) {
        if let url = URL(string: "https://github.com/stanzhai/GoldenPassport") {
            NSWorkspace.shared().open(url)
        }
    }
    
    @IBAction func deleteClicked(_ sender: NSMenuItem) {
        markDeleteVerifiedKey = !markDeleteVerifiedKey
        
        deleteMenuItem.title = markDeleteVerifiedKey ? DONE_REMOVE_STR : REMOVE_STR
        
        for authCodeMenuItem in authCodeMenuItems {
            authCodeMenuItem.toolTip = markDeleteVerifiedKey ? DELETE_VERIFY_KEY_STR : COPY_AUTH_CODE_STR
            authCodeMenuItem.image = markDeleteVerifiedKey ? removeIcon : copyIcon
        }
        
        if markDeleteVerifiedKey {
            let alert: NSAlert = NSAlert()
            alert.messageText = "已进入删除模式，请到状态栏菜单中删除认证信息。\n\n删除后，请执行`\(DONE_REMOVE_STR)`退出删除模式"
            alert.addButton(withTitle: "确定")
            alert.alertStyle = NSAlertStyle.informational
            alert.runModal()
        }
    }
    
    @IBAction func configHttpPortClicked(_ sender: NSMenuItem) {
        httpPortConfigWindow.showWindow(nil)
        httpPortConfigWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func quitClicked(sender: NSMenuItem) {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
        NSApplication.shared().terminate(self)
    }
}
