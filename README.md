# QRLinkRouter

二维码聚合跳转 App：扫到二维码 → 判断归属平台 → 唤起对应 App（或浏览器兜底）。
全部使用苹果公开标准 API，不含任何私有 API，目标是用 SideStore / AltStore 自签安装。

---

## 0. 先读这一条

**IPA 只能在 macOS + Xcode 上产出。** Windows / Linux 无法 `flutter build ios`。
> ### 没有 Mac？直接看第 13 节
> 用 **GitHub 的免费 macOS 机器**就能出 IPA，只需要一个 GitHub 账号，
> **不需要 Apple 账号、不需要证书、不需要描述文件**。
> 本仓库已内置 `.github/workflows/build-ipa.yml`，上传代码后点一下按钮即可。

本文档假设你在一台装了 Xcode 的 Mac 上操作，iPhone 系统 iOS 15.0 及以上。

**当前构建状态（已实测）**：Flutter 3.47.4 / Dart 3.13.3 下
`flutter analyze` → **No issues found**；`flutter test` → **11/11 通过**。
iOS 工程骨架（`Runner.xcodeproj`、`AppDelegate.swift`、`SceneDelegate.swift`、
`Info.plist` 权限项）已全部就位并提交。

仓库里给的是**完整可用的工程源码**（`lib/`、`pubspec.yaml`、`ios/Podfile`、`exportOptions.plist`、`test/`），
iOS 的其余骨架文件（`Runner.xcodeproj`、`LaunchScreen.storyboard` 等）由 `flutter create` 生成后合并。

---

## 1. 环境要求

| 组件 | 版本 |
| --- | --- |
| macOS | 13 Ventura 或更高 |
| Xcode | 15.0 或更高（含 Command Line Tools） |
| Flutter | 3.19 或更高（stable） |
| CocoaPods | 1.13 或更高 |
| iPhone | iOS 15.0 及以上 |
| Apple ID | 免费账号即可（SideStore / AltStore 自签） |

```bash
xcode-select --install
sudo gem install cocoapods
flutter doctor -v          # iOS toolchain 必须全绿
```

---

## 2. 工程骨架（已包含，无需生成）

> **本仓库已经带完整 iOS 工程**：`ios/Runner.xcodeproj`、`Runner.xcworkspace`、
> `AppDelegate.swift`、`SceneDelegate.swift`、`Assets.xcassets`、`LaunchScreen.storyboard`，
> 以及**已经注入好相机权限和 URL Scheme 白名单**的 `Info.plist`。
> 你**不需要**再跑 `flutter create`，拉下来 `flutter pub get` 即可编译。

只有在你想换包名、从零重建骨架时，才需要：

```bash
flutter create --org com.example --project-name qr_link_router --platforms=ios QRLinkRouter
```

以下文件对照表仅作说明用途：

| 本仓库路径 | 目标路径 | 说明 |
| --- | --- | --- |
| `lib/**` | `lib/**` | 覆盖，全部业务代码 |
| `test/regex_router_test.dart` | `test/` | 新增 |
| `pubspec.yaml` | `pubspec.yaml` | 覆盖 |
| `analysis_options.yaml` | `analysis_options.yaml` | 覆盖 |
| `ios/Podfile` | `ios/Podfile` | 覆盖（关键：`platform :ios, '15.0'`） |
| `ios/Runner/Info.plist.reference` | 合并进 `ios/Runner/Info.plist` | **不要整份覆盖**，见第 3 节 |
| `exportOptions.plist` | 项目根目录 | 方案 B 才用 |

```bash
flutter pub get
cd ios && pod install && cd ..
flutter analyze
flutter test
```

---

## 3. iOS 配置（只加 key，不要覆盖整个 Info.plist）

`flutter create` 生成的 `ios/Runner/Info.plist` 里有 `UIApplicationSceneManifest`、
`UILaunchStoryboardName` 等**必须原样保留**，整份覆盖会白屏。只需合并这几项：

1. **`NSCameraUsageDescription`（必须）**
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>需要相机权限来扫描二维码</string>
   ```
   文案与 App 内弹窗提示保持一致。

2. **`LSApplicationQueriesSchemes`（必须，最容易被漏掉）**
   ```xml
   <key>LSApplicationQueriesSchemes</key>
   <array>
     <string>douyin</string><string>weixin</string>
     <string>alipays</string><string>alipay</string>
     <string>taobao</string><string>bilibili</string>
     <string>xhs</string><string>pinduoduo</string>
     <string>https</string><string>http</string>
   </array>
   ```
   没有这一段，`canLaunchUrl` 会**永远返回 false**，表现是每次都提示「未检测到该 App」。
   这段是苹果公开的标准配置，不是私有 API。

3. **ATS（保持默认即可）**
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict><key>NSAllowsArbitraryLoads</key><false/></dict>
   ```
   你的 `codex-proxy` 必须是 **https**。如果只有 http，加域名例外（不要开 ArbitraryLoads）：
   ```xml
   <key>NSExceptionDomains</key>
   <dict>
     <key>你的域名.com</key>
     <dict>
       <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
     </dict>
   </dict>
   ```

4. **状态栏与方向**：`UIStatusBarStyle = UIStatusBarStyleLightContent`、
   `UIViewControllerBasedStatusBarAppearance = false`、`UISupportedInterfaceOrientations` 只留竖屏。

5. **Xcode 里检查**（用 `open ios/Runner.xcworkspace`）：
   - `Minimum Deployments` / `IPHONEOS_DEPLOYMENT_TARGET` = **15.0**（Runner 和 Pods 都要）
   - `PRODUCT_BUNDLE_IDENTIFIER` = **com.example.QRLinkRouter**
     （与 `exportOptions.plist` 里的 key 完全一致，大小写敏感）
   - `Signing & Capabilities`：不要添加 Push、App Groups、Sign in with Apple、NFC 等
     免费账号不支持的 capability，否则签名会失败或装完闪退。
   - 目标 `Runner` → Build Settings → `Enable Bitcode` = **No**。

---

## 4. 打包 IPA

> **签名已经由 SideStore / AltStore 处理好的话，只看下面方案 A。**
> 方案 B 和 `exportOptions.plist` 是给「需要自己产出签名 IPA」的场景准备的，可以直接忽略。
> 你的目标产物就是一个**未签名 IPA**，下面方案 A 就是。

### 方案 A：不签名打包（SideStore / AltStore 自签用，**推荐**）

这条路线不需要任何证书和开发者账号，产出的是未签名 IPA，交给 SideStore 签名。

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..

flutter build ios --release --no-codesign

mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/
zip -qry QRLinkRouter.ipa Payload
rm -rf Payload
```

得到 `QRLinkRouter.ipa`，直接丢给 SideStore 安装。

也可以用 `scripts/build_ipa_macos.sh` 一键完成（见第 7 节）。

### 方案 B：`flutter build ipa`（需要证书 / 描述文件）

```bash
flutter build ipa --export-options-plist=exportOptions.plist
```

产物在 `build/ios/ipa/*.ipa`。

`exportOptions.plist` 是**模板**，直接跑会失败，必须补两处：

- `teamID` → 你的 10 位 Team ID（免费账号也有，Xcode → Settings → Accounts 里看）
- `provisioningProfiles` → `com.example.QRLinkRouter` 对应的描述文件名称，
  且必须是**已经存在**的 profile；空字符串一定失败。

免费 Apple ID 无法在命令行创建 distribution profile。
要跑通方案 B，先在 Xcode 里用自动签名跑一次真机调试（Xcode 会生成 development profile），
再把那份 profile 的名字填进 plist，并把 `signingStyle` 改成 `automatic` 更省事。

**只想自签安装的话，用方案 A，别折腾方案 B。**

---

## 5. 用 SideStore / AltStore 安装

### SideStore

1. iPhone：设置 → 隐私与安全性 → **开发者模式** → 打开（会重启）。
2. 按 SideStore 官方指引完成配对（电脑端 SideServer 或 StosVPN，二选一）。
3. 把 `QRLinkRouter.ipa` 传到 iPhone（AirDrop / 文件 App）。
4. SideStore → 左上角 `+` → 选择该 IPA → 输入 Apple ID → 签名并安装。
5. 首次打开如果提示「不受信任的开发者」：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID。

### AltStore

1. 电脑装 AltServer，数据线连 iPhone，AltServer 菜单里安装 AltStore 到手机。
2. 手机：设置 → 通用 → VPN与设备管理 → 信任 AltStore。
3. 手机 AltStore → My Apps → `+` → 选 IPA → 输入 Apple ID。

### 免费账号的硬限制（必须知道）

- 签名 **7 天**过期，需续签（SideStore 可后台自动续，AltStore 需连电脑或同 Wi-Fi 的 AltServer）。
- 同时最多 **3 个**自签 App。
- 免费账号只能签 **development** 类型，不能上架、不能用推送等能力。
- 因此本工程刻意**不引入**任何需要付费能力的东西。

---

## 6. 防闪退 / 防签名失效的约束（本工程已遵守）

- 只用公开 API：`AVFoundation`（mobile_scanner）、`UIApplication.openURL`（url_launcher）、
  `NSURLSession`（dio 走 dart:io）、`UserDefaults`（shared_preferences）、本地文件（Hive）。
- 不申请任何免费账号不支持的 entitlement。
- 不加 `UIApplication.shared` 私有扩展、不 hook 系统方法、不读取其他 App 沙盒。
- 不依赖越狱环境。
- Podfile 强制 `IPHONEOS_DEPLOYMENT_TARGET = 15.0`，避免 pod 版本冲突导致 Release 构建异常。
- 关闭 Bitcode。

**副作用要提前接受**：iOS 沙盒限制下，第三方 App **无法**替目标 App 完成扫码动作。
本 App 只能唤起对应 App，唤起后需要你手动点目标 App 里的扫码按钮。这也是返回值里
`needManualScan` 恒为 `true` 的原因。

---

## 7. 一键打包脚本（macOS）

```bash
chmod +x scripts/build_ipa_macos.sh
./scripts/build_ipa_macos.sh
```

脚本会依次执行 `flutter clean` / `pub get` / `pod install` / `build ios --no-codesign`，
并打包成 `QRLinkRouter.ipa`。

---

## 8. 功能与异常自测清单

| # | 场景 | 预期 |
| --- | --- | --- |
| 1 | 首次启动 | 弹相机权限，文案「需要相机权限来扫描二维码」 |
| 2 | 拒绝相机权限 | 弹框提示 + 自动进入设置页，扫码页不可用 |
| 3 | 扫 `https://v.douyin.com/xxx` | 命中本地正则，不产生任何网络请求，弹「识别成功 / 抖音」 |
| 4 | 扫一段正则不认识的文本 | 调用 AI（开关开启且已配置），成功则缓存并弹窗 |
| 5 | 再扫一次第 4 步同一个码 | 走缓存，**零网络请求、零 token** |
| 6 | 拔网线 / 填错 API Key | 弹「AI识别失败，将使用浏览器打开原始链接」，之后浏览器兜底 |
| 7 | 关闭「启用AI识别」 | 只走正则；正则不认识的码直接进浏览器兜底，不发请求 |
| 8 | 目标 App 未安装 | 点「打开对应App」→ 提示「未检测到该App，即将在浏览器打开链接」→ Safari 打开 |
| 9 | 扫到空码 / 损坏码 | 无任何弹窗，继续扫描 |
| 10 | 扫码时按 Home 再回来 | 相机自动暂停并恢复，不卡死 |
| 11 | 设置页清除缓存 | 二次确认后清空，计数归零 |
| 12 | 改动设置项后杀进程重启 | 设置项保持 |

---

## 9. 目录结构

```
QRLinkRouter/
├── lib/
│   ├── main.dart                      # 入口：读设置 + 初始化 Hive
│   ├── app.dart                       # MaterialApp + 全局设置状态
│   ├── core/
│   │   ├── app_constants.dart         # 固定 Prompt、超时、默认值、版本号
│   │   └── logger.dart
│   ├── data/
│   │   ├── models/app_settings.dart
│   │   ├── models/qr_route_result.dart
│   │   ├── settings_store.dart        # shared_preferences
│   │   └── qr_cache_store.dart        # Hive 缓存
│   ├── services/
│   │   ├── regex_router.dart          # 内置正则库（零 token）
│   │   ├── llm_router.dart            # dio 调 codex-proxy
│   │   └── link_opener.dart           # url_launcher 唤起 / 兜底
│   └── ui/
│       ├── scan_page.dart             # 扫码主页
│       ├── settings_page.dart         # 设置页
│       └── widgets/
│           ├── scan_frame_overlay.dart
│           └── result_dialog.dart
├── ios/
│   ├── Podfile                        # platform :ios, '15.0'
│   └── Runner/Info.plist.reference          # 需合并的 key
├── test/regex_router_test.dart
├── scripts/build_ipa_macos.sh
├── .github/workflows/build-ipa.yml    # GitHub 云端打包（没有 Mac 用这个）
├── codemagic.yaml                     # Codemagic 云端打包（备选）
├── exportOptions.plist
└── pubspec.yaml
```

---

## 10. 识别优先级与缓存策略

```
扫到二维码
  ↓
① 空/无效 → 静默忽略，继续扫
  ↓
② 查 Hive 缓存（完全相同的文本）→ 命中直接弹窗，零 token
  ↓
③ 本地正则库（抖音/微信/支付宝/淘宝/B站/小红书/拼多多）→ 命中即缓存并弹窗，零 token
  ↓
④ AI 开关开启且已配置 → 调 codex-proxy
      成功 → 校验 scheme 合法性 → 缓存并弹窗
      失败 → 弹窗提示 AI 识别失败 → 浏览器兜底
  ↓
⑤ AI 关闭/未配置 → 直接浏览器兜底
```

> 说明：需求原文把「缓存」写在 LLM 之后，但同时要求「下次扫描完全一样的二维码文本直接读缓存、
> 不再走正则、不再调 API」。为满足「零 token」这一条，实现上把缓存查询提到了最前面，
> 逻辑等价且更省 token。

AI 返回的 `scheme` 会做一次格式校验（必须符合 `scheme://`），防止模型编造出无法唤起的字符串。

---

## 11. 常见问题

**Q: 装完打开白屏？**
A: 大概率是把 `Info.plist` 整份覆盖了，`UIApplicationSceneManifest` 丢了。恢复 `flutter create` 的版本后只合并需要的 key。

**Q: 每次都提示「未检测到该App」？**
A: `LSApplicationQueriesSchemes` 没加，或目标 App 确实没装。先确认清单里有对应 scheme。

**Q: AI 一直失败？**
A: 按顺序查：① 设置页开关是否打开；② 地址是否以 `https://` 开头且带 `/v1`；③ 用 `curl` 验证
`{baseURL}/chat/completions` 能返回；④ 如果代理只有 http，会直接被 ATS 拦截。

**Q: `pod install` 报部署版本冲突？**
A: 确认 `ios/Podfile` 第一行是 `platform :ios, '15.0'`，然后 `pod repo update && pod install --repo-update`。

**Q: `flutter build ipa` 报 no provisioning profile？**
A: 见第 4 节方案 B，或者直接用方案 A（自签不需要描述文件）。

**Q: `errorBuilder` 的签名到底是什么？**
A: `mobile_scanner` **5.2.3 就已经是三参数**：

```dart
typedef MobileScannerErrorBuilder =
    Widget Function(BuildContext, MobileScannerException, Widget?);
```

本工程的 `_buildCameraError(BuildContext, MobileScannerException, Widget?)` 就是按这个签名写的，
已经在 Flutter 3.47.4 上 `flutter analyze` 通过。升级到 6.x / 7.x 时如果签名有变化，改这一个方法即可。
**Q: 7 天后打不开了？**
A: 免费签名到期，用 SideStore 续签即可。代码和数据都不受影响。

---

## 12. 合规声明

本工程只使用苹果公开文档中的标准 API 与配置项（`NSCameraUsageDescription`、
`LSApplicationQueriesSchemes`、`NSAppTransportSecurity`、`UIApplication.openURL`、
`AVFoundation`），不包含任何私有 API、不 hook 系统、不越权访问其他 App 数据。
不提交 App Store，仅用于自签安装的个人用途。

---

## 13. 没有 Mac：云端免费出 IPA（推荐）

三种方案，按推荐度排序。你只需要方案 1。

> 本仓库的流水线会自己完成 iOS 工程骨架生成和 `Info.plist` 权限注入，
> 所以你**不需要安装 Flutter、不需要 Xcode、不需要 Mac**，只要一个 GitHub 账号。

### 方案 1：GitHub Actions（免费，推荐）

前提：一个 GitHub 账号（免费注册即可）。

**第 1 步：建仓库**

1. 打开 github.com，右上角 `+` → New repository
2. Repository name 填 `QRLinkRouter`
3. 可见性选 **Public**
   （公开仓库使用 macOS runner 免费；私有仓库会按 10 倍时长扣免费额度）
4. 不要勾选 Add a README / .gitignore / license，直接 Create repository

> 公开仓库安全吗？安全。这个工程里**不含任何密钥**。
> API Key 是你在 App 设置页里填的，只保存在手机本地，不进代码、不进仓库。

**第 2 步：上传代码**

1. 解压 `QRLinkRouter.zip`
2. 进入 `QRLinkRouter` 文件夹，**选中里面所有的文件和文件夹**
   （`lib`、`ios`、`test`、`scripts`、`pubspec.yaml`、`README.md` …）
3. 在仓库页面 → Add file → Upload files → 拖进去 → Commit changes

**更省事的办法：直接用 git 推（推荐）**

`QRLinkRouter` 目录已经是一个初始化好的 git 仓库（含一次提交），不用手动上传：

```bash
cd "C:\Users\RP\Documents\Codex\2026-09-12\new-chat\outputs\QRLinkRouter"
git remote add origin https://github.com/你的用户名/QRLinkRouter.git
git push -u origin main
```

第一次 push 会弹出浏览器让你登录 GitHub，登录一次即可。

`.github` 是隐藏文件夹，网页拖拽有时会漏。稳妥做法是单独建这个文件：

1. 仓库页面 → Add file → **Create new file**
2. 文件名填：`.github/workflows/build-ipa.yml`
3. 用记事本打开本地的 `QRLinkRouter/.github/workflows/build-ipa.yml`，
   全选复制，粘贴进网页编辑器
4. Commit changes

**第 3 步：跑构建**

1. 仓库页面顶部 → **Actions** 标签
2. 左侧选择 `Build unsigned IPA`
3. 右侧 **Run workflow** → 绿色按钮
4. 等 8–15 分钟（第一次会久一点，要下载 Flutter SDK）

**第 4 步：下载 IPA**

点进这次运行记录 → 页面最底部 **Artifacts** → 点 `QRLinkRouter-ipa` 下载
得到一个 zip，解压后里面就是 `QRLinkRouter.ipa`。

**第 5 步：装到 iPhone**

用 SideStore / AltStore 自签安装，见第 5 节。

**构建失败怎么办**：在 Actions 里点进红色的步骤看报错，把日志发我，我直接改代码重推。

### 方案 2：Codemagic（网页界面，免费 500 分钟/月）

1. 打开 codemagic.io，用 GitHub 账号登录（免费）
2. Add application → 选择你刚才建的仓库
3. 它会自动读取仓库根目录的 `codemagic.yaml`（本仓库已提供）
4. 选 workflow `QRLinkRouter unsigned IPA` → Start new build
5. 构建完成后在 Artifacts 里直接下载 `QRLinkRouter.ipa`
6. 因为是不签名构建，**不需要绑定 Apple 账号**

### 方案 3：租一台云端 Mac（想用 Xcode 手动调试时用）

- MacinCloud：按小时计费，约 $1/小时，提供远程桌面
- Scaleway Apple Silicon：按小时计费，性价比高
- 找朋友借一台 Mac，装上 Xcode 就行

拿到 Mac 后按第 2–4 节操作，`scripts/build_ipa_macos.sh` 一键出包。

### 费用与账号的真实结论

| 目标 | 需要 Apple 账号 | 需要 Mac | 费用 |
| --- | --- | --- | --- |
| 出未签名 IPA | 不需要 | 不需要（云端） | 0 元 |
| SideStore / AltStore 签名安装 | 需要，普通免费 Apple ID 即可 | 不需要 | 0 元 |
| 上架 App Store | 需要付费开发者账号 | 需要 | $99/年 |

你的场景只需要前两行，全程 0 元。