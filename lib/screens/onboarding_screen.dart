import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../widgets/glow_button.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0=logo, 1=name, 2=flag, 3=username
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  String _selectedFlag = '🇺🇸';
  String _selectedCountry = 'United States';
  final _searchController = TextEditingController();

  late AnimationController _logoGlowController;
  late Animation<double> _logoGlowAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const List<Map<String, String>> _countries = [
    {'flag': '🇺🇸', 'name': 'United States'},
    {'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'flag': '🇫🇷', 'name': 'France'},
    {'flag': '🇩🇪', 'name': 'Germany'},
    {'flag': '🇪🇸', 'name': 'Spain'},
    {'flag': '🇮🇹', 'name': 'Italy'},
    {'flag': '🇧🇷', 'name': 'Brazil'},
    {'flag': '🇯🇵', 'name': 'Japan'},
    {'flag': '🇰🇷', 'name': 'South Korea'},
    {'flag': '🇨🇳', 'name': 'China'},
    {'flag': '🇮🇳', 'name': 'India'},
    {'flag': '🇷🇺', 'name': 'Russia'},
    {'flag': '🇨🇦', 'name': 'Canada'},
    {'flag': '🇦🇺', 'name': 'Australia'},
    {'flag': '🇲🇽', 'name': 'Mexico'},
    {'flag': '🇦🇷', 'name': 'Argentina'},
    {'flag': '🇹🇷', 'name': 'Turkey'},
    {'flag': '🇸🇦', 'name': 'Saudi Arabia'},
    {'flag': '🇦🇪', 'name': 'UAE'},
    {'flag': '🇵🇱', 'name': 'Poland'},
    {'flag': '🇳🇱', 'name': 'Netherlands'},
    {'flag': '🇸🇪', 'name': 'Sweden'},
    {'flag': '🇳🇴', 'name': 'Norway'},
    {'flag': '🇩🇰', 'name': 'Denmark'},
    {'flag': '🇫🇮', 'name': 'Finland'},
    {'flag': '🇵🇹', 'name': 'Portugal'},
    {'flag': '🇨🇭', 'name': 'Switzerland'},
    {'flag': '🇧🇪', 'name': 'Belgium'},
    {'flag': '🇦🇹', 'name': 'Austria'},
    {'flag': '🇮🇪', 'name': 'Ireland'},
    {'flag': '🇿🇦', 'name': 'South Africa'},
    {'flag': '🇳🇬', 'name': 'Nigeria'},
    {'flag': '🇪🇬', 'name': 'Egypt'},
    {'flag': '🇲🇦', 'name': 'Morocco'},
    {'flag': '🇹🇭', 'name': 'Thailand'},
    {'flag': '🇻🇳', 'name': 'Vietnam'},
    {'flag': '🇵🇭', 'name': 'Philippines'},
    {'flag': '🇮🇩', 'name': 'Indonesia'},
    {'flag': '🇲🇾', 'name': 'Malaysia'},
    {'flag': '🇨🇱', 'name': 'Chile'},
    {'flag': '🇨🇴', 'name': 'Colombia'},
    {'flag': '🇵🇪', 'name': 'Peru'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _logoGlowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _logoGlowAnimation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _logoGlowController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    // Auto-advance from logo screen after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _goToStep(1);
    });
  }

  @override
  void dispose() {
    _logoGlowController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentStep = step);
      _fadeController.forward();
    });
  }

  Future<void> _complete() async {
    if (_nameController.text.trim().isEmpty || _usernameController.text.trim().isEmpty) {
      return;
    }
    final storage = await StorageService.getInstance();
    await storage.saveProfile(
      name: _nameController.text.trim(),
      flag: _selectedFlag,
      username: _usernameController.text.trim(),
    );
    await storage.setFirstLaunchDone();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppTheme.fadeRoute(const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildLogoScreen();
      case 1:
        return _buildNameStep();
      case 2:
        return _buildFlagStep();
      case 3:
        return _buildUsernameStep();
      default:
        return _buildLogoScreen();
    }
  }

  Widget _buildLogoScreen() {
    return Center(
      child: AnimatedBuilder(
        animation: _logoGlowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppTheme.purple.withValues(alpha: _logoGlowAnimation.value),
                  blurRadius: 60,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Text(
              'CHRONO',
              style: AppTheme.headingXL.copyWith(
                fontSize: 56,
                letterSpacing: 12,
                shadows: [
                  Shadow(
                    color: AppTheme.purple.withValues(alpha: _logoGlowAnimation.value),
                    blurRadius: 30,
                  ),
                  Shadow(
                    color: AppTheme.cyan.withValues(alpha: _logoGlowAnimation.value * 0.5),
                    blurRadius: 60,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'WHAT\'S YOUR NAME?',
            style: AppTheme.headingMedium.copyWith(letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text(
            'This is how others will see you',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          _buildNeonTextField(_nameController, 'Enter your name'),
          const SizedBox(height: 40),
          GlowButton(
            text: 'NEXT',
            onTap: () {
              if (_nameController.text.trim().isNotEmpty) {
                _goToStep(2);
              }
            },
            color: AppTheme.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildFlagStep() {
    final searchQuery = _searchController.text.toLowerCase();
    final filtered = _countries.where((c) {
      return c['name']!.toLowerCase().contains(searchQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'WHERE ARE YOU FROM?',
            style: AppTheme.headingMedium.copyWith(letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text('Select your country', style: AppTheme.bodyMedium),
          const SizedBox(height: 20),
          _buildNeonTextField(_searchController, 'Search country...', onChanged: (_) {
            setState(() {});
          }),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final country = filtered[index];
                final isSelected = country['flag'] == _selectedFlag;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFlag = country['flag']!;
                      _selectedCountry = country['name']!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.purple.withValues(alpha: 0.15)
                          : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.purple
                            : AppTheme.dimWhite.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.purple.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          country['flag']!,
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          country['name']!.length > 8
                              ? '${country['name']!.substring(0, 7)}…'
                              : country['name']!,
                          style: AppTheme.bodySmall.copyWith(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selected: $_selectedFlag $_selectedCountry',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.purple),
          ),
          const SizedBox(height: 12),
          GlowButton(
            text: 'NEXT',
            onTap: () => _goToStep(3),
            color: AppTheme.purple,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CHOOSE YOUR USERNAME',
            style: AppTheme.headingMedium.copyWith(letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text(
            'This will be shown in online matches',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          _buildNeonTextField(_usernameController, 'Enter username'),
          const SizedBox(height: 16),
          Text(
            '$_selectedFlag ${_nameController.text}',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.dimWhite),
          ),
          const SizedBox(height: 40),
          GlowButton(
            text: 'ENTER THE VOID',
            onTap: _complete,
            color: AppTheme.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildNeonTextField(TextEditingController controller, String hint,
      {Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
      textAlign: TextAlign.center,
      cursorColor: AppTheme.purple,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.bodyLarge.copyWith(
          color: AppTheme.dimWhite.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: AppTheme.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.dimWhite.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.dimWhite.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.purple, width: 1.5),
        ),
      ),
    );
  }
}
