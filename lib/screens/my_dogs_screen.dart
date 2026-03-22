import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/widgets/celebration_overlay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyDogsScreen extends StatefulWidget {
  const MyDogsScreen({super.key});

  @override
  State<MyDogsScreen> createState() => _MyDogsScreenState();
}

class _MyDogsScreenState extends State<MyDogsScreen> {
  final List<Dog> _dogs = List.from(MockData.dogs);
  bool _hasAnimated = false;

  Future<void> _addDog() async {
    final dog = await showDialog<Dog>(
      context: context,
      builder: (context) => const _AddDogDialog(),
    );

    if (dog == null || !mounted) return;

    setState(() {
      _dogs.add(dog);
    });

    // Check if this is the user's first dog (count == 1).
    if (_dogs.length == 1) {
      await _showFirstDogCelebration(dog.name);
    }
  }

  Future<void> _showFirstDogCelebration(String dogName) async {
    final prefs = await SharedPreferences.getInstance();
    // Use a generic key (no userId in mock mode).
    const key = 'first_dog_celebration_seen';

    if (prefs.getBool(key) == true) return;

    await prefs.setBool(key, true);

    if (!mounted) return;

    CelebrationOverlay.show(
      context,
      title: 'Welcome to the Pack!',
      subtitle: '$dogName is ready for adventures',
      illustrationAsset: 'lib/assets/illustrations/dog_happy.svg',
      confettiColors: const [
        Color(0xFFF4A832), // Golden Paw
        Color(0xFFC07D4D), // Warm Caramel
        Color(0xFFFFF5E6), // Soft Cream
      ],
    );
  }

  void _deleteDog(Dog dog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove ${dog.name}?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This will remove ${dog.name} from your dogs list.',
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _dogs.remove(dog);
              });
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // Add Dog Card — animates as the last staggered item.
          Builder(builder: (context) {
            final card = Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _AddDogCard(onTap: _addDog),
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
    );
  }
}

class _DogCard extends StatefulWidget {
  final Dog dog;
  final VoidCallback? onDelete;

  const _DogCard({required this.dog, this.onDelete});

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
                    child: _DogAvatar(dog: widget.dog),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dog.name,
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.dog.breed,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _InfoColumn(
                                label: 'Age', value: widget.dog.age),
                            const SizedBox(width: 16),
                            _InfoColumn(
                                label: 'Weight', value: widget.dog.weight),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ScaleOnPressButton(
                      scaleOnPress: 1.05,
                      onTap: () {
                        // Edit action
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.border, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'Edit',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
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
    // Shake: 0 → 2 → -2 → 2 → -2 → 0 pixels.
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
  final Dog dog;

  const _DogAvatar({required this.dog});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
        height: 80,
        child: dog.photoUrl != null
            ? _buildPhotoAvatar()
            : _buildIllustrationAvatar(),
      ),
    );
  }

  Widget _buildPhotoAvatar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.network(
        dog.photoUrl!,
        key: ValueKey(dog.photoUrl),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _buildIllustrationAvatar(),
      ),
    );
  }

  Widget _buildIllustrationAvatar() {
    return Stack(
      children: [
        // Warm background.
        Container(
          color: const Color(0xFFFFF5E6), // Soft Cream
        ),
        // SVG illustration.
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(
              'lib/assets/illustrations/dog_sitting.svg',
              width: 64,
              height: 64,
            ),
          ),
        ),
        // Subtle gradient overlay (bottom to top) for warmth.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF4A2C2A).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4],
              ),
            ),
          ),
        ),
      ],
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AddDogCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddDogCard({this.onTap});

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
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.orange100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add,
                  color: AppColors.orange500, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a Dog',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Register a new furry friend',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple dialog for adding a new dog.
class _AddDogDialog extends StatefulWidget {
  const _AddDogDialog();

  @override
  State<_AddDogDialog> createState() => _AddDogDialogState();
}

class _AddDogDialogState extends State<_AddDogDialog>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  late final AnimationController _exitController;
  bool _nameHasText = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _nameController.addListener(() {
      final hasText = _nameController.text.trim().isNotEmpty;
      if (hasText != _nameHasText) {
        setState(() => _nameHasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    final dog = Dog(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _nameController.text.trim(),
      breed: _breedController.text.trim().isEmpty
          ? 'Mixed Breed'
          : _breedController.text.trim(),
      age: _ageController.text.trim().isEmpty
          ? '1 yr'
          : _ageController.text.trim(),
      weight: _weightController.text.trim().isEmpty
          ? '20 lbs'
          : _weightController.text.trim(),
      image: '🐕',
    );

    // Fade out form content before navigating.
    await _exitController.forward();
    if (mounted) Navigator.pop(context, dog);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitController),
      child: AlertDialog(
        title: Text(
          'Add a Dog',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dog illustration at the top.
              SvgPicture.asset(
                'lib/assets/illustrations/dog_sitting.svg',
                width: 80,
                height: 80,
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 16),
              // Staggered form fields: name, breed, age, weight — each 80ms apart.
              _buildField(_nameController, 'Name *', 'e.g. Buddy')
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 0.ms)
                  .slideY(begin: 0.1, end: 0, duration: 300.ms),
              const SizedBox(height: 12),
              _buildField(
                      _breedController, 'Breed', 'e.g. Golden Retriever')
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 80.ms)
                  .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: 80.ms),
              const SizedBox(height: 12),
              _buildField(_ageController, 'Age', 'e.g. 3 yrs')
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 160.ms)
                  .slideY(
                      begin: 0.1, end: 0, duration: 300.ms, delay: 160.ms),
              const SizedBox(height: 12),
              _buildField(_weightController, 'Weight', 'e.g. 65 lbs')
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 240.ms)
                  .slideY(
                      begin: 0.1, end: 0, duration: 300.ms, delay: 240.ms),
            ],
          ),
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
          // Save button with subtle pulse when name is filled.
          Builder(builder: (context) {
            final button = FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange500,
              ),
              child: Text(
                'Save',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            );
            if (!_nameHasText) return button;
            return button
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.02, 1.02),
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                );
          }),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextField(
      controller: controller,
      style: GoogleFonts.nunito(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        hintStyle: GoogleFonts.nunito(
          color: AppColors.textTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange500, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
