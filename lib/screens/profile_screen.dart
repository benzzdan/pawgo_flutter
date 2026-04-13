import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart' hide SavedAddress;
import 'package:pawgo/services/role_service.dart';
import 'package:pawgo/services/theme_service.dart';
import 'package:pawgo/services/saved_address_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showAddressForm = false;
  String? _applicationStatus;
  bool _applicationLoading = true;

  // User profile data
  String? _fullName;
  String? _email;
  String? _phone;
  bool _profileLoading = true;

  // Saved addresses
  List<SavedAddress> _addresses = [];
  bool _addressesLoading = true;
  SavedAddress? _editingAddress;

  // Address form controllers
  final _labelController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  final _supabase = Supabase.instance.client;
  final _roleService = RoleService.instance;
  late final SavedAddressService _addressService;

  @override
  void initState() {
    super.initState();
    _addressService = SavedAddressService();
    _loadUserProfile();
    _checkApplicationStatus();
    _loadAddresses();
    _roleService.role.addListener(_onRoleChanged);
    _roleService.activeRole.addListener(_onRoleChanged);
    _roleService.isWalker.addListener(_onRoleChanged);
  }

  @override
  void dispose() {
    _roleService.role.removeListener(_onRoleChanged);
    _roleService.activeRole.removeListener(_onRoleChanged);
    _roleService.isWalker.removeListener(_onRoleChanged);
    _labelController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final addresses = await _addressService.fetchAddresses(userId);
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _addressesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  void _clearAddressForm() {
    _labelController.clear();
    _streetController.clear();
    _cityController.clear();
    _stateController.clear();
    _zipController.clear();
    _editingAddress = null;
  }

  void _editAddress(SavedAddress addr) {
    _labelController.text = addr.label;
    _streetController.text = addr.streetAddress;
    _cityController.text = addr.city ?? '';
    _stateController.text = addr.state ?? '';
    _zipController.text = addr.zipCode ?? '';
    setState(() {
      _editingAddress = addr;
      _showAddressForm = true;
    });
  }

  Future<void> _saveAddress() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final label = _labelController.text.trim();
    final street = _streetController.text.trim();
    if (label.isEmpty || street.isEmpty) return;

    try {
      if (_editingAddress != null) {
        await _addressService.updateAddress(
          id: _editingAddress!.id,
          label: label,
          streetAddress: street,
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          zipCode: _zipController.text.trim().isEmpty
              ? null
              : _zipController.text.trim(),
        );
      } else {
        await _addressService.createAddress(
          userId: userId,
          label: label,
          streetAddress: street,
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          zipCode: _zipController.text.trim().isEmpty
              ? null
              : _zipController.text.trim(),
        );
      }
      _clearAddressForm();
      setState(() => _showAddressForm = false);
      _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
      }
    }
  }

  Future<void> _deleteAddress(SavedAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Delete "${addr.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _addressService.deleteAddress(addr.id);
      _loadAddresses();
    }
  }

  Future<void> _toggleDefault(SavedAddress addr) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _addressService.setDefault(addr.id, userId);
    _loadAddresses();
  }

  void _onRoleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _email = user.email;

      final row = await _supabase
          .from('users')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _fullName = row?['full_name'] as String?;
        _phone = row?['phone'] as String?;
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
    }
  }

  Future<void> _checkApplicationStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final rows = await _supabase
          .from('walker_applications')
          .select('status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      setState(() {
        _applicationStatus =
            rows.isNotEmpty ? rows[0]['status'] as String? : null;
        _applicationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _applicationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange500, AppColors.orange400],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          child: Column(
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.arrowLeft(),
                          size: 20, color: Colors.white),
                    ),
                  ),
                  Text(
                    'Profile',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 24),
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.95) ?? Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.orange400, AppColors.orange500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange500.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child:
                            Text('\u{1F464}', style: TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _profileLoading
                          ? const SizedBox(
                              height: 48,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fullName ?? _email ?? '',
                                  style: GoogleFonts.nunito(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (_email != null)
                                  Text(
                                    _email!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (_phone != null)
                                  Text(
                                    _phone!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.pencilSimple(),
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Transform.translate(
      offset: const Offset(0, -48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saved Addresses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Addresses',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showAddressForm = !_showAddressForm),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.orange500,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange500.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Save your addresses for quick booking',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Address Form
            if (_showAddressForm) _buildAddressForm(),
            // Address List
            if (_addressesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.orange500)),
              )
            else if (_addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No saved addresses yet',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ..._addresses.map((addr) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AddressCard(
                      address: addr,
                      onEdit: () => _editAddress(addr),
                      onDelete: () => _deleteAddress(addr),
                      onToggleDefault: () => _toggleDefault(addr),
                    ),
                  )),
            const SizedBox(height: 24),
            // Become a Walker CTA
            _buildBecomeWalkerCard(),
            const SizedBox(height: 24),
            // Settings
            Text(
              'Settings',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsSection(),
            const SizedBox(height: 24),
            // Logout
            _buildLogout(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingAddress != null ? 'Edit Address' : 'Add New Address',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _FormField(
              hint: 'Label (e.g., Home, Work)',
              controller: _labelController),
          const SizedBox(height: 12),
          _FormField(
              hint: 'Street Address', controller: _streetController),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child:
                      _FormField(hint: 'City', controller: _cityController)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child:
                    _FormField(hint: 'State', controller: _stateController),
              ),
              const SizedBox(width: 8),
              SizedBox(
                  width: 96,
                  child:
                      _FormField(hint: 'ZIP', controller: _zipController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _saveAddress,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.orange500,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange500.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Save Address',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _clearAddressForm();
                  setState(() => _showAddressForm = false);
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
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

  Widget _buildBecomeWalkerCard() {
    if (_applicationLoading) {
      return const SizedBox.shrink();
    }

    // If user has an active walker profile, show role toggle
    if (_roleService.isWalker.value) {
      return _buildRoleToggle();
    }

    // Owner-only: show "Become a Walker" or "Application Status"
    final hasApplication = _applicationStatus != null &&
        _applicationStatus != 'approved';

    final String title;
    final String subtitle;
    final IconData icon;
    final String route;

    if (hasApplication) {
      title = 'Application Status';
      subtitle = _applicationStatus == 'pending'
          ? 'Your application is under review'
          : _applicationStatus == 'background_check_in_progress'
              ? 'Background check in progress'
              : _applicationStatus == 'rejected'
                  ? 'View details and re-apply options'
                  : 'Check your application status';
      icon = PhosphorIcons.clipboardText();
      route = '/walker-application-status';
    } else {
      title = 'Become a Walker';
      subtitle = 'Earn money walking dogs in your neighborhood';
      icon = PhosphorIcons.personSimpleWalk();
      route = '/walker-application';
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, route);
        // Refresh status when returning from application or status screen
        _checkApplicationStatus();
        _roleService.refresh();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.warmCaramel, AppColors.cacaoBrown],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.warmCaramel.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(), size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    final isWalkerMode = _roleService.activeRole.value == ActiveRole.walker;
    final activeColor =
        isWalkerMode ? AppColors.cacaoBrown : AppColors.warmCaramel;
    final modeLabel = isWalkerMode ? 'Walker Mode' : 'Owner Mode';
    final modeIcon = isWalkerMode ? PhosphorIcons.personSimpleWalk() : PhosphorIcons.pawPrint();
    final switchLabel = isWalkerMode ? 'Switch to Owner' : 'Switch to Walker';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // Current mode indicator
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(modeIcon, size: 24, color: activeColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modeLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isWalkerMode
                          ? 'You are in walker mode'
                          : 'You are in pet owner mode',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Switch role button
          GestureDetector(
            onTap: () {
              _roleService.switchRole();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isWalkerMode ? PhosphorIcons.pawPrint() : PhosphorIcons.personSimpleWalk(),
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    switchLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final items = [
      {
        'icon': PhosphorIcons.bell(),
        'color': AppColors.blue600,
        'bgColor': AppColors.blue50,
        'label': 'Notifications',
        'route': '/notification-preferences',
      },
      {
        'icon': PhosphorIcons.creditCard(),
        'color': AppColors.green600,
        'bgColor': AppColors.green50,
        'label': 'Payment Methods',
      },
      {
        'icon': PhosphorIcons.question(),
        'color': AppColors.orange500,
        'bgColor': AppColors.orange50,
        'label': 'Help & Support',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // Dark Mode toggle row
          _buildDarkModeToggleRow(),
          const Divider(height: 1, color: AppColors.surface),
          // Other settings items
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final route = item['route'] as String?;
            return GestureDetector(
              onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: index < items.length - 1
                      ? const Border(
                          bottom: BorderSide(color: AppColors.surface),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item['bgColor'] as Color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item['icon'] as IconData,
                          size: 18, color: item['color'] as Color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['label'] as String,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '\u{203A}',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDarkModeToggleRow() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.purple50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDark ? PhosphorIcons.moon() : PhosphorIcons.sun(),
                  size: 18,
                  color: AppColors.purple600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _themeModeLabel(mode),
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isDark,
                activeTrackColor: AppColors.orange500,
                activeThumbColor: Colors.white,
                onChanged: (on) {
                  ThemeService.instance
                      .setThemeMode(on ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  Widget _buildLogout() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (e) {
          debugPrint('Sign out error: $e');
        }
        // Always navigate to login, whether signOut succeeded or threw
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(PhosphorIcons.signOut(), size: 18, color: AppColors.red500),
              ),
              const SizedBox(width: 12),
              Text(
                'Log Out',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;

  const _FormField({required this.hint, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleDefault;

  const _AddressCard({
    required this.address,
    this.onEdit,
    this.onDelete,
    this.onToggleDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggleDefault,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: address.iconType == 'home'
                    ? AppColors.blue50
                    : AppColors.purple50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                address.iconType == 'home'
                    ? PhosphorIcons.house()
                    : PhosphorIcons.briefcase(),
                size: 20,
                color: address.iconType == 'home'
                    ? AppColors.blue600
                    : AppColors.purple600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      address.label,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orange100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Default',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address.displayAddress,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(PhosphorIcons.pencilSimple(),
                      size: 14, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.red50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(PhosphorIcons.trash(),
                      size: 14, color: AppColors.red500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
