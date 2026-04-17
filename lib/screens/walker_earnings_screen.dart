import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerEarningsScreen extends StatefulWidget {
  const WalkerEarningsScreen({super.key});

  @override
  State<WalkerEarningsScreen> createState() => _WalkerEarningsScreenState();
}

class _WalkerEarningsScreenState extends State<WalkerEarningsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  double _totalEarnings = 0;
  int _completedWalks = 0;
  double _avgRating = 0;
  List<Map<String, dynamic>> _completedBookings = [];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }

      // Get walker profile
      final walkerRes = await withRetry(() => _supabase
          .from('walkers')
          .select('id, avg_rating, total_walks')
          .eq('user_id', userId)
          .maybeSingle());

      if (walkerRes == null) {
        setState(() {
          _isLoading = false;
          _error = 'No walker profile found. You need a walker account to view earnings.';
        });
        return;
      }

      final walkerId = walkerRes['id'] as String;
      final avgRating = (walkerRes['avg_rating'] as num?)?.toDouble() ?? 0.0;
      final totalWalks = (walkerRes['total_walks'] as num?)?.toInt() ?? 0;

      // Fetch completed bookings
      final bookings = await withRetry(() => _supabase
          .from('bookings')
          .select('*, dogs(name, breed), users!bookings_owner_id_fkey(full_name, avatar_url)')
          .eq('walker_id', walkerId)
          .eq('status', 'walk_completed')
          .order('completed_at', ascending: false));

      final bookingsList = List<Map<String, dynamic>>.from(bookings);

      // Calculate total earnings (total_price_mxn - commission_mxn)
      double earnings = 0;
      for (final b in bookingsList) {
        final total = (b['total_price_mxn'] as num?)?.toDouble() ?? 0;
        final commission = (b['commission_mxn'] as num?)?.toDouble() ?? 0;
        earnings += total - commission;
      }

      setState(() {
        _totalEarnings = earnings;
        _completedWalks = totalWalks;
        _avgRating = avgRating;
        _completedBookings = bookingsList;
        _isLoading = false;
      });
    } catch (e) {
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = appError.isNetworkError
            ? appError.message
            : 'Failed to load earnings. Please try again.';
      });
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Earnings',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange500))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadEarnings,
                  color: AppColors.orange500,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      Text(
                        'Completed Walks',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_completedBookings.isEmpty)
                        _buildEmptyState()
                      else
                        ..._completedBookings.map(_buildBookingItem),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: PhosphorIcons.wallet(PhosphorIconsStyle.fill),
            iconColor: AppColors.green600,
            bgColor: AppColors.green50,
            label: 'Total Earnings',
            value: '\$${_totalEarnings.toStringAsFixed(0)} MXN',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: PhosphorIcons.personSimpleWalk(),
            iconColor: AppColors.blue600,
            bgColor: AppColors.blue50,
            label: 'Walks',
            value: '$_completedWalks',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
            iconColor: AppColors.amber500,
            bgColor: AppColors.amber50,
            label: 'Rating',
            value: _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '-',
          ),
        ),
      ],
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    final dog = booking['dogs'] as Map<String, dynamic>?;
    final owner = booking['users'] as Map<String, dynamic>?;
    final totalPrice = (booking['total_price_mxn'] as num?)?.toDouble() ?? 0;
    final commission = (booking['commission_mxn'] as num?)?.toDouble() ?? 0;
    final earned = totalPrice - commission;
    final durationMinutes = booking['duration_minutes'];
    final completedAt = booking['completed_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: owner?['avatar_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      owner!['avatar_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(PhosphorIcons.user(), color: AppColors.green600),
                    ),
                  )
                : Icon(PhosphorIcons.user(), color: AppColors.green600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owner?['full_name'] ?? 'Dog Owner',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (dog != null) dog['name'] ?? 'Unknown dog',
                    if (durationMinutes != null) '${durationMinutes} min',
                  ].join(' · '),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (completedAt != null)
                  Text(
                    _formatDateTime(completedAt),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '+\$${earned.toStringAsFixed(0)}',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.green600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.wallet(PhosphorIconsStyle.fill), size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No Completed Walks Yet',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed walks and earnings will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.warningCircle(), size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEarnings,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange500),
              child: Text('Retry', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
