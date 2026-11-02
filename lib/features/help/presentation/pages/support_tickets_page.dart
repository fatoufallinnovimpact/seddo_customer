import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';
import 'package:seddo/features/help/presentation/pages/support_ticket_detail_page.dart';
import 'package:seddo/features/help/presentation/widgets/dashed_divider.dart';

enum TicketFilterTab { all, pending, resolved }

/// Page displaying the list of support claims / tickets of the logged-in user.
/// Matches the light-mode UI design from the user's reference:
/// - Top bar with back button, "Mes Réclamations" and subtitle
/// - Horizontal filter tabs with counts ("Toutes", "• En attente", "• Résolues")
/// - Ticket cards with #TK-XXXX pill, category with icon, colored status pill,
///   description, dashed divider line, and course footer
/// - Infinite scroll pagination by 10 items
/// - Tapping a card opens the bottom sheet modal detail
class SupportTicketsPage extends StatefulWidget {
  final HelpRepository? helpRepository;

  const SupportTicketsPage({
    super.key,
    this.helpRepository,
  });

  @override
  State<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends State<SupportTicketsPage> {
  late final HelpRepository _repository =
      widget.helpRepository ?? HelpRepository();
  final ScrollController _scrollController = ScrollController();

  TicketFilterTab _selectedTab = TicketFilterTab.all;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 1;
  List<SupportTicketModel> _allTickets = [];
  List<SupportTicketModel> _displayedTickets = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchTickets();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _loadMoreTickets();
    }
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _repository.getSupportTickets();
      if (mounted) {
        setState(() {
          _allTickets = items;
          _currentPage = 1;
          _updateDisplayedTickets();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<SupportTicketModel> get _currentFilteredTickets {
    switch (_selectedTab) {
      case TicketFilterTab.pending:
        return _allTickets
            .where((t) =>
                t.status.toUpperCase() != 'RESOLVED' &&
                t.status.toUpperCase() != 'CLOSED')
            .toList();
      case TicketFilterTab.resolved:
        return _allTickets
            .where((t) =>
                t.status.toUpperCase() == 'RESOLVED' ||
                t.status.toUpperCase() == 'CLOSED')
            .toList();
      case TicketFilterTab.all:
        return _allTickets;
    }
  }

  void _updateDisplayedTickets() {
    final filtered = _currentFilteredTickets;
    final countToTake = _currentPage * AppConstants.activityItemsPerPage;
    _displayedTickets = filtered.take(countToTake).toList();
    _hasMore = _displayedTickets.length < filtered.length;
  }

  void _onTabChanged(TicketFilterTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      _currentPage = 1;
      _updateDisplayedTickets();
    });
  }

  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() {
        _currentPage += 1;
        _updateDisplayedTickets();
        _isLoadingMore = false;
      });
    }
  }

  void _openDetail(SupportTicketModel ticket) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (modalContext) => SupportTicketDetailPage(
        ticket: ticket,
        helpRepository: _repository,
        isBottomSheet: true,
      ),
    );
    // Refresh tickets on return in case replies or status updated
    _fetchTickets();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'LOST_ITEM':
        return Icons.luggage_outlined;
      case 'PAYMENT':
      case 'PRICE':
      case 'REFUND':
        return Icons.credit_card_outlined;
      case 'SAFETY':
        return Icons.security_outlined;
      case 'DRIVER_BEHAVIOR':
      case 'CLIENT_BEHAVIOR':
        return Icons.person_outline_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 10),
            _buildFilterTabs(),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetchTickets,
                      child: _displayedTickets.isEmpty
                          ? _buildEmptyState()
                          : _buildTicketsList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.grayBorderDivider,
                  width: AppConstants.strokeWidthBorder,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSubtleBlack,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.slateDark,
                size: AppConstants.iconSizeMd,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mes réclamations',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Assistance prioritaire client',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final allCount = _allTickets.length;
    final pendingCount = _allTickets
        .where((t) =>
            t.status.toUpperCase() != 'RESOLVED' &&
            t.status.toUpperCase() != 'CLOSED')
        .length;
    final resolvedCount = _allTickets
        .where((t) =>
            t.status.toUpperCase() == 'RESOLVED' ||
            t.status.toUpperCase() == 'CLOSED')
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Toutes',
            count: allCount,
            isSelected: _selectedTab == TicketFilterTab.all,
            onTap: () => _onTabChanged(TicketFilterTab.all),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'En attente',
            count: pendingCount,
            dotColor: const Color(0xFFF59E0B),
            isSelected: _selectedTab == TicketFilterTab.pending,
            onTap: () => _onTabChanged(TicketFilterTab.pending),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Résolues',
            count: resolvedCount,
            dotColor: const Color(0xFF10B981),
            isSelected: _selectedTab == TicketFilterTab.resolved,
            onTap: () => _onTabChanged(TicketFilterTab.resolved),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    Color? dotColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bgColor = isSelected ? AppColors.slateDark : AppColors.white;
    final textColor = isSelected ? AppColors.white : AppColors.slateDark;
    final badgeBgColor =
        isSelected ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final badgeTextColor =
        isSelected ? AppColors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.slateDark : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXl,
      ),
      children: [
        Center(
          child: Container(
            width: AppConstants.sosOuterRingSize,
            height: AppConstants.sosOuterRingSize,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: AppConstants.iconSizeHero,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),
        Center(
          child: Text(
            'Aucune réclamation',
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontLg,
              fontWeight: FontWeight.w700,
              color: AppColors.slateDark,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Center(
          child: Text(
            'Vous n\'avez aucune réclamation dans cette catégorie.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketsList() {
    final count = _displayedTickets.length + (_isLoadingMore ? 1 : 0);
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _displayedTickets.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppConstants.spacingMd,
            ),
            child: Center(
              child: SizedBox(
                width: AppConstants.iconSizeXl,
                height: AppConstants.iconSizeXl,
                child: const CircularProgressIndicator(
                  strokeWidth: AppConstants.strokeWidthSelected,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          );
        }
        final ticket = _displayedTickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildTicketCard(SupportTicketModel ticket) {
    final isResolved = ticket.status.toUpperCase() == 'RESOLVED' ||
        ticket.status.toUpperCase() == 'CLOSED';

    final Color statusPillBg =
        isResolved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    final Color statusPillBorder =
        isResolved ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    final Color statusDotColor =
        isResolved ? const Color(0xFF059669) : const Color(0xFFD97706);
    final Color statusTextColor =
        isResolved ? const Color(0xFF047857) : const Color(0xFFB45309);
    final String statusLabel = isResolved
        ? 'RÉSOLU'
        : (ticket.status.toUpperCase() == 'IN_PROGRESS'
            ? 'EN COURS'
            : 'OUVERT');

    final categoryIcon = _getCategoryIcon(ticket.category);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _openDetail(ticket),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Ref pill, Category with icon, and Status pill
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ticket.ref.startsWith('#') ? ticket.ref : '#${ticket.ref}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slateDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            ticket.categoryLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slateDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusPillBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                      border: Border.all(
                        color: statusPillBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusDotColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title / Description
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Dashed separator line
              const DashedDivider(
                color: Color(0xFFE2E8F0),
                dashWidth: 4,
                dashSpace: 4,
              ),
              const SizedBox(height: 12),

              // Bottom footer row: Car icon + Course reference + date + detail badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      size: 14,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.rideRef != null && ticket.rideRef!.isNotEmpty
                          ? 'Course ${ticket.rideRef} • ${ticket.formattedDateShort}'
                          : ticket.formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Detail chip on right
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Détail',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slateDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
