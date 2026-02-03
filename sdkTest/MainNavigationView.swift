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
    case viewController
    case lz4CompressionTest
    case mediaFilePicker
}

// MARK: - Main Navigation View

struct MainNavigationView: View {
    @State private var selectedDestination: NavigationDestination?
    
    private let navigationItems: [NavigationItem] = [
        NavigationItem(
            title: "SDK 测试",
            subtitle: "原始 ViewController - 登录、发消息等",
            icon: "message.fill",
            color: .blue,
            destination: .viewController
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
        )
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
        case .viewController:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateInitialViewController() as? ViewController {
                viewController = vc
                viewController.title = "SDK 测试"
            } else {
                return
            }
            
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
