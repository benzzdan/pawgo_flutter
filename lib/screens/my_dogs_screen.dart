import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/widgets/celebration_overlay.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

class MyDogsScreen extends StatefulWidget {
  const MyDogsScreen({super.key});

  @override
  State<MyDogsScreen> createState() => _MyDogsScreenState();
}

class _MyDogsScreenState extends State<MyDogsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _dogs = [];
  bool _loading = true;
  String? _error;
  bool _hasAnimated = false;
  bool _isRefreshing = false;
  bool _wasDogListEmpty = false;

  @override
  void initState() {
    super.initState();
    _fetchDogs();
  }

  Future<void> _fetchDogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      final data = await withRetry(() => _supabase
          .from('dogs')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false));
      final newDogs = List<Map<String, dynamic>>.from(data);
      final shouldCelebrate = _wasDogListEmpty && newDogs.isNotEmpty;
      setState(() {
        _dogs = newDogs;
        _loading = false;
        _wasDogListEmpty = newDogs.isEmpty;
      });

      // Celebrate when transitioning from empty to having dogs.
      if (shouldCelebrate) {
        final dogName = _dogs.first['name'] as String? ?? 'Your dog';
        _showFirstDogCelebration(dogName);
      }
    } catch (e) {
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _error = appError.message;
        _loading = false;
      });
    }
  }

  void _showFirstDogCelebration(String dogName) {
    if (!mounted) return;

    CelebrationOverlay.show(
      context,
      title: 'Welcome to the Pack!',
      subtitle: '$dogName is ready for adventures',
      illustrationAsset: 'assets/illustrations/corgi_celebration.gif',
      confettiColors: const [
        Color(0xFFF4A832), // Golden Paw
        Color(0xFFC07D4D), // Warm Caramel
        Color(0xFFFFF5E6), // Soft Cream
      ],
    );
  }

  Future<void> _openDogForm({Map<String, dynamic>? dog}) async {
    final result = await Navigator.pushNamed(
      context,
      '/dog-profile-form',
      arguments: dog == null ? null : Dog.fromMap(dog),
    );
    if (result == true && mounted) {
      _fetchDogs();
    }
  }

  void _deleteDog(Map<String, dynamic> dog) {
    final name = dog['name'] as String? ?? 'this dog';
    final dogId = dog['id'] as String?;
    if (dogId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove $name?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This will remove $name from your dogs list.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await withRetry(
                    () => _supabase.from('dogs').delete().eq('id', dogId));
                _fetchDogs();
              } catch (e) {
                if (mounted) {
                  final appError = AppError.from(e);
                  if (appError.isAuthError) {
                    ErrorHandler.instance.navigatorKey.currentState
                        ?.pushNamedAndRemoveUntil('/', (route) => false);
                    return;
                  }
                  ErrorHandler.instance
                      .handleError(context, e, screen: 'my_dogs');
                }
              }
            },
            child: Text(
              'Remove',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppColors.red500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchDogs();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;

    Widget illustration = Image.asset(
      'assets/illustrations/corgi_lying.png',
      width: 200,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(PhosphorIcons.dog(), size: 48, color: AppColors.textSecondary),
    );

    // Subtle floating idle animation unless reduce-motion
    if (!reduceMotion) {
      illustration = illustration
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(begin: 0, end: -2, duration: 3000.ms, curve: Curves.easeInOut);
    }

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          illustration,
          const SizedBox(height: 12),
          Text(
            'No pups yet',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first furry friend to get started',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => _openDogForm(),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.orange500,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange500.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add a Dog',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!reduceMotion) {
      content = content
          .animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: 400.ms,
            curve: Curves.easeOut,
          );
    }

    return content;
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.wifiSlash(), size: 48, color: AppColors.gray400),
            const SizedBox(height: 16),
            Text(
              'Unable to load your dogs. Please try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _fetchDogs();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.orange500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: PawProgressIndicator(color: AppColors.orange500),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_dogs.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.orange500,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pull-to-refresh paw icon indicator
            if (_isRefreshing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Icon(
                    PhosphorIcons.pawPrint(),
                    color: AppColors.orange500,
                    size: 24,
                  )
                      .animate(
                        onPlay: (c) => c.repeat(),
                      )
                      .rotate(
                        duration: 1000.ms,
                        curve: Curves.easeInOut,
                      ),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Dogs',
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your furry friends',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Dogs List with staggered entrance animations.
            ..._dogs.asMap().entries.map((entry) {
              final index = entry.key;
              final dog = entry.value;
              final card = Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _DogCard(
                  dog: dog,
                  onEdit: () => _openDogForm(dog: dog),
                  onDelete: () => _deleteDog(dog),
                ),
              );
              if (_hasAnimated) return card;
              return card
                  .animate()
                  .fadeIn(
                    duration: 400.ms,
                    curve: Curves.easeOut,
                    delay: Duration(milliseconds: index * 100),
                  )
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                    delay: Duration(milliseconds: index * 100),
                  );
            }),
            // Add Dog Card -- animates as the last staggered item.
            Builder(builder: (context) {
              final card = Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _AddDogCard(onTap: () => _openDogForm()),
              );
              if (_hasAnimated) return card;
              _hasAnimated = true;
              return card
                  .animate()
                  .fadeIn(
                    duration: 400.ms,
                    curve: Curves.easeOut,
                    delay: Duration(milliseconds: _dogs.length * 100),
                  )
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                    delay: Duration(milliseconds: _dogs.length * 100),
                  );
            }),
          ],
        ),
      ),
    );
  }
}

class _DogCard extends StatefulWidget {
  final Map<String, dynamic> dog;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _DogCard({required this.dog, required this.onEdit, this.onDelete});

  @override
  State<_DogCard> createState() => _DogCardState();
}

class _DogCardState extends State<_DogCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _idleController;
  late final Animation<double> _idleAnimation;

  @override
  void initState() {
    super.initState();
    // Subtle idle rotation: oscillates between -2 and +2 degrees.
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _idleAnimation = Tween<double>(begin: -0.035, end: 0.035).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.dog['name'] as String? ?? 'Unknown';
    final breed = widget.dog['breed'] as String? ?? '';
    final ageYears = widget.dog['age_years'];
    final weightKg = widget.dog['weight_kg'];
    final photoUrl = widget.dog['photo_url'] as String?;
    final notes = widget.dog['notes'] as String?;

    final ageText = ageYears != null ? '$ageYears yrs' : '-';
    final weightText = weightKg != null ? '$weightKg kg' : '-';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Dog avatar with idle rotation animation.
                  AnimatedBuilder(
                    animation: _idleAnimation,
                    builder: (context, child) => Transform.rotate(
                      angle: _idleAnimation.value,
                      child: child,
                    ),
                    child: _DogAvatar(photoUrl: photoUrl),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          breed,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _InfoColumn(label: 'Age', value: ageText),
                            const SizedBox(width: 16),
                            _InfoColumn(label: 'Weight', value: weightText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    notes,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ScaleOnPressButton(
                      scaleOnPress: 1.05,
                      onTap: widget.onEdit,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.orange50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Edit',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ShakeOnPressButton(
                      onTap: widget.onDelete,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.red50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Delete',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button that scales up slightly on press.
class _ScaleOnPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleOnPress;

  const _ScaleOnPressButton({
    required this.child,
    this.onTap,
    this.scaleOnPress = 1.05,
  });

  @override
  State<_ScaleOnPressButton> createState() => _ScaleOnPressButtonState();
}

class _ScaleOnPressButtonState extends State<_ScaleOnPressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleOnPress : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

/// A button that shakes horizontally on press before triggering the action.
class _ShakeOnPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ShakeOnPressButton({required this.child, this.onTap});

  @override
  State<_ShakeOnPressButton> createState() => _ShakeOnPressButtonState();
}

class _ShakeOnPressButtonState extends State<_ShakeOnPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Shake: 0 -> 2 -> -2 -> 2 -> -2 -> 0 pixels.
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2, end: -2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2, end: 2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2, end: -2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    _shakeController.reset();
    await _shakeController.forward();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Shows the dog's photo if available, otherwise shows the branded SVG
/// illustration with a warm gradient overlay.
class _DogAvatar extends StatelessWidget {
  final String? photoUrl;

  const _DogAvatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
        height: 80,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? _buildPhotoAvatar()
            : _buildIllustrationAvatar(),
      ),
    );
  }

  Widget _buildPhotoAvatar() {
    final headers = {
      'apikey': Env.current.supabaseAnonKey,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.network(
        photoUrl!,
        key: ValueKey(photoUrl),
        headers: headers,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _buildIllustrationAvatar(),
      ),
    );
  }

  Widget _buildIllustrationAvatar() {
    return Container(
      color: const Color(0xFFFFF5E6), // Soft Cream
      child: Center(
        child: Icon(
          PhosphorIcons.pawPrint(),
          size: 40,
          color: const Color(0xFFC07D4D), // Warm Caramel
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AddDogCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddDogCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDashed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.orange100,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: AppColors.orange500, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'Add another dog',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

