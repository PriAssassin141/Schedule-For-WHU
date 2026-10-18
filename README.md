# 表里珞珈 · Schedule-For-WHU

> 一款为**武汉大学研究生**设计的课表 App：本App由DeepSeek-v4.1-flash-expires-on-0910与DeepSeek Harness鼎力支持。
> 使用 Flutter / Dart 开发，数据全部保存在本地。

<p align="left">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%208.0%2B%20%7C%20Windows-4CAF50">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-yellow">
</p>

---

## ✨ 功能特性

### 课表

- **周一~周日同屏显示**：一天 13 节 × 一周 7 天全部在一屏内呈现，行高按屏幕高度自适应，无需上下滚动即可看到晚上的课
- **上下拖动翻页切换周次**：跟手拖动、松手自动翻页或回弹，被翻走的页面整页丝滑滑出；非本周时显示「回到本周」悬浮按钮
- 点击「第 N 周」可弹出周次网格，直接跳转任意一周
- 点击课程卡片先查看居中的信息卡片（地点、老师、周次、时间、日期与备注），点击「编辑」再进入编辑页；长按可编辑 / 更换颜色 / 删除
- 课程重叠时自动分栏显示

### 节假日与调休（v1.0.4 新增）

- 主页菜单 → **节假日与调休**，开启「智能重排课表」后即时生效；也可点击课表日期直接编辑当天安排。
- 支持 **2025—2035 年**：已公布的年度安排按实际放假及调休日期执行，未来年份预置法定节日日期，具体调休可按学校通知手动设置。
- 手动设置 **停课 / 补指定日期的课 / 按原课表上课**，支持同时停课原日期，手动设置优先。
- 跨周补课按原日期周次筛选，课表卡片、重叠分栏与分享文本同步重排，编辑卡片仍修改原课程。
- 默认关闭；关闭后恢复原课表，课程、考试、开学日期不变；所有设置保存在本地，旧数据库无需迁移。
- 未公布的年度调休方案不作推测；春节、端午、中秋和清明日期依据公历农历对照表确定。
- 所有页面、信息卡片、编辑弹窗、删除确认、年份/节次选项和日期/时间选择器统一使用玻璃样式，随个性化设置切换高斯模糊或液态玻璃。

本副本严格基于 GitHub 标签 `SFW-V1.0.3`（`0ef75ceb70969e0236bc3bb6793ac23ecf77c93b`），版本标记为 `1.0.4+4`。
设计、日期来源和维护说明见 [节假日与调休说明](docs/HOLIDAY_REORDER.md)。

后续开发统一使用 `ClassManager-New` 目录；编译产物位于 `build/`，交付安装包、源码压缩包和补丁位于 `artifacts/`，此前交付文件位于 `artifacts/previous/`。不向父目录 `Vibe_Coding` 输出文件。

### 课程管理

- 手动添加课程：课程名称、任课老师、上课地点、备注、星期、节次范围、**周次任意多选**（如 1、3、6 周，另含全部 / 单双周 / 1-16 周快捷选择）、卡片颜色
- **批量导入课表**：支持 `doc` / `docx` / `xls` / `xlsx`，导入前可逐条预览修正，支持「追加导入」或「清空并导入」
- 导入后仍可随时重新编辑任意课程
- 新课程自动分配「当前使用最少」的颜色，尽量让不同课程颜色不同；也可自定义

### 考试管理（发现页）

- 考试倒计时：考试名称、地点、日期、起止时间、备注，点击卡片即可修改
- 已结束考试自动折叠，点击展开时有丝滑的展开动画
- 本学年校历一键跳转武大官方校历页面

### 个性化（全部即时生效）

| 设置项 | 说明 |
| --- | --- |
| 主题颜色 | 7 种主题色，**只改变按钮 / 卡片 / 滑杆等控件颜色，不影响背景壁纸** |
| 背景模糊 | 壁纸高斯模糊强度 |
| 卡片透明 | 卡片底色透明度 |
| 卡片背景模糊 | 卡片背后的模糊强度 |
| 液态玻璃 | 开 = Lens 透镜材质（斯涅尔折射、菲涅耳反射、细窄定向亮边与柔和环境反光）；关 = 普通高斯模糊卡片 |
| 玻璃材质 | 厚润 / 清透 / 柔雾三种 Lens 预设，支持继续手动调整；旧参数保持不变 |
| 果冻效果 | 可点击面板按压轻微抬升与定向形变，弹簧回弹与光学压力同步，支持减少动态效果 |
| 饱和度 | 整体色彩饱和度 |
| 折射 | 玻璃边缘的局部背景弯曲，中心和前景文字保持清晰；需要 Impeller，否则保留高斯模糊及光学边缘 |
| 色散 | 玻璃边缘 RGB 分采样与轻微彩色亮边 |
| 背景图片 | 从相册导入壁纸；未设置时使用内置默认壁纸（武大老图书馆） |

液态玻璃现采用 [design-systems 的 Lens 方案](https://github.com/ruiqichenbiec/design-systems/tree/main/lens)，使用 Flutter 原生 GLSL 与共享透镜组件实现；技术细节、来源版本与平台回退见 [液态玻璃说明](docs/LIQUID_GLASS.md)。

开启液态玻璃后，底部 Dock 使用清透的背景折射选中层，随栏目切换滑动；开启果冻效果时，到位后先压缩再回弹，快速切换时动画连续接续。系统启用减少动态效果时直接更新；关闭液态玻璃后恢复普通 Dock 样式。设置开关保留上一版的普通样式，不添加玻璃滑钮、勾选或流光特效。

### 其它

- **自定义开学日期**（中文日期选择器），自动换算周次与每周日期
- 「我的」页：个性化设置、联系作者（QQ / 微信 / 邮箱，点击复制）、关于软件、检查更新（夸克网盘）、获取源码
- 内置 13 节时间轴与时间显示，与武汉大学教务系统节次方案一致

---

## ⏰ 武大课程时间（13 节）

| 节次 | 时间 | 节次 | 时间 |
| --- | --- | --- | --- |
| 第一节 | 08:00~08:45 | 第八节 | 15:45~16:30 |
| 第二节 | 08:50~09:35 | 第九节 | 16:40~17:25 |
| 第三节 | 09:50~10:35 | 第十节 | 17:30~18:15 |
| 第四节 | 10:40~11:25 | 第十一节 | 18:30~19:15 |
| 第五节 | 11:30~12:15 | 第十二节 | 19:20~20:05 |
| 第六节 | 14:05~14:50 | 第十三节 | 20:10~20:55 |
| 第七节 | 14:55~15:40 | | |

---

## 🧱 技术栈

| 用途 | 方案 |
| --- | --- |
| 语言 / 框架 | Flutter 3.44+ / Dart 3.12+（Material 3，深色玻璃质感） |
| 界面效果 | 自定义 `BackdropFilter` + 渐变 + `CustomPainter` 实现液态玻璃（模糊、亮边、高光、色散、折射、饱和度） |
| 本地存储 | `sqflite`（Android 使用系统 SQLite；Windows / Linux 桌面使用 `sqflite_common_ffi`），全部数据仅保存在本机 |
| 文件解析 | `html`（MHTML / HTML 课表）、`xml` + `archive`（docx / xlsx）、`fast_gbk`（GBK 兜底） |
| 其它 | `provider`（状态管理）、`file_picker`（选文件 / 选壁纸）、`url_launcher`（外链）、`flutter_localizations`（中文本地化） |

---

## 📁 项目结构

```
lib/
├── main.dart                     # 入口：桌面 FFI 初始化、中文本地化、主题
├── db/
│   └── app_database.dart         # SQLite：课程 / 考试 / 设置三张表
├── models/
│   ├── course.dart               # 课程模型
│   ├── exam.dart                 # 考试模型
│   ├── schedule_adjustment.dart  # 按日期的停课 / 补课 / 原课表规则
│   ├── app_settings.dart         # 个性化设置模型
│   └── periods.dart              # 武大 13 节时间表
├── services/
│   ├── holiday_calendar.dart     # 国家假日与调休的离线日历
│   ├── schedule_resolver.dart    # 解析实际授课日期与原课程
│   ├── schedule_parser.dart      # 表格 → 课程的通用解析
│   └── schedule_importer.dart    # doc/docx/xls/xlsx/MHTML 导入器
├── screens/
│   ├── root_shell.dart           # 底部导航 + 全局背景
│   ├── home_screen.dart          # 主页：7 天全周课表 + 上下翻页
│   ├── discover_screen.dart      # 发现：校历入口 + 考试倒计时
│   ├── mine_screen.dart          # 我的：个性化 / 联系作者 / 关于 / 更新 / 源码
│   ├── personalization_screen.dart
│   ├── course_edit_screen.dart
│   ├── exam_edit_screen.dart
│   ├── import_preview_screen.dart
│   └── schedule_adjustment_screen.dart
├── widgets/
│   ├── glass.dart                # 液态玻璃组件（卡片 / 行 / 按钮）
│   ├── course_info_dialog.dart  # 点击课程先显示信息卡片，再通过按钮编辑
│   ├── glass_dialog.dart        # 统一玻璃弹窗、按钮、选项及日期/时间选择器
│   └── app_background.dart       # 壁纸 / 渐变背景 + 页面骨架
├── utils/
│   ├── weeks.dart                # 周次解析、压缩、开学日期换算
│   └── links.dart                # 外链打开 + 失败兜底
└── theme/
    └── palette.dart              # 主题色与课程配色盘
```

---

## 🚀 快速开始

### 环境要求

- Flutter 3.44 或更高（`flutter doctor` 通过）
- Android 端：Android SDK（编译 APK）
- Windows 桌面预览：Visual Studio 2022 生成工具（含 C++ 桌面开发）

### 运行

```bash
flutter pub get

flutter run                 # 连接安卓手机 / 模拟器
flutter run -d windows      # 本机桌面预览（无需手机）
flutter test                # 运行全部测试
```

> 首次构建（或清理 `build/` 后）会由 sqlite3 的 native assets 钩子下载预编译库；
> 若本机无法直连 GitHub，可先设置代理再构建：
> ```powershell
> $env:HTTPS_PROXY = 'http://127.0.0.1:7897'   # 按实际代理地址调整
> $env:HTTP_PROXY  = 'http://127.0.0.1:7897'
> flutter run -d windows
> ```
> 下载一次后会被缓存复用。

### 构建 APK

```bash
flutter build apk --release
```

在 Windows 下可运行以下命令，将安装包、源码压缩包和变更补丁统一写入本工程的 `artifacts/`：

```powershell
.\tools\package.ps1
```

产物：`build/app/outputs/flutter-apk/app-release.apk`（可直接安装到 Android 8.0+ 手机）。

---

## 📥 课表导入说明

### 支持格式

| 格式 | 解析方式 |
| --- | --- |
| 教务系统导出的 `.doc`（实为 **MHTML**） | 按 HTML 表格 + `jc`/`xq`/`rowspan` 原生属性精确解析（**最推荐**，节次、星期、周次完全准确） |
| `.docx` | 解析 `word/document.xml` 的表格（含 `vMerge` 纵向合并、`gridSpan` 横向合并） |
| `.xls` / `.xlsx` | 解析 `sharedStrings` + `mergeCells` |
| 真正的二进制 `.doc` | UTF-16 启发式提取文本（较粗糙，请在预览页核对） |

### 导入步骤

1. 在电脑端「研究生综合服务平台」导出课表，得到 `学生课表.doc`
2. 把文件传到手机，打开 App → 主页右上角菜单 → **导入课表**
3. 选择文件后进入**预览页**，逐条核对 / 修改
4. 选择「清空并导入」或「追加导入」

> 仓库 `test/fixtures/` 下的 `学生课表.doc` / `.docx` 为脱敏后的解析测试样例。

---

## 💾 数据存储

- 所有课程、考试、个性化设置都保存在本地 SQLite（`class_manager.db`），不收集或上传这些数据；仅点击「检查更新」时联网读取夸克分享中的版本日志
- 首次安装为**空白课表**，请自行添加或导入课程
- 壁纸会被复制到应用私有目录保存

---

## 🧪 测试

```bash
flutter test
```

覆盖内容：周次解析与开学日期换算、真实 `学生课表.doc` / `.docx` 解析（7 门课程、教师、地点、周次）、全周课表一屏布局、上下翻页切换周次、个性化大卡片布局、液态玻璃开关、中文本地化、「我的」页分组卡片等，共 30 个用例。

---

## ⚠️ 已知限制

- 周次上限 22 周（按一学期 22 周计）
- 课程颜色调色盘共 10 色，课程数超过 10 门后会复用颜色
- 真正的二进制 `.doc` 只能启发式提取，建议另存为 `.docx` 或直接使用教务系统导出的文件
- 「检查更新」弹出玻璃悬浮窗后，匿名扫描夸克分享中的 JSON 日志，按版本号和发布时间提醒是否更新，并显示更新时间与更新内容；仅点击「跳转到下载链接」才打开网盘，由用户手动下载。发布日志格式和同版本修订规则见 [检查更新说明](docs/UPDATE_CHECK.md)

---

## 🙏 致谢

本软件在设计时借鉴了我本科期间使用的课表软件 **「矿小助」**。
「矿小助」由中国矿业大学翔工作室开发，集成了校园网自动登录、成绩查询、班车时间、电费查询等生活常用功能，
是一款非常优秀的课表软件。本项目的界面风格与交互多有参考，在此致谢。

---

## 📄 开源协议

[MIT License](LICENSE) © 2026 PriAssassin141

---

## 📮 联系作者

- QQ：`1224850644`
- 微信：`Assassin141_CUMT`
- 邮箱：`1224850644@qq.com`
- GitHub：<https://github.com/PriAssassin141/Schedule-For-WHU>
- 下载最新版：<https://pan.quark.cn/s/b57d9dfe897a>
