import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/pawgo_bottom_sheet.dart';
import 'package:pawgo/widgets/pawgo_button.dart';

class MyDogsScreen extends StatefulWidget {
  const MyDogsScreen({super.key});

  @override
  State<MyDogsScreen> createState() => _MyDogsScreenState();
}

class _MyDogsScreenState extends State<MyDogsScreen> {
  final List<Dog> _dogs = List.from(MockData.dogs);

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
              setState(() {
                _dogs.removeAt(index);
              });
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

  void _showAddDogSheet() {
    PawgoBottomSheet.show(
      context: context,
      title: 'Add a Dog',
      builder: (sheetContext) => _AddDogForm(
        onDogAdded: (dog) {
          setState(() {
            _dogs.add(dog);
          });
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;

    Widget illustration = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/illustrations/corgi_lying.png',
        width: 150,
        fit: BoxFit.contain,
      ),
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
          const SizedBox(height: 60),
          illustration,
          const SizedBox(height: 24),
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

  @override
  Widget build(BuildContext context) {
    if (_dogs.isEmpty) {
      return _buildEmptyState(context);
    }

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
          // Dogs List
          ...List.generate(_dogs.length, (index) {
            final dog = _dogs[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _DogCard(
                dog: dog,
                onEdit: () {
                  // TODO: edit dog
                },
                onDelete: () {
                  _showDeleteConfirmation(dog, index);
                },
              ),
            )
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
              variant: PawgoButtonVariant.secondary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
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
                  dog.breed,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _DetailChip(label: dog.age),
                    const SizedBox(width: 8),
                    _DetailChip(label: dog.weight),
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

  const _AddDogForm({required this.onDogAdded});

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
      setState(() => _selectedImage = picked);
    }
  }

  Future<String?> _uploadPhoto(int dogId) async {
    if (_selectedImage == null) return null;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id ?? 'anonymous';
    final filePath = '$userId/$dogId.jpg';

    try {
      final bytes = await _selectedImage!.readAsBytes();
      await supabase.storage.from('dog-photos').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final publicUrl =
          supabase.storage.from('dog-photos').getPublicUrl(filePath);
      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final dogId = DateTime.now().millisecondsSinceEpoch;
    String? photoUrl;

    if (_selectedImage != null) {
      photoUrl = await _uploadPhoto(dogId);
      if (photoUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo upload failed — saving dog without photo',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.orange500,
          ),
        );
      }
    }

    final dog = Dog(
      id: dogId,
      name: _nameController.text.trim(),
      breed: _breedController.text.trim().isEmpty
          ? 'Mixed'
          : _breedController.text.trim(),
      age: _ageController.text.trim().isEmpty
          ? 'Unknown'
          : _ageController.text.trim(),
      weight: _weightController.text.trim().isEmpty
          ? 'Unknown'
          : _weightController.text.trim(),
      image: '\u{1F436}',
      photoUrl: photoUrl,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      widget.onDogAdded(dog);
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
    return GestureDetector(
      onTap: _isSaving ? null : _pickImage,
      child: Container(
        width: 96,
        height: 96,
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
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.textTertiary,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Corgi illustration header with fadeIn + scaleUp entrance
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/illustrations/corgi_sitting.png',
              height: 100,
              fit: BoxFit.contain,
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 300.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 16),

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
