# 液态玻璃实现

2026-10-16 起改用 [ruiqichenbiec/design-systems 的 Lens 方案](https://github.com/ruiqichenbiec/design-systems/tree/main/lens)，移植其共享材质、斯涅尔折射、菲涅耳反射、定向反光和弹簧反馈。参考版本为 `1.1.0-showcase.1`，仓库提交 `7a424c93b9be13cf835b91ea67495fec2ec0584e`。

主要来源是 `lens/lab/design-system/tokens.js`、`internal/renderer.js`、`internal/jelly-physics.js`、`internal/jelly.js`、`component-patterns.js`、`components.js`、`internal/optics.js` 与 `DESIGN.md`。使用 Flutter 原生组件和 GLSL 适配这些规则，不在应用内运行 WebGL/DOM/WebView，也不引入其展示页、整套 Web 控件、音效或持续背景动画。来源及授权见 [第三方声明](../THIRD_PARTY_NOTICES.md) 和 [原 MIT 许可证](../licenses/design-systems-LICENSE.txt)；许可证作为资源同时打入 APK。

## 共享表面

`LiquidGlass` 继续供课程卡片、导航、按钮、设置页和 `GlassDialog` 系列共用。

- 普通玻璃继续使用各控件的 tint；滚动页面设置最低表面可见度与轻薄边缘，避免透明度为 100 时设置组难以辨认，不修改保存的透明度值。
- 遵守 Lens 的中心透光、细窄定向反光和宽而弱的环境反射；移除上一实现环绕一圈的粗亮边与双描边。
- 色散通过边缘 RGB 分采样表达，不添加占据布局空间的彩色边框。
- 非滚动 Impeller 表面的雾度系数为 `cardBlur × 6`，近似 Lens 九点采样 `blur × 10` 的模糊方差。滚动页面使用稳定的原生透镜和 Gaussian，默认系数与 Skia 回退、高斯模式一致，为 `cardBlur × 20`；显式 `blurOverride` 保持原值。
- 果冻开关控制可点击面板的轻微抬升、定向形变与弹簧回弹；悬停只改变反光，不抖动或放大。系统启用减少动态效果时取消形变动画。
- 指针监听不参加手势竞争，滑杆、输入和滚动仍由各自控件处理。

## 材质与兼容

`lib/theme/lens_material.dart` 是三个 Lens 预设的统一来源：

| 材质 | 折射 | 雾度 | 色散 |
| --- | --- | --- | --- |
| 厚润 Thick | 0.90 | 0.24 | 0.65 |
| 清透 Clear | 0.65 | 0.12 | 0.35 |
| 柔雾 Soft | 0.38 | 0.64 | 0.12 |

新安装默认厚润；原数据库中已保存的参数（包括 0）保持不变，缺失字段才使用新默认值。在「个性化 → 玻璃材质」可应用预设；继续调整单项参数后自动显示「自定义」。预设只修改三个光学值，不改动高斯/液态开关、透明度、主题色、课程与调休设置，不新增数据库字段或依赖。

## Dock 与设置开关

`LensDock` 参照 Lens segmented dock，使用一个覆盖整项的圆角透镜选中层。在「主页 / 发现 / 我的」间切换时，选中层在图标与文字下方滑动，快速换向从当前位移与速度继续。选中层取消高透明白色填充，改为较浅的主题色透光，并降低两层重复模糊的强度；叠加透明斜向反光和 0.8px 渐隐细边缘，使深色壁纸上的玻璃更容易辨认，保持中心通透。此提亮仅作用于选中层，不改变背景折射、模糊或动画参数。文字和图标独立绘制，保持清晰且不随透镜形变。布局变化和从右向左排列时仍对齐所选栏目，支持方向键、Home/End 和选中项的 Tab 焦点。

设置开关按用户要求恢复上一版：`GlassSwitchRow` 使用原有 `SwitchTheme` 与 Material Switch，调休页恢复 `SwitchListTile`，不再添加玻璃滑钮、勾选或单独流光。开关功能、已保存的值与高斯/液态模式设置均不改变。

Dock 位移使用 `LensRailController` 的有限弹簧（质量 1、刚度 360、阻尼 22）。开启果冻效果时，滑动中轻微拉伸，接近目标后启动独立的到位弹簧（质量 1、刚度 420、阻尼 13），先横向压缩、纵向鼓起，再反向回弹并精确归零；选中后的回弹不依赖滑动速度维持。关闭果冻效果后保留滑动但不形变。选中时参照上游 `opticalSelection` 触发一次 1100ms 窄边流光。初次显示和静止时不循环发光。系统启用减少动态效果时直接更新位置并停止形变与流光；关闭液态玻璃后恢复普通 Dock 选中样式。

## 背景折射

`GlassBackdrop` 只过滤已经渲染的背景，不过滤文字、图标及表单内容。`shaders/liquid_glass.frag` 根据实际面板尺寸和四个圆角计算圆角矩形的距离场，再将位移集中在边缘：

1. 法线来自圆角距离场的有限差分；倒角宽度、坡度指数 `1.65` 和轻微面法线均来自 Lens。
2. 使用 `refract(..., 1.0 / 1.45)` 计算从空气进入玻璃的光线，折射量随材质厚度及按压压力变化；对窄课程列和小按钮限制厚度，避免过度跨越背景。面中心只有轻微透镜变化，文字本身不参与过滤。
3. 边缘色散沿法线分离红/蓝采样，叠加菲涅耳环境反射、细定向高光、背光侧焦散和跟随指针的微光。色散参数为零时关闭通道分离。
4. 采样坐标钳制在有效纹理范围，保留预乘 alpha，并处理 OpenGLES 纹理的 Y 翻转。

「折射」滑杆控制面板内的背景弯曲；默认壁纸、自选壁纸、渐变和面板后面的场景使用同一实现。折射和色散为零时停止位移及通道分离，仍保留材质反光，不擅自覆盖已保存参数。

`LensMotion` 使用质量 1、刚度 310、阻尼 18 的有限时长弹簧，与上游按压模型一致；0.70 弹性和 0.035 抬升系数同样来自 Lens。重按从当前值与速度接续，松手/取消后精确回到静止，销毁时释放控制器。形变后的整个玻璃与内容保持一致，shader 使用同一个压力。课表的固定位置不变，不将上游自由拖拽或独立轮廓弯曲强行加入课程交互。

## 平台回退与资源

### 滚动页面与 Android 真机兼容

用户在 vivo X300 Pro / Android 17 反馈滚动边界暂时变黑、绿色线条和设置背景过于透明。Flutter 当前的运行时滤镜会随视口裁剪改变输入纹理的范围，不能把纹理归一化坐标直接当作完整面板坐标；上游已确认类似裁剪问题，见 [flutter/flutter #185175](https://github.com/flutter/flutter/issues/185175)。这与本工程的滚动玻璃路径相符，但本机没有该手机，不能把本地通过等同于该机验收。

- `GlassBackdrop` 通过 `Scrollable.maybeOf` 在依赖变化时识别滚动面板。在滚动前、滚动中与静止时固定使用 `LensBackdropRefraction` 与 `LensReflection`，不加载或组合该面板的 `ImageFilter.shader`，避免随着可见范围变化而重映射曲面或独立 RGB 通道。非滚动表面（包括 Dock）保留原有 GLSL 路径，Dock 位移和到位弹簧参数不改动。
- 应用保留原生滚动物理，关闭边界拉伸与发光指示器，避免给实时背景滤镜再套一个拉伸离屏层；正常滚动、点击和输入不受影响。
- 滚动玻璃不再绘制会参与自身背景采样的填充黑色阴影。其表面渐变起始 alpha 下限为 `0.11 + (1 - cardTransparency) × 0.08`，并使用 0.75px、12% alpha 的细边缘；原 tint 高于此下限时保留。透明度滑杆和数据库数值均不被重置，高斯模式保持独立。
- 原生透镜仍真实采样当前位置的背景，保留折射滑杆、按压形变和定向反光。滚动路径不做独立 RGB 分采样，仅用轻微冷色反光表达色散感；它不等同于 GLSL 的逐像素斯涅尔折射与色散。

[Flutter 的 `ImageFilter.shader`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html) 仅支持 Impeller。先检查 `ImageFilter.isShaderFilterSupported`；Windows/Skia 等不支持的平台使用高斯毛玻璃、细定向反光和柔和内侧焦散的 Canvas 回退，不调用不支持的 API，也不承诺真实背景折射。关闭液态玻璃后完全回到普通高斯样式。

Dock 在 Windows/Skia 上另外启用 `LensBackdropRefraction`：使用 Flutter 原生 `RawMagnifier`，分离细倒角和清晰核心的实时背景放大，配合共享定向反光近似透镜曲面。原生控件在绘制时计算采样中心，滑动、尺寸变化和果冻缩放后仍采样当前位置的背景，不复用过时壁纸或截图。不支持 GLSL 的平台也能看到背景位移，但此近似不包含逐像素斯涅尔折射与 RGB 色散；Impeller 继续使用原 GLSL 实现。两条路径都尊重已保存的零折射参数。

着色器程序首次需要时异步加载并共享，每个面板持有独立的 uniforms 实例，销毁时释放。加载失败时保留回退。没有持续的逐帧计时动画、屏幕截图或背景图片重复解码；Impeller 的模糊和着色器滤镜合成为一个 `BackdropFilter`，过滤区域由面板的 `ClipRRect` 限定。Skia 的 Dock 倒角和核心使用互不重叠的裁剪区域，避免重复放大背景。

## 验证

`test/glass_optics_test.dart` 在实际着色器输出上检查横/纵卡片的中心清晰度、边缘折射、折射率 1.45 的独立 CPU 计算、RGB 色散、零参数校准、定向光照与透明输入 alpha，同时验证模式切换后尺寸不变、Skia 回退可点击、鼠标进出、滑杆拖动、减少动态效果、途中重按、取消与销毁。`test/lens_material_test.dart` 验证新默认值、旧参数保留、预设持久化及菜单交互。`test/lens_controls_test.dart` 验证 Dock 中间帧、快速换向、尺寸变化、RTL、键盘、到位压缩/反向回弹/归零、关闭果冻与高斯回退。`test/lens_backdrop_refraction_test.dart` 直接渲染 Skia 背景，验证采样位移、中心校准、移动后的中心和外部区域保持稳定。原有液态开关、课程信息卡和全部调休回归用例继续保留。

发布前运行 `flutter test --no-pub`、`flutter analyze --no-pub`、`flutter build apk --release --no-pub` 和 `tools/package.ps1`。`flutter test --no-pub tools/glass_preview_test.dart` 导出 Windows/Skia 回退的三栏 Dock、滑动中间帧、开关开/关、课程卡和调休弹窗预览到 `artifacts/glass-preview/`，上一实现的预览保留在 `artifacts/previous/glass-preview-before-lens-20261016/`。

`test/glass_scroll_regression_test.dart` 在 Skia 与 `--enable-impeller` 下检查 Android 滚动边界、大面板部分出屏、按住和拖动、像素偏绿/变黑、透明度 100 的可见度以及零参数/高斯切换。像素与预览测试启用真实阴影，避免测试框架默认关闭模糊阴影造成与发布版不同的结果。`tools/glass_preview_test.dart` 将 Impeller 预览另外保存到 `artifacts/glass-preview/impeller/`，包含透明度 100、滚动与回到顶部状态。

本机 Impeller 验证不能等同于 vivo X300 Pro / Android 17 的真机渲染、性能及触摸验收，仍需在该手机上复测。

2026-10-16：完整 Skia 测试 101 项通过；Impeller 下新增的 2 项滚动/像素测试及 5 项 Dock 交互测试通过，两个后端的页面预览均已导出并检查。
