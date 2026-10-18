# 第三方参考与授权

当前液态玻璃使用 [ruiqichenbiec/design-systems 的 Lens 方案](https://github.com/ruiqichenbiec/design-systems/tree/main/lens)，参考提交 `7a424c93b9be13cf835b91ea67495fec2ec0584e`、版本 `1.1.0-showcase.1`，移植其材质参数、斯涅尔光线、反光计算、弹簧反馈、Dock 选中层和单次边缘流光。来源文件为 `tokens.js`、`internal/renderer.js`、`internal/jelly-physics.js`、`internal/jelly.js`、`component-patterns.js`、`internal/optics.js` 和 `DESIGN.md`。Dock 到位回弹的弹簧参数为本工程适配值。

Copyright (c) 2026 DayDreamInAReverie。原始 MIT 许可证随项目保留在 [licenses/design-systems-LICENSE.txt](licenses/design-systems-LICENSE.txt)。Flutter 适配实现位于 `lib/theme/lens_material.dart`、`lib/widgets/glass.dart`、`glass_backdrop.dart`、`lens_reflection.dart`、`lens_motion.dart` 及 `shaders/liquid_glass.frag`。

此前版本参考过 [rdev/liquid-glass-react](https://github.com/rdev/liquid-glass-react)。虽然核心材质现已替换，为保留历史衍生代码的归属，其 MIT 声明继续保留如下。

## liquid-glass-react — MIT License

Copyright 2025 MAX ROVENSKY

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
