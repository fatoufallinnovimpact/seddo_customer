import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';
import 'package:seddo/features/help/presentation/pages/support_ticket_detail_page.dart';

/// Page displaying the list of support claims / tickets of the logged-in user.
/// Connects to GET /v1/support/tickets (SupportController_mine).
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
          _displayedTickets =
              _allTickets.take(AppConstants.activityItemsPerPage).toList();
          _hasMore = _displayedTickets.length < _allTickets.length;
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

  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    final nextPage = _currentPage + 1;
    final nextBatch = _allTickets
        .skip((nextPage - 1) * AppConstants.activityItemsPerPage)
        .take(AppConstants.activityItemsPerPage)
        .toList();

    if (mounted) {
      setState(() {
        _currentPage = nextPage;
        _displayedTickets.addAll(nextBatch);
        _hasMore = _displayedTickets.length < _allTickets.length;
        _isLoadingMore = false;
      });
    }
  }

  void _openDetail(SupportTicketModel ticket) async {
    await Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: SupportTicketDetailPage(
          ticket: ticket,
          helpRepository: _repository,
        ),
      ),
    );
    // Refresh tickets on return in case replies or status updated
    _fetchTickets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
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
            child: Text(
              'Mes réclamations',
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.slateDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              color: AppColors.grayBgLight,
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
            'Vous n\'avez aucune réclamation en cours ou passée.',
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
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppConstants.spacingUnitLg),
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
    Color statusBgColor;
    Color statusTextColor;

    switch (ticket.status.toUpperCase()) {
      case 'OPEN':
        statusBgColor = AppColors.orangeLightBg;
        statusTextColor = AppColors.primary;
        break;
      case 'IN_PROGRESS':
        statusBgColor = AppColors.peachContainer;
        statusTextColor = AppColors.primaryDark;
        break;
      case 'RESOLVED':
        statusBgColor = AppColors.refundPillBg;
        statusTextColor = AppColors.greenSuccess;
        break;
      default:
        statusBgColor = AppColors.grayBgLight;
        statusTextColor = AppColors.textSecondary;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _openDetail(ticket),
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.grayBgLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Ref & Status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXs),
                      border: Border.all(
                        color: AppColors.grayBorderDivider,
                        width: AppConstants.strokeWidthBorder,
                      ),
                    ),
                    child: Text(
                      ticket.ref,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slateDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingSm,
                          vertical: AppConstants.spacingXxs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.peachContainer,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusXs),
                        ),
                        child: Text(
                          ticket.categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontXs,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                    ),
                    child: Text(
                      ticket.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontXs,
                        fontWeight: FontWeight.w700,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),

              // Description
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontBase,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slateDark,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),

              // Footer row: Ride ref & date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ticket.rideRef != null && ticket.rideRef!.isNotEmpty)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_car_rounded,
                            size: AppConstants.iconSizeSm,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppConstants.spacingXs),
                          Expanded(
                            child: Text(
                              'Course ${ticket.rideRef}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: AppConstants.fontSm,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: AppConstants.spacingSm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ticket.formattedDate,
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: AppConstants.iconSizeSm,
                        color: AppColors.textSecondary,
                      ),
                    ],
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
