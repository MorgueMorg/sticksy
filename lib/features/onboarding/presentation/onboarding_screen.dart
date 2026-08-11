import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/onboarding_storage.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      emoji: '✨',
      headline: 'Describe it.\nWe draw it.',
      body: 'Type "a sleepy cat holding a coffee" and get a finished sticker — '
          'already cut out, already the right size.',
      colors: [AppColors.pink, AppColors.violet],
    ),
    _PageData(
      emoji: '🎨',
      headline: 'Make it yours',
      body: 'Layer text, emoji, shapes and freehand drawing. Add the classic '
          'white die-cut border with one slider.',
      colors: [AppColors.cyan, AppColors.violet],
    ),
    _PageData(
      emoji: '🚀',
      headline: 'Send it everywhere',
      body: 'Organise stickers into packs and export for WhatsApp, Telegram, '
          'or as a plain ZIP.',
      colors: [AppColors.lime, AppColors.cyan],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await setOnboardingCompleted(true);
    widget.onComplete();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 12.w, top: 4.h),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    isLast ? '' : 'Skip',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _page = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _Page(data: _pages[index]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 28.h),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final active = _page == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        width: active ? 28.w : 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                          gradient: active
                              ? LinearGradient(colors: _pages[index].colors)
                              : null,
                          color: active
                              ? null
                              : AppColors.textTertiary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 26.h),
                  GradientButton(
                    label: isLast ? 'Start creating' : 'Next',
                    icon: isLast
                        ? CupertinoIcons.sparkles
                        : CupertinoIcons.arrow_right,
                    colors: _pages[_page].colors,
                    onPressed: _next,
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

class _PageData {
  const _PageData({
    required this.emoji,
    required this.headline,
    required this.body,
    required this.colors,
  });

  final String emoji;
  final String headline;
  final String body;
  final List<Color> colors;
}

class _Page extends StatelessWidget {
  const _Page({required this.data});

  final _PageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150.r,
            height: 150.r,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: data.colors),
              borderRadius: BorderRadius.circular(46.r),
              boxShadow: [
                BoxShadow(
                  color: data.colors.last.withValues(alpha: 0.45),
                  blurRadius: 50.r,
                  offset: Offset(0, 18.r),
                ),
              ],
            ),
            child: Center(
              child: Text(data.emoji, style: TextStyle(fontSize: 62.sp)),
            ),
          ),
          SizedBox(height: 44.h),
          Text(
            data.headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30.sp,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
