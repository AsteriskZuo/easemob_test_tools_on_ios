//
//  VPNChecker.swift
//  sdkTest
//
//  Created by asterisk on 2026/4/16.
//

import Foundation
import UIKit
import Darwin

class VPNChecker {
    
    /// 打印当前进程可见的 socket 端口信息（本地端口 + 对端端口）
    /// 注意：iOS 沙盒下无法直接枚举系统全局所有进程端口，这里是当前 App 进程范围。
    private static func printAllPortInfoForCurrentProcess() {
        print("===== Port Dump Begin (Current Process) =====")
        
        let openMax = sysconf(Int32(_SC_OPEN_MAX))
        let maxFD = openMax > 0 ? Int(openMax) : 1024
        var socketCount = 0
        
        for fd in 0..<maxFD {
            var localStorage = sockaddr_storage()
            var localLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
            
            let localResult = withUnsafeMutablePointer(to: &localStorage) { storagePtr in
                storagePtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    getsockname(Int32(fd), sockPtr, &localLen)
                }
            }
            
            guard localResult == 0 else { continue }
            socketCount += 1
            
            let local = describeSocketAddress(localStorage)
            
            var peerStorage = sockaddr_storage()
            var peerLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let peerResult = withUnsafeMutablePointer(to: &peerStorage) { storagePtr in
                storagePtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    getpeername(Int32(fd), sockPtr, &peerLen)
                }
            }
            
            let type = socketTypeName(fd: Int32(fd))
            let localPortText = local.port.map(String.init) ?? "-"
            
            if peerResult == 0 {
                let peer = describeSocketAddress(peerStorage)
                let peerPortText = peer.port.map(String.init) ?? "-"
                print("[fd=\(fd)] \(type) \(local.family) local=\(local.ip):\(localPortText) peer=\(peer.ip):\(peerPortText)")
            } else {
                print("[fd=\(fd)] \(type) \(local.family) local=\(local.ip):\(localPortText) peer=-")
            }
        }
        
        if socketCount == 0 {
            print("No socket fd found in current process.")
        }
        
        print("===== Port Dump End (Current Process), total sockets: \(socketCount) =====")
    }
    
    private static func describeSocketAddress(_ storage: sockaddr_storage) -> (family: String, ip: String, port: UInt16?) {
        var copy = storage
        let family = Int32(copy.ss_family)
        
        if family == AF_INET {
            let addr = withUnsafePointer(to: &copy) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            }
            let ip = ipv4String(addr.sin_addr)
            let port = UInt16(bigEndian: addr.sin_port)
            return ("IPv4", ip, port)
        }
        
        if family == AF_INET6 {
            let addr = withUnsafePointer(to: &copy) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
            }
            let ip = ipv6String(addr.sin6_addr)
            let port = UInt16(bigEndian: addr.sin6_port)
            return ("IPv6", ip, port)
        }
        
        return ("AF_\(family)", "-", nil)
    }
    
    private static func ipv4String(_ input: in_addr) -> String {
        var addr = input
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        
        let result: UnsafePointer<CChar>? = buffer.withUnsafeMutableBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return nil }
            return withUnsafePointer(to: &addr) { ptr in
                inet_ntop(AF_INET, ptr, base, socklen_t(INET_ADDRSTRLEN))
            }
        }
        
        guard result != nil else { return "unknown" }
        return String(cString: buffer)
    }
    
    private static func ipv6String(_ input: in6_addr) -> String {
        var addr = input
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        
        let result: UnsafePointer<CChar>? = buffer.withUnsafeMutableBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return nil }
            return withUnsafePointer(to: &addr) { ptr in
                inet_ntop(AF_INET6, ptr, base, socklen_t(INET6_ADDRSTRLEN))
            }
        }
        
        guard result != nil else { return "unknown" }
        return String(cString: buffer)
    }
    
    private static func socketTypeName(fd: Int32) -> String {
        var type: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_TYPE, &type, &len) == 0 else {
            return "SOCK?"
        }
        
        switch type {
        case SOCK_STREAM:
            return "STREAM"
        case SOCK_DGRAM:
            return "DGRAM"
        case SOCK_RAW:
            return "RAW"
        default:
            return "TYPE_\(type)"
        }
    }
    
    private static func interfaceFamilyName(_ addr: UnsafeMutablePointer<sockaddr>?) -> String {
        guard let addr else { return "AF_UNSPEC" }
        switch Int32(addr.pointee.sa_family) {
        case AF_INET:
            return "IPv4"
        case AF_INET6:
            return "IPv6"
        case AF_LINK:
            return "LINK"
        default:
            return "AF_\(addr.pointee.sa_family)"
        }
    }
    
    private static func interfaceAddressString(_ addr: UnsafeMutablePointer<sockaddr>?) -> String {
        guard let addr else { return "-" }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            addr,
            socklen_t(addr.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return "-" }
        return String(cString: host)
    }
    
    private static func interfaceFlagsDescription(_ flags: Int32) -> String {
        var parts: [String] = []
        if (flags & IFF_UP) == IFF_UP { parts.append("UP") }
        if (flags & IFF_RUNNING) == IFF_RUNNING { parts.append("RUNNING") }
        if (flags & IFF_POINTOPOINT) == IFF_POINTOPOINT { parts.append("POINTOPOINT") }
        if (flags & IFF_LOOPBACK) == IFF_LOOPBACK { parts.append("LOOPBACK") }
        if (flags & IFF_BROADCAST) == IFF_BROADCAST { parts.append("BROADCAST") }
        if (flags & IFF_MULTICAST) == IFF_MULTICAST { parts.append("MULTICAST") }
        return parts.isEmpty ? "NONE" : parts.joined(separator: "|")
    }
    
    private static func isVPNInterfaceName(_ name: String) -> Bool {
        return name.hasPrefix("utun") ||
            name.hasPrefix("ppp") ||
            name.hasPrefix("tap") ||
            name.hasPrefix("tun") ||
            name.hasPrefix("ipsec")
    }
    
    private static func isLinkLocalOrLoopbackAddress(_ address: String) -> Bool {
        if address == "-" || address.isEmpty { return true }
        if address == "127.0.0.1" || address == "::1" { return true }
        if address.hasPrefix("169.254.") { return true }
        
        let scoped = address.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? address
        if scoped.lowercased().hasPrefix("fe80:") { return true }
        return false
    }
    
    /// 检测设备当前是否开启了 VPN
    /// - Returns: true 表示大概率开启了 VPN，false 表示未开启
    static func isVPNConnected() -> Bool {
        // printAllPortInfoForCurrentProcess()
        
        var isVPNActive = false
        var interfaces: UnsafeMutablePointer<ifaddrs>? = nil
        var vpnFlagsByName: [String: Int32] = [:]
        var vpnAllAddrsByName: [String: [String]] = [:]
        var vpnNonLinkAddrsByName: [String: [String]] = [:]
        
        // 1. 获取设备所有的网络接口列表
        // 注意：这个底层的 C API 就是苹果隐私扫描的重点监控对象之一
        guard getifaddrs(&interfaces) == 0 else {
            return false
        }
        guard let firstInterface = interfaces else {
            return false
        }
        
        // 2. 遍历底层的网络接口链表
        var index = 0
        for ifptr in sequence(first: firstInterface, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let name = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            let family = interfaceFamilyName(interface.ifa_addr)
            let addr = interfaceAddressString(interface.ifa_addr)
            let netmask = interfaceAddressString(interface.ifa_netmask)
            let dst = interfaceAddressString(interface.ifa_dstaddr)
            let flagDesc = interfaceFlagsDescription(flags)
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            
            print("[ifaddrs #\(index)] name=\(name), family=\(family), addr=\(addr), netmask=\(netmask), dst=\(dst), flags=0x\(String(flags, radix: 16))[\(flagDesc)]")
            print("-------------------------------")
            
            index += 1
        }
        
        // 5. 释放 C 语言指针内存
        freeifaddrs(interfaces)
        
        return isVPNActive
    }
}

// 在 ViewController 中使用的示例：
/*
let vpnStatus = VPNChecker.isVPNConnected()
if vpnStatus {
    print("系统当前正在使用 VPN")
} else {
    print("系统当前未使用 VPN")
}
*/
