# Release Build Log 2026-05-10

## 背景

`lunarix_notes` 在 2026-05-10 生成 Android `release` APK 时，先后遇到了两类环境问题：

1. `Gradle` 依赖下载阶段 TLS 握手失败
2. `release` 构建链路与较新的 Android 插件生态不完全兼容

同机上的 `localshare` 可以正常编译，因此最终采用“对齐 `localshare` 的 Android 构建栈”来修复。

## 症状

- `com.android.tools.build:gradle:8.2.1` 与其他 AndroidX 依赖下载时偶发 TLS 握手失败
- 默认 `java` 实际指向 `Temurin 25.0.2`
- 插件链要求更高的 `NDK` 版本
- 旧版 AGP / Gradle 组合比 `localshare` 更脆弱

## 最终可用配置

### 1. Gradle JDK 固定为 JBR 17

文件：

- [android/gradle.properties](/Users/zhanngpenng/Development/lunarix_notes/android/gradle.properties)
- [Makefile](/Users/zhanngpenng/Development/lunarix_notes/Makefile)

关键点：

- `org.gradle.java.home=/Users/zhanngpenng/Library/Java/JavaVirtualMachines/jbr-17.0.12/Contents/Home`
- `Makefile` 默认 `JAVA_HOME` 也指向同一路径

原因：

- `Java 25.0.2` 会让 Kotlin/Gradle 在插件解析阶段报 `IllegalArgumentException: 25.0.2`
- Android Gradle Plugin 8.x 的稳妥运行 JDK 是 17

### 2. Android Gradle Plugin 升级到 8.7.0

文件：

- [android/settings.gradle](/Users/zhanngpenng/Development/lunarix_notes/android/settings.gradle)

关键点：

- `com.android.application` 从 `8.2.1` 升级到 `8.7.0`

原因：

- 与 `localshare` 对齐
- Android 官方文档显示 AGP 8.7 推荐搭配 JDK 17 与 Gradle 8.9+

### 3. Gradle Wrapper 升级到 8.10.2

文件：

- [android/gradle/wrapper/gradle-wrapper.properties](/Users/zhanngpenng/Development/lunarix_notes/android/gradle/wrapper/gradle-wrapper.properties)

关键点：

- `gradle-8.3-all.zip` 升级为 `gradle-8.10.2-all.zip`

原因：

- 与 AGP 8.7.0 兼容
- 与 `localshare` 对齐

### 4. Jetifier 打开

文件：

- [android/gradle.properties](/Users/zhanngpenng/Development/lunarix_notes/android/gradle.properties)

关键点：

- `android.enableJetifier=true`

原因：

- 与 `localshare` 一致
- 老旧 Android 依赖链更稳

### 5. NDK 固定到 27.0.12077973

文件：

- [android/app/build.gradle](/Users/zhanngpenng/Development/lunarix_notes/android/app/build.gradle)

关键点：

- `ndkVersion = "27.0.12077973"`

原因：

- `file_picker`、`image_picker_android`、`shared_preferences_android`、`sqflite_android`、`url_launcher_android`、`video_player_android` 等插件都要求这个版本

## 结论

这次问题的根因不是业务代码，也不是 Flutter SDK 本身坏掉，而是：

- 项目 Android 构建栈落后于同机其他 Flutter 项目
- 默认 Java 漂到了 `25.0.2`
- 插件生态已要求更高版本的 AGP / Gradle / NDK

## 后续建议

1. 后续 Android 构建默认使用 `make release-apk` 或 `make install-release`
2. 保留 `JBR 17` 作为项目级 Gradle JDK，不要回落到系统默认 `Java 25`
3. 如果后面再升级 Flutter，优先同步检查：
   - `android/settings.gradle`
   - `android/gradle/wrapper/gradle-wrapper.properties`
   - `android/gradle.properties`
   - `android/app/build.gradle`
4. 若要继续参考同机项目，优先对照 `localshare` 的 Android 配置，而不是只看 `Makefile`
