# iOS VPN 检测分析

## 背景

通过 `VPNChecker.swift` 在 iPhone 真机上运行，利用底层 C API `getifaddrs()` 枚举所有网卡接口，分析设备 VPN 状态。

## 核心问题

1. iPhone 手机是否设置了 VPN？
2. iPhone 手机是否已经开启 VPN？

---

## 一、检测原理

代码通过 `getifaddrs()` 遍历所有网络接口，筛选名字以 `utun / ppp / tap / tun / ipsec` 开头的接口，按以下维度打分：

- 是否带 `IFF_UP` 标志
- 是否绑定"非链路本地 / 非环回"的 IPv4/IPv6 地址

日志中 `VPN_IF_SUMMARY` 输出三种结果：

| result 值 | 含义 |
|---|---|
| `NO_VPN_IF_UP` | 没有任何 VPN 类接口处于 UP 状态 |
| `VPN_IF_EXISTS_BUT_NO_TUNNEL_ADDR` | 有 VPN 类接口 UP，但只有链路本地/环回地址 |
| `LIKELY_UP_WITH_TUNNEL_ADDR` | 有 VPN 类接口 UP 且绑定了真实隧道 IP |

## 二、能力边界

### 问题 2（是否已开启 VPN）：可以判断，但有误判

- `LIKELY_UP_WITH_TUNNEL_ADDR` → 大概率 VPN 已连接
- 需排除假阳性：iCloud Private Relay、个人热点、Wi-Fi Calling、FaceTime relay、AWDL/Handoff 等

### 问题 1（是否设置了 VPN）：基本判断不出来

- iOS 即便未配置任何 VPN，`utun0/1/2` 也几乎总是存在
- VPN "已配置但未连接"时，`getifaddrs()` 里不会出现对应的运行中接口
- 想判断"是否配置了 VPN Profile"需要走 `NEVPNManager` / `NETunnelProviderManager` API，但只能读到自己 App 配置的 VPN

---

## 三、真机日志分析（2026-04-16）

### 3.1 完整日志

```
[ifaddrs #0] name=lo0, family=LINK, addr=, netmask=-, dst=-, flags=0x8049[UP|RUNNING|LOOPBACK|MULTICAST]
[ifaddrs #1] name=lo0, family=IPv4, addr=127.0.0.1, netmask=255.0.0.0, dst=127.0.0.1, flags=0x8049[UP|RUNNING|LOOPBACK|MULTICAST]
[ifaddrs #2] name=lo0, family=IPv6, addr=::1, netmask=ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff, dst=::1, flags=0x8049[UP|RUNNING|LOOPBACK|MULTICAST]
[ifaddrs #3] name=lo0, family=IPv6, addr=fe80::1%lo0, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8049[UP|RUNNING|LOOPBACK|MULTICAST]
[ifaddrs #4] name=XHC0, family=LINK, addr=, netmask=-, dst=-, flags=0x0[NONE]
[ifaddrs #5] name=pdp_ip0, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #6] name=pdp_ip3, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #7] name=pdp_ip2, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #8] name=pdp_ip4, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #9] name=pdp_ip1, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #10] name=pdp_ip5, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #11] name=pdp_ip6, family=LINK, addr=, netmask=-, dst=-, flags=0x8010[POINTOPOINT|MULTICAST]
[ifaddrs #12] name=ipsec0, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #13] name=ipsec1, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #14] name=ipsec2, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #15] name=utun0, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #16] name=utun0, family=IPv6, addr=fe80::4132:3d8d:9cde:fec9%utun0, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #17] name=anpi0, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #18] name=anpi0, family=IPv6, addr=fe80::d47f:69ff:fee8:3090%anpi0, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #19] name=en1, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #20] name=en2, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #21] name=en2, family=IPv6, addr=fe80::148b:490b:3dd8:3764%en2, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #22] name=en2, family=IPv4, addr=169.254.25.207, netmask=255.255.0.0, dst=169.254.255.255, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #23] name=ap1, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8822[BROADCAST|MULTICAST]
[ifaddrs #24] name=en0, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #25] name=en0, family=IPv6, addr=fe80::86a:ff34:50c3:b477%en0, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #26] name=en0, family=IPv4, addr=10.202.0.65, netmask=255.255.255.0, dst=10.202.0.255, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #27] name=utun1, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #28] name=utun1, family=IPv6, addr=fe80::1a51:e188:f46b:66f6%utun1, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #29] name=awdl0, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #30] name=awdl0, family=IPv6, addr=fe80::6ce0:caff:fe04:ef51%awdl0, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #31] name=llw0, family=LINK, addr=02:00:00:00:00:00, netmask=-, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #32] name=llw0, family=IPv6, addr=fe80::6ce0:caff:fe04:ef51%llw0, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8863[UP|RUNNING|BROADCAST|MULTICAST]
[ifaddrs #33] name=utun2, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #34] name=utun2, family=IPv6, addr=fe80::5a1a:4bdd:459f:5ad%utun2, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #35] name=utun3, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #36] name=utun3, family=IPv6, addr=fe80::ce81:b1c:bd2c:69e%utun3, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #37] name=utun4, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #38] name=utun4, family=IPv6, addr=fe80::2879:66f3:b6:8366%utun4, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #39] name=utun6, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #40] name=utun6, family=IPv6, addr=fe80::25df:3a89:a06:29af%utun6, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #41] name=utun5, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #42] name=utun5, family=IPv6, addr=fe80::80e6:82e9:b1fd:7286%utun5, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #43] name=utun5, family=IPv6, addr=fdaf:ad80:df0b::1, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #44] name=utun7, family=LINK, addr=, netmask=-, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #45] name=utun7, family=IPv4, addr=198.18.0.1, netmask=255.255.255.0, dst=198.18.0.1, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #46] name=utun7, family=IPv6, addr=fe80::80e6:82e9:b1fd:7286%utun7, netmask=ffff:ffff:ffff:ffff::, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
[ifaddrs #47] name=utun7, family=IPv6, addr=fd00:1234:ffff::10, netmask=ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff, dst=-, flags=0x8051[UP|RUNNING|POINTOPOINT|MULTICAST]
```

### 3.2 关键接口分析

| # | 接口 | 地址 | 判定 |
|---|---|---|---|
| 12-14 | `ipsec0/1/2` | 无 IP | iOS 系统自带（Wi-Fi Calling / VoLTE / FaceTime），**不是用户 VPN** |
| 15-16 | `utun0` | 仅 `fe80::` | 系统用 utun，无隧道地址 |
| 27-28 | `utun1` | 仅 `fe80::` | 系统用 utun |
| 33-34 | `utun2` | 仅 `fe80::` | 系统用 utun |
| 35-36 | `utun3` | 仅 `fe80::` | 系统用 utun |
| 37-38 | `utun4` | 仅 `fe80::` | 系统用 utun |
| 39-40 | `utun6` | 仅 `fe80::` | 系统用 utun |
| 41-43 | **`utun5`** | `fe80::` + **`fdaf:ad80:df0b::1`** | 很可能是 iCloud Private Relay（ULA IPv6），**不算用户 VPN** |
| **44-47** | **`utun7`** | **`198.18.0.1`** + **`fd00:1234:ffff::10`** | **几乎必定是第三方 VPN/代理应用在运行** |
| 26 | `en0` | `10.202.0.65` | 当前连着 Wi-Fi |

### 3.3 结论

**VPN 已开启。**

关键证据 —— `utun7` 上的 `198.18.0.1`：

- `198.18.0.0/15` 由 RFC 2544 保留用于设备基准测试，真实互联网上不会出现
- iOS 上的"规则代理/VPN"类 App 用 `NEPacketTunnelProvider` 建立 TUN 时，几乎都默认选这个段作为隧道网关
- 同一接口上的 `fd00:1234:ffff::10`（ULA IPv6）也是此类 App 的默认 IPv6 隧道段
- 这个组合是"第三方代理/VPN 应用正在运行"的指纹级信号

典型产品：Shadowrocket / Surge / Quantumult X / Loon / Stash / Clash / Potatso 等。

### 3.4 附带观察

- `utun5` 上的 `fdaf:ad80:df0b::1` 很像 iCloud Private Relay（私密转发），不算用户 VPN
- `en2` 拿到 `169.254.25.207`（link-local），说明有一路以太网/Thunderbolt 未获取 DHCP 地址，与 VPN 判定无关
- 7 个 `pdp_ipN` 是蜂窝数据的 PDP context 槽位，无 IP 且无 UP，正常

---

## 四、判定流程总结

看日志时按以下顺序判定"VPN 是否开启"：

1. 找 `===== VPN_IF_SUMMARY_BEGIN =====` 段落
2. `NO_VPN_IF_UP` → 当前没有开启 VPN（较可靠）
3. `VPN_IF_EXISTS_BUT_NO_TUNNEL_ADDR` → 基本没开启 VPN，看到的是 iOS 自身的 utun
4. `LIKELY_UP_WITH_TUNNEL_ADDR`，再看 `VPN_IF_DETAIL`：
   - 命中名字是 `ppp*/ipsec*/tap*/tun*` → 几乎必定是 VPN
   - 命中名字是 `utun*`、地址是 `100.64.x.x` 或 IPv6 → 可能是 iCloud Private Relay，需要结合其它信息
   - 命中 `utun*` 且绑定 `198.18.x.x` → 第三方代理/VPN App 正在运行
   - 命中 `utun*` 且绑定典型私网 VPN 段（10.x、172.16-31.x、192.168.x） → 基本可判定 VPN 已连接

## 五、局限性

- **无法检测"已配置但未连接"的 VPN**：需要 `NEVPNManager` API，且只能读到自己 App 配置的 VPN
- **假阳性风险**：iCloud Private Relay、个人热点、Wi-Fi Calling 等都可能触发 utun 接口
- **iOS 沙盒限制**：`getifaddrs()` 在 iOS 上越来越受限，未来版本可能进一步收紧

---

## 六、App Store 上架合规性分析

**问题：集成这段 VPN 嗅探代码的 App 是否可以上架 Apple App Store？**

**结论：能上架，但有风险，需要注意几个关键点。**

### 6.1 `getifaddrs()` 本身目前没有被禁

截至 2026-04，Apple **没有正式废弃或封禁** `getifaddrs()`。它仍然是 iOS 上获取网络接口信息的标准 BSD API。Apple DTS 工程师在论坛中也仍在引导开发者使用它。

但 Apple 明确说过："App Review has the final say on what is allowed on the store"。技术上能调用 ≠ 审核一定能过。

### 6.2 主要风险点

#### 风险一：设备指纹（Fingerprinting）—— 最大的雷

Apple 在 App Store Review Guidelines 和开发者协议中明确禁止利用设备信号进行用户追踪/指纹识别。从 2023 年起 Apple 已经在打击利用设备指纹追踪用户的行为。

本代码枚举了所有网络接口名称、IP 地址、flags —— 这些信息组合起来**理论上可以构成设备指纹**。如果审核员认为在做 fingerprinting，会被拒。

**规避方式**：
- 不要把这些数据上传到服务器
- 不要持久化存储接口列表
- 仅在本地做判断，只上报一个布尔值（是/否开启 VPN）

#### 风险二：Privacy Manifest（隐私清单）—— 必须做

从 2024 年 5 月起，Apple 要求所有 App 提交 `PrivacyInfo.xcprivacy` 文件，声明使用的 Required Reason API。虽然 `getifaddrs()` 目前不在 Required Reason API 列表中，但如果 App 还用了其他被列入的 API（如 `UserDefaults`、`NSFileSystemFreeSize` 等），必须一并声明，否则会收到 `ITMS-91053` 拒绝。

#### 风险三：BSD 接口名不是稳定 API

Apple 在开发者论坛中明确说过：

> BSD interface names are not considered API. There's no guarantee that an iPhone's Wi-Fi interface is en0.

这意味着代码里 `isVPNInterfaceName()` 依赖的 `utun/ppp/tap/tun/ipsec` 前缀匹配，**未来 iOS 版本可能失效**，但不会导致审核被拒，只是功能可能不准。

#### 风险四：审核员的主观判断

如果 App 核心功能和 VPN 检测无关（比如是个 IM SDK 测试工具），审核员可能会质疑"为什么需要枚举网络接口"。需要准备好合理的解释，比如：
- 网络诊断 / 连接质量检测
- 帮助用户排查连接问题

### 6.3 上架建议

如果要带着这段代码上架：

1. **去掉详细日志输出**（或改为 `#if DEBUG` 包裹），Release 包不要打印完整的接口列表
2. **不要上传原始接口数据到服务器**，只上报最终判断结果
3. **确保 `PrivacyInfo.xcprivacy` 完整**
4. **在 App 审核备注中说明**用途是"网络诊断"而非"用户追踪"
5. **考虑用 `NWPathMonitor` 替代**部分功能 —— 这是 Apple 推荐的高层 API，可以检测当前网络路径是否经过 VPN（`NWPath` 的 `usesInterfaceType(.other)` 在某些场景下可以间接判断），审核风险更低

### 6.4 风险评估总结

| 维度 | 结论 |
|---|---|
| 技术上能否调用 | 能，`getifaddrs()` 未被封禁 |
| 审核能否通过 | 大概率能，但有被质疑 fingerprinting 的风险 |
| 长期稳定性 | 不保证，Apple 可能随时收紧 |
| 更安全的替代方案 | `NWPathMonitor` + `NEVPNManager`（需 entitlement） |

### 6.5 参考资料

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple cracks down on apps using fingerprinting](https://appleinsider.com/articles/23/07/28/apple-cracks-down-on-apps-identifying-users-through-device-fingerprinting)
- [Network interface names in iOS - Apple Developer Forums](https://developer.apple.com/forums/thread/49581)
- [Privacy Manifest Files - Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

---

## 七、补充说明：utun 接口与 NWPathMonitor / NEVPNManager 的能力边界

### 7.1 `utun1` / `utun*` 到底是什么

`utun0`、`utun1`、`utun2` 这类名字里的 `utun`，指的是 Apple 系统里的 **user tunnel interface**，本质上是**虚拟网络接口（network interface）**，不是端口（port）。

这里要先区分两个概念：

- **接口（interface）**：操作系统里的网络收发通道，比如 `en0`、`pdp_ip0`、`lo0`、`utun1`
- **端口（port）**：TCP/UDP 的逻辑端点，比如 `443`、`3478`、`5222`

所以，`utun1` 的含义是"系统里存在一个编号为 1 的虚拟隧道接口"，**不是**"打开了 1 号 VPN 端口"，也不是某种 socket 端口。

可以把常见接口粗略理解为：

- `en0`：通常是 Wi‑Fi 对应的网络接口
- `pdp_ip0`：通常是蜂窝数据接口
- `lo0`：回环接口（loopback）
- `utun*`：虚拟隧道接口，供系统或某类网络扩展/代理/VPN 功能承载隧道流量

因此，日志里看到 `utun1`、`utun2`、`utun5` 这类名字，本身只说明：**当前系统创建了若干虚拟隧道接口**。它并不自动等价于：

1. 用户在系统设置里手动配置过 VPN
2. 用户当前开启了第三方 VPN
3. 该 `utun` 一定属于某个 VPN App

原因是 iOS/macOS 上不止用户 VPN 会用到 `utun`。一些系统级或平台级网络能力也可能创建 `utun`，例如：

- iCloud Private Relay（私密转发）
- 某些系统代理/中继能力
- 某些通话或连续互通相关的网络隧道场景
- 某些基于 Network Extension 的非传统 VPN 隧道

所以更准确的说法是：

- **看到 `utun*` = 看到虚拟隧道接口存在**
- **看到带典型隧道地址且流量特征明显的 `utun*` = 高概率存在隧道类网络能力在工作**
- **但仅凭 `utun*` 本身，不能 100% 证明“用户开启了 VPN”**

### 7.2 `NWPathMonitor` 能做什么，不能做什么

`NWPathMonitor` 是 Apple 推荐的高层网络路径观察 API。它的核心能力是：**观察当前网络路径（path）如何变化**，而不是读取系统 VPN 设置数据库。

它能做的事情包括：

- 监听网络可达性变化
- 判断当前路径是否可用（`satisfied / unsatisfied`）
- 判断当前路径大致走的是 Wi‑Fi、蜂窝、wired、loopback、other 等接口类型
- 在部分场景下，通过 `NWPath` 的接口类型变化，辅助推测当前流量是否可能经过某种 tunnel / proxy / VPN 通道

但它做不到以下事情：

- **不能枚举系统里配置了哪些 VPN profile**
- **不能告诉你“设置 App 里是否存在某个未连接的 VPN 配置”**
- **不能 100% 断定当前启用的一定是“用户 VPN”而不是系统隧道**
- **不能稳定区分 iCloud Private Relay、系统中继、第三方 VPN、其他 tunnel 型网络扩展**

换句话说，`NWPathMonitor` 更像是：

- 一个**网络路径观测器**
- 一个**运行态特征信号源**
- 不是一个**系统 VPN 配置检查器**

因此，如果目标是：

- "当前网络路径是否疑似经过某种隧道" → `NWPathMonitor` 有辅助价值
- "当前 iPhone 系统是否设置过 VPN" → `NWPathMonitor` 不具备这个能力
- "当前 iPhone 系统是否 100% 开启了用户 VPN" → `NWPathMonitor` 也不能给出系统级确定答案

### 7.3 `NEVPNManager` / `NETunnelProviderManager` 能做什么，不能做什么

`NEVPNManager`、`NETunnelProviderManager` 属于 Network Extension 体系，能力比 `NWPathMonitor` 更接近"VPN 配置与连接管理"，但它们的边界同样很明确。

它们能做的事情包括：

- 在具备相应 entitlement / capability 的前提下，读取和管理**本 App 自己创建、持有或可见**的 VPN 配置
- 观察这些配置对应的连接状态（如 disconnected / connecting / connected）
- 对本 App 管理的 VPN 配置进行保存、加载、启停等操作（前提是权限与产品形态允许）

但它们不能保证做到：

- **系统级枚举“所有”VPN 配置**
- **可靠读取其他 App 创建的所有 VPN 条目**
- **读取系统设置里所有历史 VPN profile 并据此做完整审计**
- **把“系统存在某个 VPN 配置”这个问题，做成面向所有来源的 100% 检查**

也就是说，这套 API 更适合回答的问题是：

- "我这个 App 管理的 VPN 配置是否存在？"
- "我这个 App 管理的 VPN 现在是否已连接？"

而不适合回答的问题是：

- "这台 iPhone 在系统层面到底有没有配置过任何 VPN？"
- "这台 iPhone 当前是否开启了任意来源的 VPN，并且我要 100% 确认？"

### 7.4 最终结论：不要把两类目标混为一谈

后续讨论时，建议明确区分两类能力：

1. **系统 VPN 配置检测器**
   - 目标：检查系统里是否配置过 VPN、是否存在 VPN profile、是否已开启某个系统级 VPN
   - 结论：在普通 App 可用能力范围内，**无法做成系统级 100% 检测**

2. **基于网络接口/路径特征的高置信度识别器**
   - 目标：根据 `getifaddrs()`、`utun*`、隧道地址、`NWPath` 特征，判断当前是否**很可能**存在第三方 VPN / 代理隧道在运行
   - 结论：可以做，而且在部分典型场景下准确率很高，但**本质仍是特征识别，不是系统真值查询**

因此，如果需求是：**“检查当前 iPhone 系统是否有 VPN 设置、是否已开启 VPN，并要求系统级 100% 确定性”**，那么 `NWPathMonitor + NEVPNManager` 这条路线**不满足目标**，也不建议继续把它包装成“系统 VPN 配置检测器”去实现。

更合适的表述应该是：

- 当前方案能做的是：**运行态高置信度识别**
- 当前方案做不到的是：**系统级、全局、100% 确定的 VPN 配置/开启状态检查**

