import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:castelle/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Castelle\'e Hoş Geldiniz',
      'description': 'Seçkin yönetmenler ve yapımcılar ile en iyi oyuncuları bir araya getiren premium casting platformu.',
      'icon': '🎬',
    },
    {
      'title': 'Profilinizi Detaylandırın',
      'description': 'Fiziksel özelliklerinizi ve filmografinizi girerek cast direktörlerinin sizi kolayca bulmasını sağlayın.',
      'icon': '⭐',
    },
    {
      'title': 'Yatay Video Kuralı',
      'description': 'Castelle kalitesi için tanıtım, showreel ve mimik videolarınızı mutlaka YATAY (landscape) olarak çekip yüklemelisiniz. Dikey videolar kabul edilmemektedir.',
      'icon': '📱',
    },
    {
      'title': 'Takvim ve Anlık İletişim',
      'description': 'Görüşme, audition ve çekim planlarınızı takviminizden anlık olarak takip edin. Bildirimlerle hiçbir işi kaçırmayın.',
      'icon': '📅',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_onboarding', false);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        children: [
          // Background soft glowing gradients
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.15),
              ),
            ),
          ).animate().fadeIn(duration: 1000.ms),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Skip Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'GEÇ',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textOnPrimary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                // Slide Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Big Emoji/Icon representation
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  slide['icon']!,
                                  style: const TextStyle(fontSize: 56),
                                ),
                              ),
                            )
                                .animate(key: ValueKey('icon_$index'))
                                .scale(duration: 400.ms, curve: Curves.easeOutBack)
                                .shake(delay: 400.ms, duration: 400.ms),

                            const SizedBox(height: 48),

                            // Slide Title
                            Text(
                              slide['title']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                                .animate(key: ValueKey('title_$index'))
                                .fadeIn(duration: 450.ms)
                                .slideY(begin: 0.1),

                            const SizedBox(height: 16),

                            // Slide Description
                            Text(
                              slide['description']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.6,
                              ),
                            )
                                .animate(key: ValueKey('desc_$index'))
                                .fadeIn(delay: 150.ms, duration: 450.ms)
                                .slideY(begin: 0.1),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dots & Actions Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Indicators (Dots)
                      Row(
                        children: List.generate(_slides.length, (index) {
                          final isSelected = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: isSelected ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.accent : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      // Next/Get Started Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _slides.length - 1) {
                              _completeOnboarding();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPage == _slides.length - 1 ? 'BAŞLA' : 'İLERİ',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

