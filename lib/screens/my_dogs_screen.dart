import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/widgets/celebration_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      setState(() {
        _dogs = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });

      // Check if this is the user's first dog (count == 1).
      if (_dogs.length == 1) {
        final dogName = _dogs.first['name'] as String? ?? 'Your dog';
        await _showFirstDogCelebration(dogName);
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

  Future<void> _showFirstDogCelebration(String dogName) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _supabase.auth.currentUser?.id ?? 'unknown';
    final key = 'first_dog_celebration_seen_$userId';

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

  void _openDogForm({Map<String, dynamic>? dog}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DogFormScreen(
          dog: dog,
          onSaved: () {
            _fetchDogs();
          },
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load dogs',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _fetchDogs,
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
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
            // Empty state
            if (_dogs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48),
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
                      const Text('\u{1F436}', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'No dogs yet',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add your first furry friend to get started',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
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
            // Add Dog Card — animates as the last staggered item.
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.network(
        photoUrl!,
        key: ValueKey(photoUrl),
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
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.orange100,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Icon(Icons.add, color: AppColors.orange500, size: 32),
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

/// Full-screen form for adding or editing a dog profile.
class _DogFormScreen extends StatefulWidget {
  final Map<String, dynamic>? dog;
  final VoidCallback onSaved;

  const _DogFormScreen({this.dog, required this.onSaved});

  @override
  State<_DogFormScreen> createState() => _DogFormScreenState();
}

class _DogFormScreenState extends State<_DogFormScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  String? _photoUrl;
  File? _pickedImage;
  bool _saving = false;

  bool get _isEditing => widget.dog != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final dog = widget.dog!;
      _nameController.text = dog['name'] as String? ?? '';
      _breedController.text = dog['breed'] as String? ?? '';
      final age = dog['age_years'];
      if (age != null) _ageController.text = age.toString();
      final weight = dog['weight_kg'];
      if (weight != null) _weightController.text = weight.toString();
      _notesController.text = dog['notes'] as String? ?? '';
      _photoUrl = dog['photo_url'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadPhoto(String dogId) async {
    if (_pickedImage == null) return _photoUrl;

    final bytes = await _pickedImage!.readAsBytes();
    final ext = _pickedImage!.path.split('.').last.toLowerCase();
    final path = '$dogId/photo.$ext';

    await _supabase.storage.from('dog-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl =
        _supabase.storage.from('dog-photos').getPublicUrl(path);
    return publicUrl;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }

      final ageText = _ageController.text.trim();
      final weightText = _weightController.text.trim();

      final record = {
        'owner_id': userId,
        'name': _nameController.text.trim(),
        'breed': _breedController.text.trim(),
        'age_years': ageText.isNotEmpty ? int.tryParse(ageText) : null,
        'weight_kg': weightText.isNotEmpty ? double.tryParse(weightText) : null,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };

      String dogId;

      if (_isEditing) {
        dogId = widget.dog!['id'] as String;
        record.remove('owner_id');
        await withRetry(() => _supabase.from('dogs').update(record).eq('id', dogId));
      } else {
        final result =
            await withRetry(() => _supabase.from('dogs').insert(record).select().single());
        dogId = result['id'] as String;
      }

      // Upload photo if picked
      if (_pickedImage != null) {
        final url = await _uploadPhoto(dogId);
        if (url != null) {
          await _supabase
              .from('dogs')
              .update({'photo_url': url}).eq('id', dogId);
        }
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        ErrorHandler.instance.handleError(context, e, screen: 'my_dogs');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Dog' : 'Add a Dog',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.orange50,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: AppColors.borderDashed, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedImage != null
                        ? Image.file(_pickedImage!, fit: BoxFit.cover)
                        : (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? Image.network(
                                _photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _photoPlaceholder(),
                              )
                            : _photoPlaceholder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to add photo',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Name
              _buildLabel('Name *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'e.g., Max',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              // Breed
              _buildLabel('Breed'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _breedController,
                hint: 'e.g., Golden Retriever',
              ),
              const SizedBox(height: 20),
              // Age & Weight
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Age (years)'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _ageController,
                          hint: 'e.g., 3',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Weight (kg)'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _weightController,
                          hint: 'e.g., 25.5',
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Notes
              _buildLabel('Notes'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _notesController,
                hint: 'Special instructions, allergies, etc.',
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              // Save button
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _saving ? AppColors.gray400 : AppColors.orange500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _saving
                        ? []
                        : [
                            BoxShadow(
                              color:
                                  AppColors.orange500.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Add Dog',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt, color: AppColors.orange500, size: 32),
        const SizedBox(height: 4),
        Text(
          'Photo',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.orange500,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.white,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red500),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
