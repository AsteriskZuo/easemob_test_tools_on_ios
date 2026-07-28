package com.example.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import java.net.NetworkInterface

/**
 * Android VPN 检测工具类
 *
 * 需要权限：<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
 *
 * 用法：
 *   val result = VPNChecker.check(context)
 *   if (result.isVPNActive) { ... }
 */
object VPNChecker {

    data class Result(
        /** 当前活动网络是否带有 TRANSPORT_VPN 标记 */
        val isVPNActive: Boolean,
        /** 当前存在的隧道类网络接口名列表（tun0, ppp0 等） */
        val tunnelInterfaces: List<String>,
        /** 说明文字，用于日志或诊断 */
        val summary: String
    )

    /**
     * 综合判断当前是否有 VPN 正在运行。
     *
     * 主判断：ConnectivityManager + NetworkCapabilities.TRANSPORT_VPN
     * 辅助信号：NetworkInterface 枚举隧道类接口
     */
    fun check(context: Context): Result {
        val transportVPN = checkTransportVPN(context)
        val tunnelIfaces = findTunnelInterfaces()

        val active = transportVPN || tunnelIfaces.isNotEmpty()

        val summary = buildString {
            append("TRANSPORT_VPN=").append(transportVPN)
            if (tunnelIfaces.isNotEmpty()) {
                append(", tunnelInterfaces=").append(tunnelIfaces.joinToString(","))
            } else {
                append(", tunnelInterfaces=none")
            }
        }

        return Result(
            isVPNActive = active,
            tunnelInterfaces = tunnelIfaces,
            summary = summary
        )
    }

    /**
     * 主判断：通过 ConnectivityManager 检查当前活动网络是否具备 TRANSPORT_VPN。
     *
     * 这是 Android 官方推荐的方式，API 21+ 可用。
     * 标准 VPN（IKEv2、OpenVPN、WireGuard 等通过 VpnService 建立的）都会被标记。
     * 纯 HTTP/SOCKS 代理不走 VpnService 的不会被标记。
     */
    private fun checkTransportVPN(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val activeNetwork = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(activeNetwork) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }

    /**
     * 辅助判断：枚举当前运行中的网络接口，查找隧道类接口名。
     *
     * 接口名不是稳定标准，不同厂商 ROM 可能不同，仅作辅助信号。
     */
    private fun findTunnelInterfaces(): List<String> {
        return try {
            val result = mutableListOf<String>()
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return emptyList()
            for (iface in interfaces) {
                val name = iface.name ?: continue
                if (!iface.isUp) continue
                if (isTunnelInterfaceName(name)) {
                    result.add(name)
                }
            }
            result
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun isTunnelInterfaceName(name: String): Boolean {
        return name.startsWith("tun") ||
                name.startsWith("ppp") ||
                name.startsWith("tap") ||
                name.startsWith("ipsec")
    }

    /**
     * 打印完整的网络接口信息，用于开发调试。
     * Release 包不要调用此方法。
     */
    fun dumpAllInterfaces() {
        println("===== Android Network Interface Dump Begin =====")
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return
            var index = 0
            for (iface in interfaces) {
                val name = iface.name ?: "unknown"
                val isUp = iface.isUp
                val addrs = iface.inetAddresses.toList().map { it.hostAddress }
                println("[#$index] name=$name, up=$isUp, addrs=${addrs.ifEmpty { listOf("-") }.joinToString(",")}")
                index++
            }
        } catch (e: Exception) {
            println("Failed to enumerate interfaces: ${e.message}")
        }
        println("===== Android Network Interface Dump End =====")
    }
}
