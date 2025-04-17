//
//  AppDelegate.swift
//  sdkTest
//
//  Created by li xiaoming on 2023/12/12.
//

import UIKit
import UserNotifications
import HyphenateChat

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // 设置UNUserNotificationCenter的delegate
        UNUserNotificationCenter.current().delegate = self
        // 注册APNs权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            // 你可以在这里处理用户对于推送通知权限的授权情况
            if granted {
                // 注册远程通知
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
            }
        }
        
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // 注册远程通知成功时调用
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("didRegisterForRemoteNotificationsWithDeviceToken")
//        DispatchQueue.global().async {
//            EMClient.shared().registerForRemoteNotifications(withDeviceToken: deviceToken) { e in
//                
//            }
//        }
    }
    
    // 注册远程通知失败时调用
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 注册远程通知失败时的处理
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        //EMClient.shared().applicationDidEnterBackground(application)
    }
}

