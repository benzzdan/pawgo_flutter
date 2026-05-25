import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/l10n/app_localizations.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/services/booking_rules.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/utils/booking_validators.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _supabase = Supabase.instance.client;

  // Walker data passed as argument
  Map<String, dynamic>? _walker;
  String? _walkerId;

  // Dogs list
  List<Map<String, dynamic>> _dogs = [];
  bool _loadingDogs = true;
  String? _dogsError;

  // Selection state
  String? _selectedDogId;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationMinutes = 60;
  String _notes = '';
  // Currently the UI only books solo walks. Group walks land behind a feature
  // flag — when introduced, expose a toggle that updates this and re-evaluates
  // the rules engine for every dog.
  final WalkType _selectedWalkType = WalkType.solo;

  // Validation state
  String? _dateTimeError;

  // Booking state
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_walker == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _walkerId = args['walker_id'] as String?;
        _walker = args['walker'] as Map<String, dynamic>?;
      }
      _fetchDogs();
    }
  }

  Future<void> _fetchDogs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }

      final data = await withRetry(() => _supabase
          .from('dogs')
          .select(
            'id, owner_id, name, breed, age_years, weight_kg, photo_url, '
            'temperament, vaccination_status, vaccination_expires_at',
          )
          .eq('owner_id', userId));

      setState(() {
        _dogs = List<Map<String, dynamic>>.from(data);
        _loadingDogs = false;
        // Auto-select the only dog when the rules allow it. Don't lock the
        // user into a chip they can't actually book on.
        if (_dogs.length == 1 && _ruleFor(_dogs[0]).allowed) {
          _selectedDogId = _dogs[0]['id'] as String;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _dogsError = 'Failed to load dogs';
        _loadingDogs = false;
      });
    }
  }

  String _walkerName() {
    final users = _walker?['users'];
    if (users is Map) return users['full_name'] ?? 'Walker';
    return 'Walker';
  }

  int _hourlyRate() {
    return (_walker?['hourly_rate_mxn'] as num?)?.toInt() ?? 0;
  }

  int _walkerExperienceYears() {
    return (_walker?['experience_years'] as num?)?.toInt() ?? 0;
  }

  /// Runs [evaluateBookingRules] against a Supabase dog row.
  BookingRuleResult _ruleFor(Map<String, dynamic> dogRow) {
    return evaluateBookingRules(
      dog: Dog.fromMap(dogRow),
      walkerExperienceYears: _walkerExperienceYears(),
      walkType: _selectedWalkType,
    );
  }

  double _totalPrice() {
    return _hourlyRate() * (_durationMinutes / 60);
  }

  DateTime _scheduledAt() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDogId == null) {
      _showError('Please select a dog');
      return;
    }

    final scheduled = _scheduledAt();
    final dateError = BookingValidators.validateScheduledDate(scheduled);
    if (dateError != null) {
      setState(() => _dateTimeError = dateError);
      return;
    }
    // Clear any previous date validation error
    setState(() => _dateTimeError = null);

    setState(() => _submitting = true);

    try {
      final response = await withRetry(() => _supabase.functions.invoke(
        'create-booking',
        body: {
          'walker_id': _walkerId,
          'dog_id': _selectedDogId,
          'scheduled_at': scheduled.toUtc().toIso8601String(),
          'duration_minutes': _durationMinutes,
          'notes': _notes.isNotEmpty ? _notes : null,
          'walk_type': _selectedWalkType.name,
        },
      ));

      if (!mounted) return;

      if (response.status == 201) {
        AnalyticsService.instance.bookingInitiated(walkerId: _walkerId!);
        BookingsScreen.pendingInitialTab = 'upcoming';
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
          arguments: {'tab': 2},
        );
      } else {
        ErrorHandler.instance.handleFunctionError(
          context,
          response,
          screen: 'booking',
          blocking: true,
          fallbackMessage: 'Booking failed. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'booking',
        blocking: true,
        fallbackMessage: 'Failed to create booking. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Book a Walk',
            style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWalkerSummary(),
                  const SizedBox(height: 20),
                  _buildDogSelection(),
                  const SizedBox(height: 20),
                  _buildDateTimePicker(),
                  const SizedBox(height: 20),
                  _buildDurationPicker(),
                  const SizedBox(height: 20),
                  _buildNotesField(),
                  const SizedBox(height: 20),
                  _buildPriceSummary(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildWalkerSummary() {
    final name = _walkerName();
    final rate = _hourlyRate();
    final rating = (_walker?['avg_rating'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.orange50,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'W',
              style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (rating != null) ...[
                      Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: AppColors.amber500, size: 16),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1),
                          style: GoogleFonts.nunito(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                    ],
                    Text('\$$rate MXN/hr',
                        style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDogSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Your Dog',
            style: GoogleFonts.nunito(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        if (_loadingDogs)
          const Center(child: PawProgressIndicator())
        else if (_dogsError != null)
          Center(
            child: Text(_dogsError!,
                style: GoogleFonts.nunito(color: AppColors.red500)),
          )
        else if (_dogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text('No dogs found. Add a dog in your profile first.',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ),
          )
        else
          ...List.generate(_dogs.length, (i) {
            final dog = _dogs[i];
            final isSelected = _selectedDogId == dog['id'];
            final ruling = _ruleFor(dog);
            final tile = Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.green50 : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.green600 : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.orange50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(PhosphorIcons.pawPrint(),
                        color: AppColors.orange500, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dog['name'] ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          '${dog['breed'] ?? 'Unknown breed'} · ${dog['weight_kg'] ?? '?'} kg',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: AppColors.green600, size: 24),
                ],
              ),
            );
            return Padding(
              padding: EdgeInsets.only(bottom: i < _dogs.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () {
                  if (!ruling.allowed) {
                    final l = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizedRuleError(l, ruling.errorCodeKey!),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedDogId = dog['id']);
                },
                child: ruling.allowed
                    ? tile
                    : Opacity(opacity: 0.4, child: tile),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDateTimePicker() {
    final hasError = _dateTimeError != null;
    final fieldBorderColor = hasError ? AppColors.red500 : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date & Time',
            style: GoogleFonts.nunito(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (hasError) setState(() => _dateTimeError = null);
                  _pickDate();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasError ? AppColors.red50 : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.calendarBlank(),
                          color: hasError ? AppColors.red500 : AppColors.blue500, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: GoogleFonts.nunito(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (hasError) setState(() => _dateTimeError = null);
                  _pickTime();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasError ? AppColors.red50 : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.clock(),
                          color: hasError ? AppColors.red500 : AppColors.purple500, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _selectedTime.format(context),
                        style: GoogleFonts.nunito(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.red50,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(color: AppColors.red500.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.warningCircle(), color: AppColors.red500, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _dateTimeError!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.red500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDurationPicker() {
    final durations = [30, 60, 90, 120];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration',
            style: GoogleFonts.nunito(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: durations.map((d) {
            final isSelected = _durationMinutes == d;
            final label = d < 60
                ? '${d}m'
                : d == 60
                    ? '1hr'
                    : '${d ~/ 60}.${(d % 60 == 30) ? '5' : '0'}hr';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: d != durations.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _durationMinutes = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.green600 : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.green600
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes (optional)',
            style: GoogleFonts.nunito(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any special instructions for the walker...',
            hintStyle: GoogleFonts.nunito(
                fontSize: 14, color: AppColors.textTertiary),
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
              borderSide:
                  const BorderSide(color: AppColors.green600, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: GoogleFonts.nunito(fontSize: 15),
          onChanged: (v) => _notes = v,
        ),
      ],
    );
  }

  Widget _buildPriceSummary() {
    final total = _totalPrice();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rate',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: AppColors.textSecondary)),
              Text('\$${_hourlyRate()} MXN/hr',
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Duration',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: AppColors.textSecondary)),
              Text('$_durationMinutes min',
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: GoogleFonts.nunito(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Text('\$${total.toStringAsFixed(0)} MXN',
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _submitting ? null : _confirmBooking,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _submitting ? AppColors.gray400 : AppColors.green600,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _submitting
                ? null
                : [
                    BoxShadow(
                      color: AppColors.green600.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: _submitting
                ? const PawProgressIndicator(size: 24, strokeWidth: 2.5, color: Colors.white)
                : Text(
                    'Confirm Booking - \$${_totalPrice().toStringAsFixed(0)} MXN',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
