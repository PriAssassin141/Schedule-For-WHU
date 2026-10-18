# 检查更新

点击「我的 → 检查更新」会立即显示原有玻璃弹窗，随后匿名扫描固定的夸克分享链接：
https://pan.quark.cn/s/b57d9dfe897a

不需要登录、转存、提供 Cookie，也不会自动下载或安装 APK。点击底部「跳转到下载链接」后才交给外部应用打开分享页。关闭弹窗会终止本次网络会话。

## 更新日志格式

将 UTF-8 编码的 `更新日志.json` 放在分享目录中；示例见 [update-manifest.example.json](update-manifest.example.json)。

```json
{
  "update-time": 202610170013,
  "latest-version": "v1.0.4",
  "describe": "本次更新的说明"
}
```

- `latest-version`：三段数字版本号，可带 `v` 前缀、预发布后缀和构建后缀。
- `update-time`：北京时间的 12 位年月日时分 `yyyyMMddHHmm`，支持 JSON 整数或字符串。它是**安装包的发布时间**，不是网盘上传时间、安装时间或检查时间。
- `describe`：可选的更新说明，按普通文字显示，支持换行。

应用会递归读取分享目录（包括分享根目录外包的一层文件夹），找到 `.json` 文件并核验上述字段。存在多份有效日志时，先选版本最高者，再按更新时间选最新者；无关 JSON 不参与比较。无效日期或损坏的更新日志会显示检查失败，不会误报「无需更新」。

## 判断规则

1. 网盘版本高于本机版本：提示「发现新版本，建议更新」。数字按数值比较，例如 `1.0.10 > 1.0.9`。
2. 版本相同、网盘发布时间更晚：同样提示更新，用于同版本修订。
3. 版本相同且时间不更新，或者网盘版本较低：显示「当前版本无需更新」，不推荐降级。
4. 本机版本或发布标识无法读取：明确提示无法核对，不当作已是最新版。

当前安装包的默认发布标识为 `202610170013`，与用户提供的第一份日志对应。发布后续版本时，**新 APK 内的时间必须和网盘 JSON 的 `update-time` 一致**。可以修改 `lib/config/release_metadata.dart` 的默认值，也可以构建时指定：

```powershell
flutter build apk --release --dart-define=APP_RELEASE_UPDATE_TIME=202610180900
```

每次发布同时更新 `pubspec.yaml` 的版本/构建号（同版本修订也建议提高构建号），先准备对应 APK，再发布新 JSON，避免提醒更新但尚无安装包。仅更新网盘日志不会改变已安装 APK 的本机发布标识。

## 网络行为与验证

使用分享令牌、分页文件列表和网页的 `share/sharepage/rich_text/preview` 接口获取临时读取地址，再下载 JSON；不保存临时地址或匿名会话 Cookie，不发送姓名、课表和设备标识。Android 发布清单包含普通 `INTERNET` 权限，隐私政策同步说明主动检查更新的联网行为。

请求只接受夸克 HTTPS 域名；每份 JSON 最大 64KB，最多扫描 32 个目录、2000 个文件、16 份 JSON，单次检查总超时 35 秒。达到限制、断网、分享失效、验证拦截、格式错误均显示失败并允许重试，下载按钮始终保留。

```powershell
flutter test test/update_manifest_test.dart test/quark_update_service_test.dart test/update_check_dialog_test.dart test/mine_screen_test.dart
dart tools/check_quark_update.dart
```

第二个命令是显式运行的真实网络只读检查，使用与应用相同的读取代码；不属于自动测试。解析与交互测试使用模拟响应，不依赖夸克网络可用性。

分享接口没有稳定兼容性的保证。后续平台调整时可能需要维护读取代码；失败时应用保留原下载入口。
