# 液态玻璃实现

本次参考 [rdev/liquid-glass-react](https://github.com/rdev/liquid-glass-react) 的实现思路：背景变形与内容分层、边缘位移、RGB 分采样、遮罩亮边及跟随指针的高光。使用 Flutter 原生组件和 GLSL 实现，不引入 React/WebView 运行时。来源及授权说明见 [第三方声明](../THIRD_PARTY_NOTICES.md)。

## 共享表面

`LiquidGlass` 继续供课程卡片、导航、按钮、设置页和 `GlassDialog` 系列共用。

- 玻璃底色保持透明度和各控件原来的 tint 配置。
- 双层圆角高光与渐变内圈表现玻璃厚度；高光随触摸/鼠标位置移动。
- 色散环在表面内部绘制，不通过额外 padding 改变课程卡片或按钮的大小。
- 液态模式的雾度系数为 `cardBlur × 13`，高斯模式为 `cardBlur × 20`，显式 `blurOverride` 不变。
- 果冻开关控制可点击面板按压缩放、弹性回弹和轻微悬停放大；系统启用减少动态效果时取消缩放动画。
- 指针监听不参加手势竞争，滑杆、输入和滚动仍由各自控件处理。

## 背景折射

`GlassBackdrop` 只过滤已经渲染的背景，不过滤文字、图标及表单内容。`shaders/liquid_glass.frag` 根据实际面板尺寸和四个圆角计算圆角矩形的距离场，再将位移集中在边缘：

1. 法线来自距离场的有限差分，折射沿边缘法线向内采样。
2. 位移在中心逐渐归零；中心不会被整体放大或扭曲。
3. RGB 在边缘分别采样，色散参数为零时关闭通道分离。
4. 采样坐标钳制在有效纹理范围，保留预乘 alpha，并处理 OpenGLES 纹理的 Y 翻转。

现有「折射」滑杆现在控制面板内背景弯曲，取消原先只对自选壁纸添加的整屏重影；默认壁纸、渐变和任意面板后面的场景使用同一实现。折射/色散为零时保留普通背景采样，不擅自修改已保存参数。

## 平台回退与资源

[Flutter 的 `ImageFilter.shader`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html) 仅支持 Impeller。先检查 `ImageFilter.isShaderFilterSupported`；Windows/Skia 等不支持的平台直接使用高斯模糊和同样的光学边缘，不调用不支持的 API。关闭液态玻璃后也完全回到高斯模式。

着色器程序首次需要时异步加载并共享，每个面板持有独立的 uniforms 实例，销毁时释放。加载失败时保留高斯回退。没有持续的逐帧计时动画、屏幕截图或背景图片重复解码；模糊和着色器滤镜合成为一个 `BackdropFilter`，过滤区域由面板的 `ClipRRect` 限定。

## 验证

`test/glass_optics_test.dart` 在真实着色器输出上检查横/纵卡片的中心不变、边缘折射、RGB 色散、零参数采样及透明输入 alpha，同时验证模式切换后尺寸不变、Skia 回退可点击、鼠标进出、滑杆拖动与减少动态效果。原有液态开关、课程信息卡和全部调休回归用例继续保留。

发布前运行 `flutter test --no-pub`、`flutter analyze --no-pub`、`flutter build apk --release --no-pub` 和 `tools/package.ps1`。当前电脑未连接 Android 真机，Impeller 的实际设备效果仍需在安装包上体验；着色器算法已由像素测试执行，不能将其等同于真机验证。
