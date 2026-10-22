# 项目约定

- 用户的数据至关重要。不要卸载应用、清除应用数据，或为解决安装问题更换包名和签名。使用原签名通过 `adb install -r` 覆盖安装。
- 每次交付有新改动的安装包，都必须先更新 `pubspec.yaml` 的版本号和构建号。构建号必须大于设备已安装的 `versionCode`；不要用同一版本号反复交付不同改动。
- 安装前核对最终 APK 的包名、版本和签名；安装成功后读取手机上的 `versionName` 与 `versionCode`，确认新版本实际生效。
- 设置页版本信息应从已安装的包读取，不能另写一个固定版本字符串。
- 默认使用 `make release-apk` 和已有 JBR 17 构建配置。保护 `android/key.properties` 与 keystore，不输出密钥内容。
