//
//  MainNavigationView.swift
//  sdkTest
//
//  Created on 2026/02/03.
//

import SwiftUI
import UIKit

// MARK: - Navigation Item Model

struct NavigationItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: NavigationDestination
}

enum NavigationDestination {
    case envLoginTest
    case lz4CompressionTest
    case mediaFilePicker
    case sendImageMessage
    case userToken
    case multiBodiesMessage
    case sdkLogin
    case apiTester
}

// MARK: - Main Navigation View

struct MainNavigationView: View {
    @State private var selectedDestination: NavigationDestination?
    
    private let navigationItems: [NavigationItem] = [
        NavigationItem(
            title: "环境与密码登录",
            subtitle: "独立环境配置 + 反射密码登录（迁移自旧 sdkTest 页面）",
            icon: "network.badge.shield.half.filled",
            color: .indigo,
            destination: .envLoginTest
        ),
        NavigationItem(
            title: "登录与初始化",
            subtitle: "可选初始化参数与共享登录状态",
            icon: "person.crop.circle.badge.checkmark",
            color: .blue,
            destination: .sdkLogin
        ),
        NavigationItem(
            title: "LZ4 压缩测试",
            subtitle: "测试 LZ4 压缩日志收集与统计",
            icon: "archivebox.fill",
            color: .orange,
            destination: .lz4CompressionTest
        ),
        NavigationItem(
            title: "媒体文件选择",
            subtitle: "测试相册和文件管理器路径获取",
            icon: "photo.on.rectangle.angled",
            color: .green,
            destination: .mediaFilePicker
        ),
        NavigationItem(
            title: "发送图片消息",
            subtitle: "初始化、登录、发送图片消息、退出登录",
            icon: "photo.badge.arrow.down.fill",
            color: .purple,
            destination: .sendImageMessage
        ),
        NavigationItem(
            title: "用户 Token",
            subtitle: "通过 Bearer Token 获取用户登录 Token",
            icon: "key.fill",
            color: .teal,
            destination: .userToken
        ),
        NavigationItem(
            title: "多 bodies 消息",
            subtitle: "自由组合文本、图片和文件，验证收发与附件回调",
            icon: "square.stack.3d.up.fill",
            color: .cyan,
            destination: .multiBodiesMessage
        ),
        NavigationItem(
            title: "API 调用",
            subtitle: "搜索已注册 API，编辑 JSON 参数并调用",
            icon: "terminal.fill",
            color: .brown,
            destination: .apiTester
        ),
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("SDK Test")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("选择一个测试模块")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Navigation Cards
                    ForEach(navigationItems) { item in
                        NavigationCard(item: item) {
                            navigateTo(item.destination)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func navigateTo(_ destination: NavigationDestination) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let navigationController = window.rootViewController as? UINavigationController else {
            return
        }
        
        let viewController: UIViewController
        
        switch destination {
        case .envLoginTest:
            let envLoginViewController = EnvLoginTestViewController()
            envLoginViewController.title = "环境与密码登录"
            envLoginViewController.edgesForExtendedLayout = []
            viewController = envLoginViewController

        case .sdkLogin:
            let hostingController = UIHostingController(rootView: SDKLoginView())
            hostingController.title = "登录与初始化"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController

        case .multiBodiesMessage:
            let hostingController = UIHostingController(rootView: MultiBodiesMessageTest())
            hostingController.title = "多 bodies 消息"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController

        case .lz4CompressionTest:
            let lz4View = LZ4CompressionTestView()
            let hostingController = UIHostingController(rootView: lz4View)
            hostingController.title = "LZ4 压缩测试"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController
            
        case .mediaFilePicker:
            let mediaPickerView = MediaFilePickerTest()
            let hostingController = UIHostingController(rootView: mediaPickerView)
            hostingController.title = "媒体文件选择"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController
            
        case .sendImageMessage:
            let sendImageView = SendImageMessageTest()
            let hostingController = UIHostingController(rootView: sendImageView)
            hostingController.title = "发送图片消息"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController

        case .userToken:
            let tokenView = EasemobUserTokenView()
            let hostingController = UIHostingController(rootView: tokenView)
            hostingController.title = "用户 Token"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController

        case .apiTester:
            let hostingController = UIHostingController(rootView: ApiTestListView())
            hostingController.title = "API 调用"
            hostingController.edgesForExtendedLayout = []
            viewController = hostingController
        }
        
        navigationController.pushViewController(viewController, animated: true)
    }
}

// MARK: - Navigation Card Component

struct NavigationCard: View {
    let item: NavigationItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundColor(item.color)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MainNavigationView()
}
