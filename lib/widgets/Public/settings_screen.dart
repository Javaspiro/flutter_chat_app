import 'package:a_pds/widgets/Public/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  String language = "English";
  String tone = "Casual";

  final user = FirebaseAuth.instance.currentUser;

  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late List<AnimationController> _itemControllers;

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _itemControllers = List.generate(10, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500 + (index * 50)),
      )..forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _listAnimationController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Professional App Bar with elegant design
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
              title: SlideTransition(
                position: _headerSlideAnimation,
                child: FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Content with refined spacing and design
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (user != null) ...[
                  _buildAnimatedUserCard(colorScheme),
                  const SizedBox(height: 28),
                ],

                _buildSectionHeader("Appearance", Icons.palette_outlined, colorScheme),
                const SizedBox(height: 12),
                _buildAnimatedSettingsCard(
                  colorScheme,
                  [
                    _buildAnimatedTile(
                      icon: Icons.brightness_4_outlined,
                      color: colorScheme.primary,
                      title: "Theme Mode",
                      value: _getThemeModeText(themeProvider.themeMode),
                      onTap: () => _showThemeDialog(context, themeProvider),
                      index: 0,
                    ),
                    _buildDivider(colorScheme),
                    _buildAnimatedTile(
                      icon: Icons.palette_outlined,
                      color: colorScheme.secondary,
                      title: "Accent Color",
                      value: themeProvider.themeColor,
                      onTap: () => _showColorDialog(context, themeProvider),
                      index: 1,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("Preferences", Icons.person_outline, colorScheme),
                const SizedBox(height: 12),
                _buildAnimatedSettingsCard(
                  colorScheme,
                  [
                    _buildAnimatedTile(
                      icon: Icons.language_outlined,
                      color: Colors.green,
                      title: "Language",
                      value: language,
                      onTap: () => _showLanguageDialog(context),
                      index: 2,
                    ),
                    _buildDivider(colorScheme),
                    _buildAnimatedTile(
                      icon: Icons.forum_outlined,
                      color: Colors.orange,
                      title: "Response Tone",
                      value: tone,
                      onTap: () => _showToneDialog(context),
                      index: 3,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("Privacy & Data", Icons.shield_outlined, colorScheme),
                const SizedBox(height: 12),
                _buildAnimatedSettingsCard(
                  colorScheme,
                  [
                    _buildAnimatedTile(
                      icon: Icons.lock_outline_rounded,
                      color: Colors.teal,
                      title: "Privacy Mode",
                      value: "Local storage only",
                      index: 4,
                    ),
                    _buildDivider(colorScheme),
                    _buildAnimatedTile(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      title: "Clear Chat History",
                      value: "Delete all messages",
                      onTap: _showClearMessagesDialog,
                      index: 5,
                    ),
                  ],
                ),

                if (user != null) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader("Account", Icons.account_circle_outlined, colorScheme),
                  const SizedBox(height: 12),
                  _buildAnimatedSettingsCard(
                    colorScheme,
                    [
                      _buildAnimatedTile(
                        icon: Icons.logout_rounded,
                        color: Colors.red,
                        title: "Sign Out",
                        value: user!.email ?? "",
                        onTap: _showLogoutDialog,
                        index: 6,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
                _buildAnimatedFooter(colorScheme),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: colorScheme.outline.withOpacity(0.2),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedUserCard(ColorScheme colorScheme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        user!.email![0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user!.displayName ?? "User",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user!.email ?? "",
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Verified",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSettingsCard(ColorScheme colorScheme, List<Widget> children) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: colorScheme.shadow.withOpacity(0.03),
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    VoidCallback? onTap,
    required int index,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 500 + (index * 50)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, double animationValue, child) {
        return Opacity(
          opacity: animationValue,
          child: Transform.translate(
            offset: Offset(30 * (1 - animationValue), 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: color.withOpacity(0.5),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedFooter(ColorScheme colorScheme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1000),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: colorScheme.primary.withOpacity(0.4),
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Smart Reply Assistant",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "Light";
      case ThemeMode.dark:
        return "Dark";
      default:
        return "System default";
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildAnimatedDialog(
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.brightness_4_rounded,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Theme Mode",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogOption(
                  context,
                  title: "Light",
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  icon: Icons.wb_sunny_rounded,
                  color: Colors.amber,
                  onChanged: (v) {
                    if (v != null) {
                      themeProvider.setThemeMode(v);
                      Navigator.pop(context);
                    }
                  },
                ),
                _buildDialogOption(
                  context,
                  title: "Dark",
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  icon: Icons.nightlight_round_rounded,
                  color: Colors.indigo,
                  onChanged: (v) {
                    if (v != null) {
                      themeProvider.setThemeMode(v);
                      Navigator.pop(context);
                    }
                  },
                ),
                _buildDialogOption(
                  context,
                  title: "System",
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  icon: Icons.settings_rounded,
                  color: Colors.grey,
                  onChanged: (v) {
                    if (v != null) {
                      themeProvider.setThemeMode(v);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  Widget _buildDialogOption<T>(BuildContext context, {
    required String title,
    required T value,
    required T groupValue,
    required IconData icon,
    required Color color,
    required void Function(T?) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value == groupValue ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDialog({required Widget child}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    );
  }

  void _showColorDialog(BuildContext context, ThemeProvider themeProvider) {
    List<Map<String, dynamic>> colors = [
      {"name": "blue", "color": Colors.blue, "label": "Blue"},
      {"name": "green", "color": Colors.green, "label": "Green"},
      {"name": "purple", "color": Colors.purple, "label": "Purple"},
      {"name": "orange", "color": Colors.orange, "label": "Orange"},
      {"name": "pink", "color": Colors.pink, "label": "Pink"},
      {"name": "teal", "color": Colors.teal, "label": "Teal"},
      {"name": "indigo", "color": Colors.indigo, "label": "Indigo"},
    ];

    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildAnimatedDialog(
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.palette_rounded,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Accent Color",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final colorData = colors[index];
                  return _buildColorOption(
                    context,
                    color: colorData["color"],
                    label: colorData["label"],
                    isSelected: themeProvider.themeColor == colorData["name"],
                    onTap: () {
                      themeProvider.setThemeColor(colorData["name"]);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  Widget _buildColorOption(BuildContext context, {
    required Color color,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? color : Theme.of(context).colorScheme.outline,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    List<Map<String, dynamic>> languages = [
      {"name": "English", "code": "en"},
      {"name": "Tamil", "code": "ta"},
      {"name": "Hindi", "code": "hi"},
    ];

    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildAnimatedDialog(
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Language",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: languages.map((lang) {
                return _buildDialogOptionWithIcon(
                  context,
                  title: lang["name"],
                  isSelected: language == lang["name"],
                  onTap: () {
                    setState(() => language = lang["name"]);
                    Navigator.pop(context);
                    _showAnimatedSnackBar(context, "Language: ${lang["name"]}");
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _showToneDialog(BuildContext context) {
    List<Map<String, dynamic>> tones = [
      {"name": "Casual", "icon": Icons.tag_faces_rounded, "color": Colors.amber, "desc": "Relaxed & friendly"},
      {"name": "Friendly", "icon": Icons.emoji_emotions_rounded, "color": Colors.green, "desc": "Warm & approachable"},
      {"name": "Formal", "icon": Icons.business_center_rounded, "color": Colors.blue, "desc": "Professional & courteous"},
      {"name": "Professional", "icon": Icons.work_rounded, "color": Colors.purple, "desc": "Business appropriate"},
    ];

    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildAnimatedDialog(
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.forum_rounded,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Response Tone",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: tones.map((toneData) {
                return InkWell(
                  onTap: () {
                    setState(() => tone = toneData["name"]);
                    Navigator.pop(context);
                    _showAnimatedSnackBar(context, "Tone: ${toneData["name"]}");
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: tone == toneData["name"]
                          ? toneData["color"].withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: toneData["color"].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              toneData["icon"],
                              color: toneData["color"],
                              size: 20
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                toneData["name"],
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                              Text(
                                toneData["desc"],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (tone == toneData["name"])
                          Icon(
                            Icons.check_circle_rounded,
                            color: toneData["color"],
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  Widget _buildDialogOptionWithIcon(BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  title.substring(0, 2).toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showAnimatedSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showClearMessagesDialog() {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildAnimatedDialog(
          child: AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Clear History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Delete all chat messages? This action cannot be undone.",
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.outline,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAnimatedSnackBar(context, "Chat history cleared");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Clear"),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildAnimatedDialog(
          child: AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Sign Out",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Are you sure you want to sign out?",
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.outline,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    _showAnimatedSnackBar(context, "Signed out successfully");
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Sign Out"),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}