import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/data/models/support_ticket_message_model.dart';
import 'package:seddo/features/help/data/models/support_ticket_model.dart';
import 'package:seddo/features/help/data/repositories/help_repository.dart';

/// Screen displaying the detail of a support claim / ticket and its message thread.
/// Connects to:
/// - GET /v1/support/tickets/{id} (SupportController_get)
/// - GET /v1/support/tickets/{id}/messages (SupportController_messages)
/// - POST /v1/support/tickets/{id}/messages (SupportController_reply)
class SupportTicketDetailPage extends StatefulWidget {
  final SupportTicketModel ticket;
  final HelpRepository? helpRepository;

  const SupportTicketDetailPage({
    super.key,
    required this.ticket,
    this.helpRepository,
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

      // If ticket was resolved, reload detail because server reopens it
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingMd,
                          vertical: AppConstants.spacingSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ticket info summary card
                            _buildSummaryCard(),

                            const SizedBox(height: AppConstants.spacingLg),

                            // Initial claim section
                            _buildInitialClaimCard(),

                            const SizedBox(height: AppConstants.spacingLg),

                            // Messages thread header
                            Row(
                              children: [
                                const Icon(
                                  Icons.forum_outlined,
                                  size: AppConstants.iconSizeSm,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppConstants.spacingXs),
                                Text(
                                  'MESSAGES AVEC LE SUPPORT',
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontSm,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingSm),

                            // Messages thread list
                            if (_messages.isEmpty)
                              _buildNoMessagesPrompt()
                            else
                              ...List.generate(
                                _messages.length,
                                (index) => _buildMessageBubble(_messages[index]),
                              ),

                            const SizedBox(height: AppConstants.spacingLg),
                          ],
                        ),
                      ),
              ),

              // Bottom reply bar
              _buildBottomReplyBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    Color statusBgColor;
    Color statusTextColor;

    switch (_ticket.status.toUpperCase()) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Réclamation ${_ticket.ref}',
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _ticket.formattedDate,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
              vertical: AppConstants.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: Text(
              _ticket.statusLabel,
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontXs,
                fontWeight: FontWeight.w700,
                color: statusTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.grayBgLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                  vertical: AppConstants.spacingXxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.peachContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                ),
                child: Text(
                  _ticket.categoryLabel,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              if (_ticket.rideRef != null && _ticket.rideRef!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingSm,
                    vertical: AppConstants.spacingXxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                    border: Border.all(
                      color: AppColors.grayBorderDivider,
                      width: AppConstants.strokeWidthBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car_rounded,
                        size: AppConstants.iconSizeSm,
                        color: AppColors.slateDark,
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      Text(
                        'Course ${_ticket.rideRef}',
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_ticket.resolution != null && _ticket.resolution!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.refundPillBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.greenSuccess,
                    size: AppConstants.iconSizeMd,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Text(
                      'Résolution : ${_ticket.resolution}',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greenSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialClaimCard() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(
          color: AppColors.grayBorderDivider,
          width: AppConstants.strokeWidthBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppConstants.spacingLg,
                height: AppConstants.spacingLg,
                decoration: const BoxDecoration(
                  color: AppColors.peachContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: AppConstants.iconSizeSm,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                'Votre signalement initial',
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontSm,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            _ticket.description,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontBase,
              fontWeight: FontWeight.w500,
              color: AppColors.slateDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMessagesPrompt() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.grayBgLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      ),
      child: Center(
        child: Text(
          'Notre équipe support traite votre réclamation. Vous pouvez ajouter un message ou des précisions ci-dessous.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontSm,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(SupportTicketMessageModel msg) {
    final isMe = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: AppConstants.spacingUnitXl,
              height: AppConstants.spacingUnitXl,
              decoration: const BoxDecoration(
                color: AppColors.slateDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: AppConstants.iconSizeSm,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: AppConstants.spacingXs),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.grayBgLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppConstants.radiusCard),
                  topRight: const Radius.circular(AppConstants.radiusCard),
                  bottomLeft: Radius.circular(
                    isMe ? AppConstants.radiusCard : AppConstants.radiusXs,
                  ),
                  bottomRight: Radius.circular(
                    isMe ? AppConstants.radiusXs : AppConstants.radiusCard,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.body,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontBase,
                      fontWeight: FontWeight.w500,
                      color: isMe ? AppColors.white : AppColors.slateDark,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXxs),
                  Text(
                    msg.formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontXs,
                      fontWeight: FontWeight.w400,
                      color: isMe
                          ? AppColors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
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

  Widget _buildBottomReplyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        AppConstants.spacingSm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.grayBorderDivider,
            width: AppConstants.strokeWidthBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              decoration: BoxDecoration(
                color: AppColors.grayBgLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontBase,
                  color: AppColors.slateDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingSm,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: AppConstants.buttonHeight,
              height: AppConstants.buttonHeight,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: AppConstants.iconSizeSm,
                        height: AppConstants.iconSizeSm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppColors.white,
                      size: AppConstants.iconSizeMd,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
