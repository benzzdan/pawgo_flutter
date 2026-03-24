import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:google_fonts/google_fonts.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  String _selectedFilter = 'all';

  List<Walker> get _filteredWalkers {
    return MockData.walkers.where((w) {
      if (_selectedFilter == 'available') return w.availableColor == 'green';
      if (_selectedFilter == 'top-rated') return w.rating >= 4.9;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Header
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Find a Walker',
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/illustrations/corgi_wagging.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '123 Main St, New York, NY',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Filters
              Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'Available',
                    isSelected: _selectedFilter == 'available',
                    onTap: () => setState(() => _selectedFilter = 'available'),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'Top Rated',
                    isSelected: _selectedFilter == 'top-rated',
                    onTap: () => setState(() => _selectedFilter = 'top-rated'),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Results Count
        Container(
          width: double.infinity,
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            '${_filteredWalkers.length} walker${_filteredWalkers.length != 1 ? 's' : ''} nearby',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        // Walker Cards
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            itemCount: _filteredWalkers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final walker = _filteredWalkers[index];
              return _WalkerCard(walker: walker);
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange500 : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _WalkerCard extends StatelessWidget {
  final Walker walker;

  const _WalkerCard({required this.walker});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/walker', arguments: walker.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
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
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.orange400, AppColors.orange500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(walker.avatar,
                            style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    if (walker.verified)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.blue500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.shield,
                              color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            walker.name,
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (walker.backgroundCheck) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.green100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield,
                                      size: 10, color: AppColors.green600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.green700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: AppColors.orange500),
                          const SizedBox(width: 4),
                          Text(
                            '${walker.rating}',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            ' (${walker.reviews})',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            walker.distance,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${walker.price}',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'per walk',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats Row
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.purple100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('\u{1F6B6}', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${walker.walks}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    ' walks',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.blue100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('\u{26A1}', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    walker.responseTime,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Specialties & Availability
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: walker.specialties
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.orange50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: walker.availableColor == 'green'
                            ? AppColors.green500
                            : walker.availableColor == 'blue'
                                ? AppColors.blue500
                                : AppColors.gray400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      walker.availability,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: walker.availableColor == 'green'
                            ? AppColors.green600
                            : walker.availableColor == 'blue'
                                ? AppColors.blue600
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
