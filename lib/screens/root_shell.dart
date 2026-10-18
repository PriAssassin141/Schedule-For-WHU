import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/discover_screen.dart';
import 'package:class_manager/screens/home_screen.dart';
import 'package:class_manager/screens/mine_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/lens_dock.dart';

/// 应用外壳：全屏背景 + 三个页面 + 底部玻璃导航栏。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 全局饱和度滤镜
          ColorFiltered(
            colorFilter: ColorFilter.matrix(
              saturationMatrix(settings.saturation),
            ),
            child: const AppBackground(),
          ),
          IndexedStack(
            index: _tab,
            children: const [HomeScreen(), DiscoverScreen(), MineScreen()],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LensDock(
          key: const ValueKey('bottom_nav'),
          items: const [
            LensDockItem(Icons.home_rounded, '主页'),
            LensDockItem(Icons.explore_rounded, '发现'),
            LensDockItem(Icons.person_rounded, '我的'),
          ],
          selectedIndex: _tab,
          onChanged: (index) => setState(() => _tab = index),
        ),
      ),
    );
  }
}
