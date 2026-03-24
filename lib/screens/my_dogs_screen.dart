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
          // Dogs List
          ..._dogs.map((dog) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _DogCard(dog: dog),
              )),
          // Add Dog Card
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: _AddDogCard(onTap: _showAddDogSheet),
          ),
        ],
      ),
    );
  }
}

class _DogCard extends StatelessWidget {
  final Dog dog;

  const _DogCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.orange400, AppColors.orange500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(dog.image, style: const TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dog.breed,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _InfoColumn(label: 'Age', value: dog.age),
                        const SizedBox(width: 16),
                        _InfoColumn(label: 'Weight', value: dog.weight),
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
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 2),
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
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'View Profile',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
