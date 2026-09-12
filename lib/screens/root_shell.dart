import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/discover_screen.dart';
import 'package:class_manager/screens/home_screen.dart';
import 'package:class_manager/screens/mine_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 应用外壳：全屏背景 + 三个页面 + 底部玻璃导航栏。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 启动时尝试自动登录校园网（仅在连接武大 WiFi 且已保存账号时执行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().tryCampusAutoLogin();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回到前台时重试自动登录
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().tryCampusAutoLogin();
    }
  }

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
            colorFilter: ColorFilter.matrix(saturationMatrix(settings.saturation)),
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
        child: LiquidGlass(
          key: const ValueKey('bottom_nav'),
          radius: BorderRadius.circular(28),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          tintAlphaOverride: 0.30,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: '主页',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _NavItem(
                icon: Icons.explore_rounded,
                label: '发现',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: '我的',
                selected: _tab == 2,
                onTap: () => setState(() => _tab = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: 42,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? theme.withValues(alpha: 0.28) : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 2),
            // 选中指示点
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? theme : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
