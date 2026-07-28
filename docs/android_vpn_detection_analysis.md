# Android VPN 检测分析

## 前置澄清：两个问题，不要混为一谈

| 问题 | 含义 |
|---|---|
| 是否**设置了** VPN | 系统设置里是否存在 VPN 配置，不管当前有没有连接 |
| 是否**开启了** VPN | 当前是否有 VPN 隧道正在运行、流量正在经过 VPN 通道 |

关系：

- 开启 VPN 的前提是设置了 VPN
- 设置了 VPN 不代表开启了 VPN
- **真正的关注点是：是否正在开启 VPN**
- 就算 100% 确认"设置了 VPN"，但无法确认"正在开启 VPN"，那这个信息没有实际意义

---

## 一、是否设置了 VPN

### 1.1 可用技术手段

| 方案 | 能否判断 | 说明 |
|---|---|---|
| `ConnectivityManager` / `NetworkCapabilities` | 不能 | 只反映当前网络状态，不读取配置数据库 |
| `NetworkInterface` 枚举接口 | 不能 | 只反映当前运行中的接口，未连接的 VPN 不会产生接口 |
| `VpnService` | 仅限自己 | 只能知道本 App 提供的 VPN 服务是否存在，不能枚举其他 VPN |
| `DevicePolicyManager.getAlwaysOnVpnPackage()` | 仅限设备管理者 | 需要 Device Owner / Profile Owner 权限，普通 App 不可用 |
| 读取 `/proc/net/route`、`/proc/net/if_inet6` 等 | 不能 | 只反映当前路由/接口状态，不反映未激活的配置 |

### 1.2 结论

**普通 Android App 无法系统级判断"设备是否设置了 VPN"。**

只有企业管控场景（Device Owner / MDM）可以部分做到，但这不适用于普通上架应用。

---

## 二、是否已经开启 VPN（真正的关注点）

### 2.1 可用技术手段

#### 方案一：`ConnectivityManager` + `NetworkCapabilities`（推荐，最正规）

```kotlin
val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
val activeNetwork = cm.activeNetwork
val caps = cm.getNetworkCapabilities(activeNetwork)
val isVpn = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
```

| 维度 | 说明 |
|---|---|
| 能做什么 | 判断当前活动网络是否具备 `TRANSPORT_VPN` 传输类型 |
| 准确性 | 对大多数标准 VPN 实现（IKEv2、OpenVPN、WireGuard 等通过 `VpnService` 建立的）准确率很高 |
| 不能做什么 | 不能枚举所有 VPN 配置；不能判断未激活的 VPN；某些非标准代理（HTTP 代理、SOCKS 代理）不一定走 `TRANSPORT_VPN` |
| API 级别 | `NetworkCapabilities` 从 API 21 (Android 5.0) 起可用 |

这是 Android 上判断"当前是否开启 VPN"**最直接、最推荐**的方案，比 iOS 的 `getifaddrs()` 方案更正规。

#### 方案二：`NetworkInterface` 枚举网络接口

```kotlin
val interfaces = NetworkInterface.getNetworkInterfaces()
while (interfaces.hasMoreElements()) {
    val iface = interfaces.nextElement()
    // 检查 tun0, ppp0, ipsec* 等接口名
}
```

| 维度 | 说明 |
|---|---|
| 能做什么 | 枚举当前运行中的网络接口，通过接口名（`tun0`、`ppp0`、`ipsec*`）和地址特征辅助判断 |
| 不能做什么 | 接口名不是稳定标准，不同 ROM / 厂商 / VPN 实现差异大；单看接口名容易误判 |
| 适合场景 | 作为方案一的**辅助信号**，不建议作为独立判断依据 |

#### 方案三：读取 `/proc/net/route` 等内核信息

| 维度 | 说明 |
|---|---|
| 能做什么 | 查看当前路由表，如果存在指向 `tun0` 等接口的默认路由，辅助判断 VPN 是否在承载流量 |
| 不能做什么 | 从 Android 10 (API 29) 起，`/proc/net` 下部分文件已被限制访问；不同版本行为不一致 |
| 趋势 | Google 在逐步收紧对 `/proc` 文件系统的访问，**不建议依赖** |

#### 方案四：`VpnService.prepare()` 探测（不推荐）

调用 `VpnService.prepare(context)` 如果返回 `null`，说明当前已有 VPN 服务在运行或本 App 已被授权。

| 维度 | 说明 |
|---|---|
| 问题 | 会触发系统权限弹窗（如果当前没有 VPN 运行）；副作用太大，不适合做"静默检测" |
| 结论 | **不推荐用于检测目的** |

### 2.2 方案对比总结

| 方案 | 准确度 | 稳定性 | 侵入性 | 推荐度 |
|---|---|---|---|---|
| `ConnectivityManager` + `TRANSPORT_VPN` | 高 | 高（API 21+） | 低 | 推荐 |
| `NetworkInterface` 枚举 | 中 | 中（接口名不稳定） | 低 | 辅助 |
| `/proc/net/route` | 中 | 低（Android 10+ 受限） | 低 | 不推荐 |
| `VpnService.prepare()` | 低 | 中 | 高（弹窗） | 不推荐 |

### 2.3 结论

**Android 上判断"是否已经开启 VPN"，推荐使用 `ConnectivityManager` + `NetworkCapabilities.TRANSPORT_VPN`。**

这个方案：

- 对标准 VPN 实现的检出率很高
- 是 Google 官方推荐的网络状态查询方式
- 不需要特殊权限（只需 `ACCESS_NETWORK_STATE`，这是最基础的网络权限）

但仍然不能承诺 100%：

- 某些非标准代理（纯 HTTP 代理、SOCKS 代理、不走 `VpnService` 的方案）可能检测不到
- 某些厂商 ROM 对 `NetworkCapabilities` 的实现可能有差异
- 不能排除极端情况下的假阳性或假阴性

**定性结论：能做到"较高置信度判断当前是否正在通过 VPN 传输"，不能做到"系统级 100% 确认"。**

---

## 三、Android vs iOS 对比

| 维度 | iOS | Android |
|---|---|---|
| 判断"是否设置了 VPN" | 不能（普通 App） | 不能（普通 App） |
| 判断"是否开启了 VPN" | 可以，高置信度（`getifaddrs()` + 地址特征） | 可以，高置信度（`ConnectivityManager` + `TRANSPORT_VPN`） |
| 推荐方案 | `getifaddrs()` 枚举接口 + 隧道地址特征分析 | `ConnectivityManager` + `NetworkCapabilities` |
| 方案直接程度 | 间接：需要自己分析接口名和地址特征 | 直接：系统 API 直接告诉你是否有 `TRANSPORT_VPN` |
| 所需权限 | 无需特殊权限 | `ACCESS_NETWORK_STATE`（基础权限） |
| 假阳性风险 | 较高（iCloud Private Relay、Wi-Fi Calling 等也用 `utun*`） | 较低（`TRANSPORT_VPN` 语义比较明确） |
| API 稳定性 | 不稳定（BSD 接口名不是 API，Apple 可能收紧） | 较稳定（`NetworkCapabilities` 是官方推荐 API） |
| 能否 100% 确认 | 不能 | 不能 |

简单说：**Android 在这件事上比 iOS 更友好**——有更直接的官方 API，假阳性风险更低，权限要求更简单。

---

## 四、Google Play 上架合规性分析

### 4.1 结论

**使用 `ConnectivityManager` + `NetworkCapabilities` 判断 VPN 状态，符合 Google Play 上架要求。**

### 4.2 为什么风险比 iOS 更低

- `ConnectivityManager` 和 `NetworkCapabilities` 是 Android 官方推荐的网络状态 API，不是"灰色地带"API
- `ACCESS_NETWORK_STATE` 是最基础的网络权限，几乎所有联网 App 都声明了
- 不涉及枚举底层接口细节、不读取 `/proc` 文件系统、不触发权限弹窗
- Google 没有像 Apple 那样对"设备指纹"采取同等力度的打击（但也在逐步收紧）

### 4.3 仍需注意的风险点

| 风险 | 说明 |
|---|---|
| 用途合理性 | 如果 App 主功能与网络诊断无关，仍可能被质疑"为什么要检测 VPN" |
| 数据使用 | 如果将 VPN 状态上传到服务器用于风控/封禁/画像，可能违反 Google Play 的数据收集政策 |
| Data Safety 声明 | Google Play 要求在 Data Safety 区域声明收集的数据类型；如果收集网络状态信息需要如实声明 |
| 用户体验 | 如果检测到 VPN 就限制功能或弹窗警告，可能引起用户投诉和差评 |

### 4.4 上架建议

1. 优先使用 `ConnectivityManager` + `NetworkCapabilities`，不要用 `/proc/net` 等底层方案
2. 用途表述为"网络诊断 / 连接质量检测"
3. 不上传原始网络状态数据，只在本地判断
4. 在 Google Play Data Safety 中如实声明
5. 不要因为检测到 VPN 就封禁用户或限制核心功能

### 4.5 上架判断一句话

> Android 上使用 `ConnectivityManager` + `NetworkCapabilities.TRANSPORT_VPN` 判断当前是否通过 VPN 传输，是官方推荐的网络状态查询方式，上架风险极低；但仍应避免滥用检测结果，且在 Data Safety 中如实声明。

---

## 五、最终定性

### 关于"是否设置了 VPN"

**普通 Android App 无法系统级判断。与 iOS 一致。**

### 关于"是否已经开启 VPN"

**可以通过 `ConnectivityManager` + `TRANSPORT_VPN` 做较高置信度判断，比 iOS 方案更直接、假阳性更低；但仍不能承诺系统级 100% 确认。**

### 关于上架

**符合 Google Play 上架要求，风险比 iOS 更低。**
