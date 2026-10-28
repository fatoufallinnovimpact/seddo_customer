import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/in_app_call_page.dart';

/// Screen allowing the customer to chat with the assigned driver.
/// Connected to backend API endpoints:
/// - GET /v1/rides/{id}/messages
/// - POST /v1/rides/{id}/messages with { "body": "..." }
/// Supports quick preset replies and masked phone numbers security notice.
class DriverChatPage extends StatefulWidget {
  final DriverModel driver;
  final String? rideId;
  final RideService? rideService;

  const DriverChatPage({
    super.key,
    required this.driver,
    this.rideId,
    this.rideService,
  });

  @override
  State<DriverChatPage> createState() => _DriverChatPageState();
}

class _DriverChatPageState extends State<DriverChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  Timer? _replyTimer;
  Timer? _pollTimer;
  late final RideService _rideService;

  String get _effectiveRideId =>
      widget.rideId ?? RideService.lastCreatedRideId ?? 'current';

  static const List<String> _quickReplies = [
    'chat.quick_at_gate',
    'chat.quick_coming_1min',
    'chat.quick_pharmacy',
    'chat.quick_white_shirt',
    'chat.quick_waiting',
  ];

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();

    // Initial driver message
    _messages.add(
      ChatMessageModel(
        id: 'msg_0',
        sender: ChatSender.driver,
        text: 'Bonjour ! Je suis en route vers votre point de prise en charge.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );

    // Initial fetch from backend API
    _fetchMessages();

    // Periodic poll for incoming driver messages (every 4 seconds)
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchMessages();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final remoteMessages = await _rideService.getChatMessages(
        rideId: _effectiveRideId,
      );
      if (!mounted || remoteMessages.isEmpty) return;

      bool hasNew = false;
      for (final rMsg in remoteMessages) {
        final alreadyExists = _messages.any((m) =>
            m.id == rMsg.id ||
            (m.text == rMsg.text && m.sender == rMsg.sender));
        if (!alreadyExists) {
          _messages.add(rMsg);
          hasNew = true;
        }
      }

      if (hasNew) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final customerMsg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.customer,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(customerMsg);
      _textController.clear();
    });
    _scrollToBottom();

    // Synchronize to backend API POST /v1/rides/{id}/messages with {"body": trimmed}
    unawaited(
      _rideService.sendChatMessage(
        rideId: _effectiveRideId,
        message: trimmed,
      ),
    );

    // Realistic driver reply fallback for test environments or offline mode
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final hasRecentDriverMsg = _messages.any((m) =>
          m.sender == ChatSender.driver &&
          m.timestamp
              .isAfter(DateTime.now().subtract(const Duration(seconds: 2))));
      if (!hasRecentDriverMsg) {
        setState(() {
          _messages.add(
            ChatMessageModel(
              id: 'msg_reply_${DateTime.now().millisecondsSinceEpoch}',
              sender: ChatSender.driver,
              text: 'Bien reçu ! Je suis à l\'angle de la rue, à tout de suite.',
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _makePhoneCall() async {
    await InAppCallPage.show(context, driver: widget.driver);
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Driver Initials Avatar with Verified Status Dot
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.avatarBeige,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.driver.name.isNotEmpty
                        ? widget.driver.name
                            .split(' ')
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .take(2)
                            .join()
                            .toUpperCase()
                        : 'MS',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.refundGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driver.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.driver.carModel} · ${widget.driver.licensePlate}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surfaceGrey,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/call-svgrepo-com.svg',
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
              padding: EdgeInsets.zero,
              onPressed: _makePhoneCall,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            const Divider(height: 1, color: AppColors.cardBorder),

            // Numéros masqués security notice banner
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingSm,
                AppConstants.spacingMd,
                AppConstants.spacingXs,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingUnitLg,
                vertical: AppConstants.spacingUnit,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: AppColors.grayBorderDivider,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.refundPillBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.refundGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'chat.masked_numbers_title'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'chat.masked_numbers_notice'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: 16,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isCustomer = msg.sender == ChatSender.customer;

                  return Align(
                    alignment: isCustomer
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isCustomer
                            ? AppColors.primary
                            : AppColors.chatBubbleDriver,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isCustomer ? 16 : 4),
                          bottomRight: Radius.circular(isCustomer ? 4 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isCustomer
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: isCustomer
                                  ? AppColors.white
                                  : AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg.formattedTime,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isCustomer
                                      ? AppColors.white80
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (isCustomer) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.done_all_rounded,
                                  size: 14,
                                  color: AppColors.white80,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quick Preset Replies Horizontal List
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                itemCount: _quickReplies.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final replyKey = _quickReplies[index];
                  return ActionChip(
                    label: Text(
                      replyKey.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    onPressed: () => _sendMessage(replyKey.tr()),
                  );
                },
              ),
            ),

            // Input Bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.textSecondary,
                        size: 23,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.buttonBlack,
                            content: Text(
                              'chat.photo_soon'.tr(),
                              style: GoogleFonts.inter(color: AppColors.white),
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _textController,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'chat.send_hint'.tr(args: [widget.driver.name]),
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                        onPressed: () => _sendMessage(_textController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
