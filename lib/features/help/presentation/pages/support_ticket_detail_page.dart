import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/data/models/support_ticket_message_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';

/// Modal bottom sheet or full-page view for support ticket details & live chat thread.
/// Implements the light-mode design matching user requirements:
/// - Drag handle (when modal sheet)
/// - Top header with #TK-XXXX pill, category pill and circular close button
/// - Ticket title / description
/// - 3-step progress bar (ENREGISTRÉ, EXAMEN EN COURS, RÉSOLU)
/// - Course card with ride ref, route and green price badge
/// - Chat thread with orange bubbles for user and support agent cards with 'S' avatar
/// - Bottom reply input bar fixed above the keyboard
class SupportTicketDetailPage extends StatefulWidget {
  final SupportTicketModel ticket;
  final HelpRepository? helpRepository;
  final bool isBottomSheet;

  const SupportTicketDetailPage({
    super.key,
    required this.ticket,
    this.helpRepository,
    this.isBottomSheet = false,
  });

  @override
  State<SupportTicketDetailPage> createState() =>
      _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends State<SupportTicketDetailPage> {
  late final HelpRepository _repository =
      widget.helpRepository ?? HelpRepository();

  late SupportTicketModel _ticket = widget.ticket;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _replyFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSending = false;
  List<SupportTicketMessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadTicketData();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTicketData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTicket = await _repository.getTicketDetails(widget.ticket.id);
      final messages = await _repository.getTicketMessages(widget.ticket.id);

      if (mounted) {
        setState(() {
          if (updatedTicket != null) {
            _ticket = updatedTicket;
          }
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final newMsg = await _repository.replyTicketMessage(
        id: _ticket.id,
        body: text,
      );

      if (!mounted) return;

      if (newMsg != null) {
        _replyController.clear();
        setState(() {
          _messages.add(newMsg);
        });
        _scrollToBottom();
      }

      // If ticket was resolved, reload detail in case status was updated
      if (_ticket.status.toUpperCase() == 'RESOLVED' ||
          _ticket.status.toUpperCase() == 'CLOSED') {
        final refreshed = await _repository.getTicketDetails(_ticket.id);
        if (mounted && refreshed != null) {
          setState(() {
            _ticket = refreshed;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l\'envoi du message.',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          backgroundColor: AppColors.slateDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isBottomSheet) _buildDragHandle(),
        _buildHeaderRow(),
        const SizedBox(height: 12),
        _buildTitle(),
        const SizedBox(height: 16),
        _buildStepProgressBar(),
        const SizedBox(height: 16),
        if (_ticket.rideRef != null && _ticket.rideRef!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCourseCard(),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                )
              : _buildMessagesList(),
        ),
        _buildBottomReplyBar(),
      ],
    );

    if (widget.isBottomSheet) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: content,
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // If not in bottom sheet, provide a back arrow button
          if (!widget.isBottomSheet) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.grayBorderDivider,
                    width: AppConstants.strokeWidthBorder,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.slateDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Ticket Ref pill (e.g. #TK-1024)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Text(
              _ticket.ref.startsWith('#') ? _ticket.ref : '#${_ticket.ref}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.slateDark,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Category pill (e.g. OBJET PERDU / REMBOURSEMENT)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFFEDD5),
                  width: 1,
                ),
              ),
              child: Text(
                _ticket.categoryLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Close button on right (circular grey ✕)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.slateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        _ticket.description,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.slateDark,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildStepProgressBar() {
    final statusUpper = _ticket.status.toUpperCase();
    final isResolved = statusUpper == 'RESOLVED' || statusUpper == 'CLOSED';
    final isInProgress = statusUpper == 'IN_PROGRESS';

    double progressFraction;
    if (isResolved) {
      progressFraction = 1.0;
    } else if (isInProgress) {
      progressFraction = 0.66;
    } else {
      progressFraction = 0.40;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Step 1: ENREGISTRÉ
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'ENREGISTRÉ',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Step 2: EXAMEN EN COURS
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isInProgress || isResolved)
                            ? AppColors.primary
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'EXAMEN EN COURS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: (isInProgress || isResolved)
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Step 3: RÉSOLU
              Text(
                'RÉSOLU',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isResolved
                      ? AppColors.greenSuccess
                      : const Color(0xFF94A3B8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Underline progress bar
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 3.5,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 3.5,
                    width: totalWidth * progressFraction,
                    decoration: BoxDecoration(
                      color: isResolved
                          ? AppColors.greenSuccess
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard() {
    final rideRefText = _ticket.rideRef ?? 'SD-1270';
    final subtitle = _ticket.ridePickup != null
        ? '${_ticket.ridePickup} • ${_ticket.formattedDateShort}'
        : 'Péage VDN / Mermoz • ${_ticket.formattedDateShort}';
    final priceText = _ticket.formattedRidePrice.isNotEmpty
        ? _ticket.formattedRidePrice
        : '3 000 F';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course $rideRefText',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            priceText,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.greenSuccess,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final List<Widget> items = [];

    // Initial claim message bubble (shown from client)
    items.add(_buildUserMessageBubble(
      body: _ticket.description,
      timeLabel: 'Client • ${_ticket.formattedDateShort}',
    ));

    // Message thread replies
    for (final msg in _messages) {
      if (msg.isUser) {
        items.add(_buildUserMessageBubble(
          body: msg.body,
          timeLabel: 'Client • ${msg.formattedTime}',
        ));
      } else {
        items.add(_buildSupportMessageBubble(msg));
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: items,
    );
  }

  Widget _buildUserMessageBubble({
    required String body,
    required String timeLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              body,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.white,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportMessageBubble(SupportTicketMessageModel message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular avatar with 'S'
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.slateDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Grey bubble with agent header and message
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Équipe Support Seddo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slateDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Actif',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.body,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slateDark,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              'Support · ${message.formattedTime}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomReplyBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: AppConstants.strokeWidthBorder,
                ),
              ),
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Répondre à l\'agent...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slateDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppColors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
