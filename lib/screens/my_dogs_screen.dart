import 'package:flutter/material.dart';
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
          // Dogs List
          ..._dogs.map((dog) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _DogCard(
                  dog: dog,
                  onDelete: () => _deleteDog(dog),
                ),
              )),
          // Add Dog Card
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: _AddDogCard(onTap: _addDog),
          ),
        ],
      ),
    );
  }
}

class _DogCard extends StatelessWidget {
  final Dog dog;
  final VoidCallback? onDelete;

  const _DogCard({required this.dog, this.onDelete});

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
                child: GestureDetector(
                  onTap: () {
                    // Edit action
                  },
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onDelete,
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

class _AddDogDialogState extends State<_AddDogDialog> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _save() {
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

    Navigator.pop(context, dog);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            _buildField(_nameController, 'Name *', 'e.g. Buddy'),
            const SizedBox(height: 12),
            _buildField(_breedController, 'Breed', 'e.g. Golden Retriever'),
            const SizedBox(height: 12),
            _buildField(_ageController, 'Age', 'e.g. 3 yrs'),
            const SizedBox(height: 12),
            _buildField(_weightController, 'Weight', 'e.g. 65 lbs'),
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
        FilledButton(
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
        ),
      ],
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
