import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/dog_service.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/celebration_overlay.dart';
import 'package:pawgo/widgets/pawgo_bottom_sheet.dart';
import 'package:pawgo/widgets/pawgo_button.dart';
import 'package:pawgo/widgets/pawgo_card.dart';

final _storageHeaders = {'apikey': Env.current.supabaseAnonKey};

class MyDogsScreen extends StatefulWidget {
  const MyDogsScreen({super.key});

  @override
  State<MyDogsScreen> createState() => _MyDogsScreenState();
}

class _MyDogsScreenState extends State<MyDogsScreen> {
  List<Dog> _dogs = [];
  int? _lastAddedIndex;
  int? _removingIndex;
  bool _isRefreshing = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDogs();
  }

  Future<void> _loadDogs() async {
    try {
      final dogs = await DogService.fetchDogs();
      if (mounted) {
        setState(() {
          _dogs = dogs;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, st) {
      developer.log('MyDogsScreen._loadDogs: ERROR $e\n$st', name: 'MyDogsScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load your dogs. Please try again.';
        });
      }
    }
  }

  void _showDeleteConfirmation(Dog dog, int index) {
    PawgoBottomSheet.show(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Dog photo
          if (dog.photoUrl != null && dog.photoUrl!.isNotEmpty)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                dog.photoUrl!,
                headers: _storageHeaders,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.orange50, AppColors.orange100],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.pets, color: AppColors.orange500, size: 32),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.orange50, AppColors.orange100],
                ),
              ),
              child: const Center(
                child: Icon(Icons.pets, color: AppColors.orange500, size: 32),
              ),
            ),
          const SizedBox(height: 16),
          // Title
          Text(
            'Remove ${dog.name}?',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This will remove ${dog.name} from your dogs list. This action cannot be undone.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // Remove Dog button (destructive)
          PawgoButton(
            label: 'Remove Dog',
            variant: PawgoButtonVariant.destructive,
            icon: Icons.delete_outline,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _removeDogAnimated(index);
            },
          ),
          const SizedBox(height: 8),
          // Cancel as text button
          PawgoButton(
            label: 'Cancel',
            variant: PawgoButtonVariant.text,
            onPressed: () {
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
  }

  void _removeDogAnimated(int index) {
    final dog = _dogs[index];
    setState(() => _removingIndex = index);
    Future.delayed(const Duration(milliseconds: 250), () async {
      try {
        await DogService.deleteDog(dog.id);
      } catch (e, st) {
        developer.log('MyDogsScreen._removeDog: ERROR $e\n$st', name: 'MyDogsScreen');
        if (mounted) {
          setState(() => _removingIndex = null);
          _loadDogs();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Something went wrong. Please try again.',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
          return;
        }
      }
      if (mounted) {
        setState(() {
          _dogs.removeAt(index);
          _removingIndex = null;
        });
      }
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadDogs();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _showAddDogSheet() {
    final wasEmpty = _dogs.isEmpty;
    PawgoBottomSheet.show(
      context: context,
      title: 'Add a Dog',
      builder: (sheetContext) => _AddDogForm(
        onDogAdded: (dog) {
          setState(() {
            _dogs.add(dog);
            _lastAddedIndex = _dogs.length - 1;
          });
          // Clear the flag after animation plays
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _lastAddedIndex = null);
          });
          // Show celebration if this is the first dog
          if (wasEmpty && mounted) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                CelebrationOverlay.show(
                  context,
                  title: 'Welcome to the Pack!',
                  subtitle: '${dog.name} is ready for adventures',
                  illustrationAsset: 'assets/illustrations/corgi_wagging.png',
                );
              }
            });
          }
        },
        onDismiss: () {
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _showEditDogSheet(Dog dog, int index) {
    PawgoBottomSheet.show(
      context: context,
      title: 'Edit Dog',
      builder: (sheetContext) => _EditDogForm(
        dog: dog,
        onDogUpdated: (updatedDog) {
          setState(() {
            _dogs[index] = updatedDog;
          });
        },
        onDismiss: () {
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;

    Widget illustration = Image.asset(
      'assets/illustrations/corgi_lying.png',
      width: 200,
      fit: BoxFit.contain,
    );

    // Subtle floating idle animation (2px, 3s loop) unless reduce-motion
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
          PawgoButton(
            label: 'Add a Dog',
            icon: Icons.add,
            onPressed: _showAddDogSheet,
          ),
        ],
      ),
    );

    // FadeIn + scaleUp entrance animation unless reduce-motion
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
            const Icon(Icons.wifi_off, size: 48, color: AppColors.gray400),
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
                  _isLoading = true;
                  _error = null;
                });
                _loadDogs();
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange500),
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Pull-to-refresh paw icon indicator
            if (_isRefreshing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Icon(
                    Icons.pets,
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
            // Dogs List
            ...List.generate(_dogs.length, (index) {
              final dog = _dogs[index];
              final isRemoving = _removingIndex == index;
              final isNewlyAdded = _lastAddedIndex == index;

              Widget card = Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _DogCard(
                  dog: dog,
                  onEdit: () {
                    _showEditDogSheet(dog, index);
                  },
                  onDelete: () {
                    _showDeleteConfirmation(dog, index);
                  },
                ),
              );

              // Delete shrink + fade animation
              if (isRemoving) {
                return card
                    .animate()
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(0.9, 0.9),
                      duration: 250.ms,
                      curve: Curves.easeIn,
                    )
                    .fadeOut(duration: 250.ms, curve: Curves.easeIn);
              }

              // Newly added bounce animation
              if (isNewlyAdded) {
                return card
                    .animate()
                    .scaleX(
                      begin: 0.95,
                      end: 1.0,
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 300.ms, curve: Curves.easeOut);
              }

              // Default staggered entrance
              return card
                  .animate()
                  .fadeIn(
                    delay: (index * 80).ms,
                    duration: 250.ms,
                    curve: Curves.easeOut,
                  )
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: (index * 80).ms,
                    duration: 250.ms,
                    curve: Curves.easeOut,
                  );
            }),
            // Add Dog Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PawgoButton(
                label: 'Add a Dog',
                icon: Icons.add,
                onPressed: _showAddDogSheet,
              ),
            ),
          ],
        ),
      );
  }
}

class _DogCard extends StatelessWidget {
  final Dog dog;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DogCard({required this.dog, this.onEdit, this.onDelete});

  Widget _buildPhoto() {
    if (dog.photoUrl != null && dog.photoUrl!.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.orange100,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          dog.photoUrl!,
          headers: _storageHeaders,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
        ),
      );
    }
    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange50, AppColors.orange100],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.pets,
          color: AppColors.orange500,
          size: 28,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PawgoCard(
      child: Row(
        children: [
          _buildPhoto(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dog.name,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dog.displayBreed,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _DetailChip(label: dog.displayAge),
                    const SizedBox(width: 8),
                    _DetailChip(label: dog.displayWeight),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                iconSize: 20,
                color: AppColors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                iconSize: 20,
                color: AppColors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;

  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}



/// Bottom-sheet form for adding a new dog, with photo picker, corgi
/// illustration header, and staggered entrance animations.
class _AddDogForm extends StatefulWidget {
  final ValueChanged<Dog> onDogAdded;
  final VoidCallback onDismiss;

  const _AddDogForm({required this.onDogAdded, required this.onDismiss});

  @override
  State<_AddDogForm> createState() => _AddDogFormState();
}

class _AddDogFormState extends State<_AddDogForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _selectedImage;
  bool _isSaving = false;
  bool _showSuccessCorgi = false;
  bool _justPickedPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
        _justPickedPhoto = true;
      });
      // Reset pulse flag after animation
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _justPickedPhoto = false);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final ageText = _ageController.text.trim();
      final weightText = _weightController.text.trim();
      final photoBytes =
          _selectedImage != null ? await _selectedImage!.readAsBytes() : null;

      final result = await DogService.addDog(
        name: _nameController.text.trim(),
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        ageYears: ageText.isNotEmpty ? int.tryParse(ageText) : null,
        weightKg: weightText.isNotEmpty ? double.tryParse(weightText) : null,
        photoBytes: photoBytes,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSuccessCorgi = true;
        });
        widget.onDogAdded(result.dog);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onDismiss();
        }
      }
    } catch (e, st) {
      developer.log('AddDogForm._submit: ERROR $e\n$st', name: 'MyDogsScreen');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Something went wrong. Please try again.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
      floatingLabelStyle: GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        color: AppColors.orange500,
      ),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.orange400, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildPhotoPicker() {
    Widget picker = GestureDetector(
      onTap: _isSaving ? null : _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.inputFill,
          border: Border.all(
            color: _selectedImage != null
                ? AppColors.orange500
                : AppColors.borderDashed,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _selectedImage != null
            ? (kIsWeb
                ? Image.network(
                    _selectedImage!.path,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(_selectedImage!.path),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.textTertiary,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );

    // Pulse animation when photo is just picked
    if (_justPickedPhoto) {
      picker = picker
          .animate()
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.05, 1.05),
            duration: 150.ms,
            curve: Curves.easeOut,
          )
          .then()
          .scale(
            begin: const Offset(1.05, 1.05),
            end: const Offset(1.0, 1.0),
            duration: 150.ms,
            curve: Curves.easeIn,
          );
    }

    return picker;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular photo picker
          _buildPhotoPicker()
              .animate()
              .fadeIn(delay: 100.ms, duration: 250.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                delay: 100.ms,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 20),

          // Name field (required) — stagger index 0
          TextFormField(
            controller: _nameController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Name *'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your dog\'s name';
              }
              return null;
            },
            textCapitalization: TextCapitalization.words,
          )
              .animate()
              .fadeIn(delay: 0.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 0.ms,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 12),

          // Breed field — stagger index 1
          TextFormField(
            controller: _breedController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Breed'),
            textCapitalization: TextCapitalization.words,
          )
              .animate()
              .fadeIn(delay: 80.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 80.ms,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 12),

          // Age field — stagger index 2
          TextFormField(
            controller: _ageController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Age'),
          )
              .animate()
              .fadeIn(delay: 160.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 160.ms,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 12),

          // Weight field — stagger index 3
          TextFormField(
            controller: _weightController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Weight'),
          )
              .animate()
              .fadeIn(delay: 240.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 240.ms,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 24),

          // Submit button with loading state — stagger index 4
          PawgoButton(
            label: _isSaving ? 'Saving...' : 'Add Dog',
            onPressed: _isSaving ? null : _submit,
            isLoading: _isSaving,
            icon: _isSaving ? null : Icons.pets,
          )
              .animate()
              .fadeIn(delay: 320.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 320.ms,
                duration: 250.ms,
                curve: Curves.easeOut,
              ),

          // Bottom padding for keyboard
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

/// Bottom-sheet form for editing an existing dog.
class _EditDogForm extends StatefulWidget {
  final Dog dog;
  final ValueChanged<Dog> onDogUpdated;
  final VoidCallback onDismiss;

  const _EditDogForm({
    required this.dog,
    required this.onDogUpdated,
    required this.onDismiss,
  });

  @override
  State<_EditDogForm> createState() => _EditDogFormState();
}

class _EditDogFormState extends State<_EditDogForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  final _picker = ImagePicker();

  XFile? _selectedImage;
  bool _isSaving = false;
  bool _justPickedPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dog.name);
    _breedController = TextEditingController(text: widget.dog.breed ?? '');
    _ageController = TextEditingController(
      text: widget.dog.ageYears?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.dog.weightKg?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
        _justPickedPhoto = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _justPickedPhoto = false);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final ageText = _ageController.text.trim();
      final weightText = _weightController.text.trim();
      final photoBytes =
          _selectedImage != null ? await _selectedImage!.readAsBytes() : null;

      final result = await DogService.updateDog(
        dogId: widget.dog.id,
        name: _nameController.text.trim(),
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        ageYears: ageText.isNotEmpty ? int.tryParse(ageText) : null,
        weightKg: weightText.isNotEmpty ? double.tryParse(weightText) : null,
        photoBytes: photoBytes,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        widget.onDogUpdated(result.dog);
        widget.onDismiss();
      }
    } catch (e, st) {
      developer.log('EditDogForm._submit: ERROR $e\n$st', name: 'MyDogsScreen');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Something went wrong. Please try again.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
      floatingLabelStyle: GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        color: AppColors.orange500,
      ),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.orange400, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildPhotoPicker() {
    final hasExistingPhoto =
        widget.dog.photoUrl != null && widget.dog.photoUrl!.isNotEmpty;

    Widget picker = GestureDetector(
      onTap: _isSaving ? null : _pickImage,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.inputFill,
          border: Border.all(
            color: (_selectedImage != null || hasExistingPhoto)
                ? AppColors.orange500
                : AppColors.borderDashed,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _selectedImage != null
            ? (kIsWeb
                ? Image.network(
                    _selectedImage!.path,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(_selectedImage!.path),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ))
            : hasExistingPhoto
                ? Image.network(
                    widget.dog.photoUrl!,
                    headers: _storageHeaders,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
      ),
    );

    if (_justPickedPhoto) {
      picker = picker
          .animate()
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.05, 1.05),
            duration: 150.ms,
            curve: Curves.easeOut,
          )
          .then()
          .scale(
            begin: const Offset(1.05, 1.05),
            end: const Offset(1.0, 1.0),
            duration: 150.ms,
            curve: Curves.easeIn,
          );
    }

    return picker;
  }

  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt_outlined,
          color: AppColors.textTertiary,
          size: 28,
        ),
        const SizedBox(height: 4),
        Text(
          'Change',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo picker showing current photo
          _buildPhotoPicker()
              .animate()
              .fadeIn(duration: 250.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 20),

          // Name field (required)
          TextFormField(
            controller: _nameController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Name *'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your dog\'s name';
              }
              return null;
            },
            textCapitalization: TextCapitalization.words,
          )
              .animate()
              .fadeIn(delay: 0.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.1, end: 0, delay: 0.ms, duration: 250.ms, curve: Curves.easeOut),
          const SizedBox(height: 12),

          // Breed field
          TextFormField(
            controller: _breedController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Breed'),
            textCapitalization: TextCapitalization.words,
          )
              .animate()
              .fadeIn(delay: 80.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.1, end: 0, delay: 80.ms, duration: 250.ms, curve: Curves.easeOut),
          const SizedBox(height: 12),

          // Age field
          TextFormField(
            controller: _ageController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Age (years)'),
            keyboardType: TextInputType.number,
          )
              .animate()
              .fadeIn(delay: 160.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.1, end: 0, delay: 160.ms, duration: 250.ms, curve: Curves.easeOut),
          const SizedBox(height: 12),

          // Weight field
          TextFormField(
            controller: _weightController,
            enabled: !_isSaving,
            decoration: _fieldDecoration('Weight (kg)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          )
              .animate()
              .fadeIn(delay: 240.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.1, end: 0, delay: 240.ms, duration: 250.ms, curve: Curves.easeOut),
          const SizedBox(height: 24),

          // Save button
          PawgoButton(
            label: _isSaving ? 'Saving...' : 'Save Changes',
            onPressed: _isSaving ? null : _submit,
            isLoading: _isSaving,
            icon: _isSaving ? null : Icons.check,
          )
              .animate()
              .fadeIn(delay: 320.ms, duration: 250.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.1, end: 0, delay: 320.ms, duration: 250.ms, curve: Curves.easeOut),

          // Bottom padding for keyboard
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
