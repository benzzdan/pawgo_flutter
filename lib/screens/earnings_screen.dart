import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/earnings_service.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  List<Payment> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final payments = await EarningsService.fetchWalkerPayments();
      if (mounted) {
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      developer.log('EarningsScreen._loadPayments: ERROR $e\n$st',
          name: 'EarningsScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load your earnings. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.arrowLeft(),
                  size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Earnings',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: PawProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.warningCircle(),
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPayments,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.wallet(),
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No earnings yet',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete walks to start earning!',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final completedPayments =
        _payments.where((p) => p.isCompleted).toList();
    final totalEarnings = completedPayments.fold<double>(
        0, (sum, p) => sum + p.walkerEarnings);
    final pendingPayments =
        _payments.where((p) => p.status == 'pending').toList();
    final pendingTotal = pendingPayments.fold<double>(
        0, (sum, p) => sum + p.walkerEarnings);

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSummaryCards(totalEarnings, pendingTotal),
          const SizedBox(height: 24),
          Text(
            'Payment History',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PaymentCard(payment: p),
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double totalEarnings, double pendingTotal) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Earned',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${totalEarnings.toStringAsFixed(0)} MXN',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.green700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.amber50,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.yellow800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${pendingTotal.toStringAsFixed(0)} MXN',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.yellow800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Payment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, size: 20, color: _statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.dogName ?? 'Walk',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (payment.ownerName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    payment.ownerName!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (payment.scheduledAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(payment.scheduledAt!),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payment.displayEarnings,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _statusColor,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  payment.displayStatus,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (payment.status) {
      case 'completed':
        return AppColors.green600;
      case 'pending':
        return AppColors.amber500;
      case 'failed':
        return AppColors.red500;
      case 'refunded':
        return AppColors.blue600;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _statusBgColor {
    switch (payment.status) {
      case 'completed':
        return AppColors.green50;
      case 'pending':
        return AppColors.amber50;
      case 'failed':
        return AppColors.red50;
      case 'refunded':
        return AppColors.blue50;
      default:
        return AppColors.surface;
    }
  }

  IconData get _statusIcon {
    switch (payment.status) {
      case 'completed':
        return PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
      case 'pending':
        return PhosphorIcons.clock();
      case 'failed':
        return PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
      case 'refunded':
        return PhosphorIcons.arrowCounterClockwise();
      default:
        return PhosphorIcons.creditCard();
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
