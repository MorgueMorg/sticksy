import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/config/onboarding_storage.dart';
import '../../../core/widgets/gradient_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      headline: 'Bring Your Sticker Ideas to Life',
      subtitle:
          'Turn fun, surreal, and bold concepts into stunning stickers with ease.',
      icon: Icons.auto_awesome,
    ),
    _OnboardingPageData(
      headline: 'Create & Edit in the Workshop',
      subtitle:
          'Add images, text, emojis, shapes, and draw. Use AI to remove backgrounds and generate ideas.',
      icon: Icons.palette_outlined,
    ),
    _OnboardingPageData(
      headline: 'Share Your Packs',
      subtitle:
          'Export sticker packs for WhatsApp, Telegram, or as ZIP. Your creations, your way.',
      icon: Icons.ios_share,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await setOnboardingCompleted(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPage(
                    headline: page.headline,
                    subtitle: page.subtitle,
                    icon: page.icon,
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        width: _currentPage == index ? 24.w : 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? CupertinoColors.white
                              : CupertinoColors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      borderRadius: BorderRadius.circular(14.r),
                      color: const Color(0xFF2C2C2E),
                      onPressed: _currentPage == _pages.length - 1
                          ? _finish
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            },
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Continue',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.headline,
    required this.subtitle,
    required this.icon,
  });

  final String headline;
  final String subtitle;
  final IconData icon;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.headline,
    required this.subtitle,
    required this.icon,
  });

  final String headline;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 40.h),
          Container(
            width: 160.w,
            height: 160.h,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(80.r),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemIndigo.withValues(alpha: 0.15),
                  blurRadius: 40.r,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 72.r,
              color: CupertinoColors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 48.h),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.white.withValues(alpha: 0.7),
              fontSize: 17.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
