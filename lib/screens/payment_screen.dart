import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _supabase = Supabase.instance.client;

  String? _bookingId;
  double _totalPrice = 0;
  String _walkerName = 'Walker';
  int _durationMinutes = 60;

  bool _initializing = true;
  bool _processing = false;
  String? _error;
  bool _paymentComplete = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _bookingId = args['booking_id'] as String?;
        _totalPrice = (args['total_price'] as num?)?.toDouble() ?? 0;
        _walkerName = args['walker_name'] as String? ?? 'Walker';
        _durationMinutes = args['duration_minutes'] as int? ?? 60;
      }
      _initRevenueCat();
    }
  }

  bool get _isLocalDev => Env.current.revenueCatApiKey.contains('LOCAL');

  Future<void> _initRevenueCat() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ErrorHandler.instance.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/', (route) => false);
      return;
    }

    if (_isLocalDev) {
      setState(() => _initializing = false);
      return;
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(Env.current.revenueCatApiKey)
          ..appUserID = userId,
      );

      setState(() => _initializing = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize payment system';
        _initializing = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (_bookingId == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    // Skip RevenueCat in local dev — confirm directly via Edge Function
    if (_isLocalDev) {
      await _confirmPaymentDirectly();
      return;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering == null || currentOffering.availablePackages.isEmpty) {
        await _confirmPaymentDirectly();
        return;
      }

      final package = currentOffering.availablePackages.first;
      final purchaseResult = await Purchases.purchasePackage(package);

      if (purchaseResult.entitlements.all.values
          .any((entitlement) => entitlement.isActive)) {
        await _confirmPaymentDirectly();
      } else {
        setState(() {
          _error = 'Payment was not completed. Please try again.';
          _processing = false;
        });
      }
    } on PlatformException catch (e) {
      if (e.code == '1' || e.message?.contains('cancel') == true) {
        setState(() {
          _error = null;
          _processing = false;
        });
        return;
      }
      setState(() {
        _error = 'Payment failed: ${e.message ?? 'Unknown error'}';
        _processing = false;
      });
      AnalyticsService.instance.paymentFailed(
        bookingId: _bookingId!,
        error: e.message ?? 'Unknown error',
      );
    } catch (e) {
      await _confirmPaymentDirectly();
    }
  }

  Future<void> _confirmPaymentDirectly() async {
    try {
      final response = await withRetry(() => _supabase.functions.invoke(
        'confirm-payment',
        body: {
          'booking_id': _bookingId,
          'amount_mxn': _totalPrice,
        },
      ));

      if (!mounted) return;

      if (response.status == 200) {
        setState(() {
          _paymentComplete = true;
          _processing = false;
        });
        AnalyticsService.instance.bookingCompleted(bookingId: _bookingId!);
      } else {
        final appError = AppError.fromFunctionResponse(response);
        setState(() {
          _error = appError.message;
          _processing = false;
        });
        AnalyticsService.instance.paymentFailed(
          bookingId: _bookingId!,
          error: appError.message,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _error = appError.isNetworkError
            ? appError.message
            : 'Failed to confirm payment. Please try again.';
        _processing = false;
      });
    }
  }

  Future<void> _cancelBooking() async {
    try {
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'}).eq('id', _bookingId!);
      AnalyticsService.instance.bookingCancelled(bookingId: _bookingId!);
    } catch (_) {
      // Best effort cancellation
    }
    if (mounted) {
      Navigator.pop(context, 'cancelled');
    }
  }

  Future<bool> _onWillPop() async {
    if (_paymentComplete) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Payment?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'If you leave now, your booking will be cancelled.',
          style: GoogleFonts.nunito(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: AppColors.green600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Booking',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: AppColors.red500)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _cancelBooking();
      return false; // We handle navigation in _cancelBooking
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paymentComplete,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(PhosphorIcons.arrowLeft(), color: AppColors.textPrimary),
            onPressed: () async {
              if (_paymentComplete) {
                Navigator.pop(context, 'success');
              } else {
                await _onWillPop();
              }
            },
          ),
          title: Text('Payment',
              style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          centerTitle: true,
        ),
        body: _paymentComplete ? _buildSuccessView() : _buildPaymentView(),
      ),
    );
  }

  Widget _buildPaymentView() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(),
                const SizedBox(height: 24),
                _buildPaymentMethods(),
                const SizedBox(height: 16),
                if (_error != null) _buildErrorBanner(),
              ],
            ),
          ),
        ),
        _buildPayButton(),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Walker',
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: AppColors.textSecondary)),
              Text(_walkerName,
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
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: GoogleFonts.nunito(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text('\$${_totalPrice.toStringAsFixed(0)} MXN',
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Method',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green600, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(PhosphorIcons.creditCard(),
                      color: AppColors.green600, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In-App Purchase',
                          style: GoogleFonts.nunito(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Secure payment via App Store / Google Play',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                    color: AppColors.green600, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.lock(), color: AppColors.textTertiary, size: 14),
              const SizedBox(width: 4),
              Text('Secured by RevenueCat',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.red50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red500.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.warningCircle(), color: AppColors.red500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!,
                style: GoogleFonts.nunito(
                    fontSize: 14, color: AppColors.red500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
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
        onTap: _processing ? null : _processPayment,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _processing ? AppColors.gray400 : AppColors.green600,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _processing
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
            child: _processing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(
                    _error != null
                        ? 'Retry Payment'
                        : 'Pay \$${_totalPrice.toStringAsFixed(0)} MXN',
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

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.green50,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.green200, width: 3),
              ),
              child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  color: AppColors.green600, size: 56),
            ),
            const SizedBox(height: 24),
            Text('Payment Successful!',
                style: GoogleFonts.nunito(
                    fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Your walk with $_walkerName has been confirmed. The walker will be notified.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false,
                    arguments: {'tab': 2});
              },
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.green600,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green600.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text('Done',
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
