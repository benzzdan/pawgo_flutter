import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Screen shown when a walker declines or the request expires.
/// Displays up to 3 suggested alternative walkers with "Book Instead" buttons.
class AlternativeWalkersScreen extends StatefulWidget {
  const AlternativeWalkersScreen({
    super.key,
    this.bookingId,
    this.suggestedWalkerIds,
    this.walkersFuture,
  });

  final String? bookingId;
  final List<String>? suggestedWalkerIds;

  /// Injectable future for testing — bypasses Supabase fetch.
  final Future<List<Map<String, dynamic>>>? walkersFuture;

  @override
  State<AlternativeWalkersScreen> createState() =>
      _AlternativeWalkersScreenState();
}

class _AlternativeWalkersScreenState extends State<AlternativeWalkersScreen> {
  List<Map<String, dynamic>> _walkers = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _originalBooking;

  String? _bookingId;
  List<String> _walkerIds = [];

  @override
  void initState() {
    super.initState();
    _bookingId = widget.bookingId;
    _walkerIds = widget.suggestedWalkerIds ?? [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _bookingId = args['booking_id'] as String?;
        final ids = args['suggested_walker_ids'];
        if (ids is List) {
          _walkerIds = ids.cast<String>();
        }
      }
    }

    if (_isLoading) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use injected future or fetch from Supabase
      final walkers = widget.walkersFuture != null
          ? await widget.walkersFuture!
          : await _fetchWalkers();

      // Fetch original booking details for rebooking
      if (_bookingId != null && widget.walkersFuture == null) {
        final bookingData = await withRetry(() => Supabase.instance.client
            .from('bookings')
            .select('*, dogs(id, name, breed)')
            .eq('id', _bookingId!)
            .single());
        _originalBooking = bookingData;
      }

      if (!mounted) return;
      setState(() {
        _walkers = walkers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load alternative walkers';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWalkers() async {
    if (_walkerIds.isEmpty) return [];
    final data = await withRetry(() => Supabase.instance.client
        .from('walkers')
        .select(
            'id, user_id, hourly_rate_mxn, avg_rating, total_walks, bio, users(full_name, avatar_url)')
        .inFilter('id', _walkerIds));
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _bookInstead(Map<String, dynamic> walker) async {
    if (_originalBooking == null) {
      ErrorHandler.instance.showRecoverableError(
        context,
        'Cannot rebook — original booking details unavailable.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final users = walker['users'] as Map<String, dynamic>?;
        final name = users?['full_name'] ?? 'this walker';
        return AlertDialog(
          title: Text('Book with $name?',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Text(
              'A new walk request will be sent for the same date, time, and dog.',
              style: GoogleFonts.nunito()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Book',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.green600)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      final response = await withRetry(() =>
          Supabase.instance.client.functions.invoke(
            'create-booking',
            body: {
              'walker_id': walker['id'],
              'dog_id': _originalBooking!['dog_id'],
              'scheduled_at': _originalBooking!['scheduled_at'],
              'duration_minutes': _originalBooking!['duration_minutes'],
              'notes': _originalBooking!['notes'],
            },
          ));

      if (!mounted) return;

      if (response.status == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Walk request sent!',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.green600,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        ErrorHandler.instance.handleFunctionError(
          context,
          response,
          screen: 'alternative_walkers',
          blocking: true,
          fallbackMessage: 'Failed to create booking. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'alternative_walkers',
        fallbackMessage: 'Failed to create booking. Please try again.',
      );
    }
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
        title: Text('Alternative Walkers',
            style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: PawProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.warningCircle(),
                  size: 48, color: AppColors.red500),
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text('Retry',
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_walkers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.magnifyingGlass(),
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.sm),
              Text('No alternative walkers available',
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('Try searching for walkers nearby',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (route) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text('Browse Walkers',
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Text(
            'Your walker was unavailable. Here are some alternatives:',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: _walkers.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _WalkerCard(
              walker: _walkers[index],
              onBookInstead: () => _bookInstead(_walkers[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _WalkerCard extends StatelessWidget {
  final Map<String, dynamic> walker;
  final VoidCallback onBookInstead;

  const _WalkerCard({required this.walker, required this.onBookInstead});

  @override
  Widget build(BuildContext context) {
    final users = walker['users'] as Map<String, dynamic>?;
    final name = users?['full_name'] as String? ?? 'Unknown Walker';
    final rate = (walker['hourly_rate_mxn'] as num?)?.toInt() ?? 0;
    final rating = (walker['avg_rating'] as num?)?.toDouble();
    final totalWalks = walker['total_walks'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (rating != null) ...[
                          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                              color: AppColors.amber500, size: 16),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: GoogleFonts.nunito(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text('$totalWalks walks',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('\$$rate MXN/hr',
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green600)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onBookInstead,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text('Book Instead',
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
