# 任务计划

在现有项目中实现一个读取文件、发送消息、输出消息统计的工具。

- 读取文件：指定文件夹，读取文件夹中的所有文件，每一个文件都是多行json格式（每一行都是json格式，但是整个文件不符合json格式），每一行的json格式（payload.bodies[0].action 作为消息的文本）
  - 示例文件: ../2026012714
  - 示例格式：
    ```json
    {
      "channel_channel": "1131230112212288#heizai_1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10@easemob.com",
      "os": "android",
      "ip": "14.31.161.127",
      "expire_time": 1772593031397,
      "sdk_service_id": "81400045-2700-43a9-9685-bbbf88cc98e3",
      "meta_ext": {
        "chat_type": "chat:user",
        "write_channel": true,
        "route_type": "route_online",
        "msg_type": "command",
        "chat_route_target": "self",
        "chat_route": "route_online:chat:user:command",
        "client_id": 17700010310050245
      },
      "version": "4.13.0",
      "meta_timestamp": 1770001031395,
      "channel_user": "1131230112212288#heizai_1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10@easemob.com",
      "chat_type": "chat",
      "is_downgrade": false,
      "content_type": "chat:user:command",
      "payload": {
        "ext": {},
        "bodies": [
          {
            "action": "{\"data\":\"{\\\"aa\\\":\\\"\\\",\\\"lat\\\":22.422998972739148,\\\"lng\\\":112.61579366651023,\\\"loctime\\\":1770001030,\\\"move_status\\\":0,\\\"radius\\\":11.4,\\\"speed\\\":0,\\\"stop_status\\\":false,\\\"stop_time\\\":1769999958}\",\"msg_type\":3}",
            "type": "cmd"
          }
        ],
        "meta": {},
        "from": "1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10",
        "to": "1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10",
        "type": "chat"
      },
      "writed_channel": false,
      "name": "1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10",
      "from": "1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10",
      "to": "1_hebao_d42d7a45-c5a3-4728-a29d-5224d67955e01740243212_10",
      "msg_id": "1513702087723063076",
      "client_resource": "android_fd143ca0-7190-4b4a-852a-449e46a7b31b",
      "direction": "outgoing",
      "timestamp": 1770001031395
    }
    ```
- 发送消息：
  - 手动发送：
    - 点击发送按钮，发送一条消息，消息内容来自 payload
  - 自动发送：
    - 每 xxx 毫秒发送一条消息
    - 发送成功之后，继续 每 xxx 毫秒发送下一条消息
    - 直到指定文件内容读取完毕 或者 点击了 停止发送按钮
- 输出消息统计：
  - 读取日志，统计消息的压缩率。
  - 格式为：
    - 开启lz4日志的标记：`[0][2026/02/02 13:54:39:486(08)]: log: level: 2, area: 1, LZ4 COMP:2|2`
    - lz4压缩日志：`[0][2026/02/02 13:54:39:487(08)]: log: level: 0, area: 4, LZ4 compress success: compressed size=21 bytes, original size=19, ratio=110.526314 %, compress_ratio_<100%=10, compress_ratio_>=100%=4`
    - lz4解压缩日志：`[0][2026/02/02 13:54:39:610(08)]: log: level: 0, area: 4, LZ4 compress success: compressed size=33 bytes, original size=35, ratio=94.285713 %, compress_ratio_<100%=12, compress_ratio_>=100%=4`

使用UI的方式进行操作：

界面要求如下：

- 用户可以输入 appkey
- 用户可以输入 用户名、密码
- 用户可以手动点击登录和退出
- 用户可以选择文件夹，直接输入文件夹路径
- 用户可以设置发送间隔
- 用户可以点击开始发送，开始自动发送消息
- 用户可以点击停止发送，停止自动发送消息
- 用户可以点击手动发送消息，发送一条消息
- 用户可以点击统计，统计消息的压缩率，同时也重置统计信息，统计信息将保存到指定的 output.md 文件中，格式为表格(时间、compressed size、original size、ratio)。统计信息来自日志，日志关键字是 LZ4 compress success 和 LZ4 compress success。
- 该页面是独立的UI页面，使用swiftui进行开发, 从 ViewController.swift 的testAction 方法 弹出，不可以返回。
- 统计的信息保存在  `[0][2026/02/02 13:41:37:011(08)]: log path: /Users/asterisk/Library/Developer/CoreSimulator/Devices/4BEA133B-4B24-430F-96FC-924632C2CF53/data/Containers/Data/Application/91B54677-C6F9-4273-A07C-E96CC0F15302/Library/Application Support/HyphenateSDK/easemobLog` 这个文件夹，
