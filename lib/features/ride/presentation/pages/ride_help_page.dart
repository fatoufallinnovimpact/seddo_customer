import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';

/// Issue item model for the help page.
class HelpIssueOption {
  final String title;
  final String? svgAsset;
  final IconData? iconData;

  const HelpIssueOption({
    required this.title,
    this.svgAsset,
    this.iconData,
  });
}

/// Screen displaying the ride support & help request matching design:
/// - Top bar: Circular back button and "Aide sur cette course" title
/// - Summary card with destination pin, date/status, and price
/// - 4 selectable issue cards with specific SVGs requested by user:
///   1. "J'ai oublié un objet"
///   2. "Le trajet ne s'est pas bien passé" (route-svgrepo-com.svg)
///   3. "Montant ou paiement" (wallet-svgrepo-com.svg)
///   4. "Remboursement non reçu" (refresh-left-svgrepo-com.svg)
/// - "Dites-nous ce qui s'est passé" with multiline text field and counter
/// - Quick selection tags ("Détour inutile", "Conduite dangereuse", "Chauffeur impoli")
/// - Primary orange button "Envoyer au support"
class RideHelpPage extends StatefulWidget {
  final PlaceSearchResult? destination;
  final String priceText;
  final String dateText;

  const RideHelpPage({
    super.key,
    this.destination,
    this.priceText = '3 500 F',
    this.dateText = '15 avr. · Course terminée',
  });

  @override
  State<RideHelpPage> createState() => _RideHelpPageState();
}

class _RideHelpPageState extends State<RideHelpPage> {
  int _selectedIssueIndex = 1; // Default to "Le trajet ne s'est pas bien passé"
  final TextEditingController _notesController = TextEditingController(
    text: 'Le chauffeur a pris un détour par la Corniche...',
  );

  static const List<HelpIssueOption> _issueOptions = [
    HelpIssueOption(
      title: "J'ai oublié un objet",
      iconData: Icons.search_rounded,
      svgAsset: 'assets/icons/search-magnifying-glass-svgrepo-com.svg',
    ),
    HelpIssueOption(
      title: "Le trajet ne s'est pas bien passé",
      svgAsset: 'assets/icons/route-svgrepo-com.svg',
    ),
    HelpIssueOption(
      title: 'Montant ou paiement',
      svgAsset: 'assets/icons/wallet-svgrepo-com.svg',
    ),
    HelpIssueOption(
      title: 'Remboursement non reçu',
      svgAsset: 'assets/icons/refresh-left-svgrepo-com.svg',
    ),
  ];

  static const List<String> _quickTags = [
    'Détour inutile',
    'Conduite dangereuse',
    'Chauffeur impoli',
  ];

  final FocusNode _notesFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _notesController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _onTagPressed(String tag) {
    FocusScope.of(context).unfocus();
    setState(() {
      final current = _notesController.text.trim();
      if (current.isEmpty) {
        _notesController.text = tag;
      } else if (!current.contains(tag)) {
        _notesController.text = '$current, $tag';
      }
    });
  }

  void _submitSupportRequest() {
    final selectedIssue = _issueOptions[_selectedIssueIndex].title;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Votre demande ($selectedIssue) a été transmise au support Seddo.',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.slateDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinationTitle = widget.destination?.mainText ?? 'Almadies';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              _buildTopAppBar(),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppConstants.spacingSm),

                    // Trip Summary Header Card
                    _buildTripSummaryCard(destinationTitle),

                    const SizedBox(height: AppConstants.spacingLg),

                    // Section 1: "Quel est le problème ?"
                    Text(
                      'Quel est le problème ?',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontLg,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingUnitLg),

                    // Issue list
                    ...List.generate(
                      _issueOptions.length,
                      (index) => _buildIssueOptionCard(index),
                    ),

                    const SizedBox(height: AppConstants.spacingLg),

                    // Section 2: "Dites-nous ce qui s'est passé"
                    Text(
                      'Dites-nous ce qui s\'est passé',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingUnit),

                    // Multiline Text Box
                    _buildNotesInput(),

                    const SizedBox(height: AppConstants.spacingUnitLg),

                    // Quick Issue Chips
                    _buildQuickChips(),

                    const SizedBox(height: AppConstants.spacingLg),
                  ],
                ),
              ),
            ),

            // Bottom Submit Button
            _buildBottomButton(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTopAppBar() {
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
              'Aide sur cette course',
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

  Widget _buildTripSummaryCard(String destinationTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingUnitLg,
      ),
      decoration: BoxDecoration(
        color: AppColors.grayBgLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: AppConstants.circularAvatarSize,
            height: AppConstants.circularAvatarSize,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: AppConstants.iconSizeLg,
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destinationTitle,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontLg,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  widget.dateText,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.priceText,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontLg,
              fontWeight: FontWeight.w800,
              color: AppColors.slateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueOptionCard(int index) {
    final option = _issueOptions[index];
    final isSelected = _selectedIssueIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingUnitLg),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _selectedIssueIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingUnitLg,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.grayBorderDivider,
              width: isSelected
                  ? AppConstants.strokeWidthSelected
                  : AppConstants.strokeWidthBorder,
            ),
          ),
          child: Row(
            children: [
              // Circular icon container
              Container(
                width: AppConstants.circularAvatarSize,
                height: AppConstants.circularAvatarSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.peachContainer
                      : AppColors.grayBgLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: option.svgAsset != null
                      ? SvgPicture.asset(
                          option.svgAsset!,
                          width: AppConstants.helpOptionIconSize,
                          height: AppConstants.helpOptionIconSize,
                          colorFilter: ColorFilter.mode(
                            isSelected ? AppColors.primary : AppColors.slateDark,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(
                          option.iconData,
                          size: AppConstants.helpOptionIconSize,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.slateDark,
                        ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),
              Expanded(
                child: Text(
                  option.title,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ),
              // Radio indicator
              Container(
                width: AppConstants.iconSizeLg,
                height: AppConstants.iconSizeLg,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.transparent,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: AppColors.grayBorderMedium,
                          width: AppConstants.strokeWidthBorder,
                        ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: AppConstants.spacingUnitXl,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grayBgLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _notesController,
            focusNode: _notesFocusNode,
            maxLines: 4,
            maxLength: AppConstants.helpMaxCharacters,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontBase,
              color: AppColors.slateDark,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Le chauffeur a pris un détour par la Corniche...',
              hintStyle: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: AppConstants.fontBase,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '${_notesController.text.length}/${AppConstants.helpMaxCharacters}',
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontSm,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    return Wrap(
      spacing: AppConstants.spacingSm,
      runSpacing: AppConstants.spacingSm,
      children: _quickTags.map((tag) {
        return GestureDetector(
          onTap: () => _onTagPressed(tag),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              border: Border.all(
                color: AppColors.supportTagBorder,
                width: AppConstants.strokeWidthBorder,
              ),
            ),
            child: Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontSm,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppConstants.buttonHeight,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            elevation: AppConstants.elevationNone,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            ),
          ),
          onPressed: _submitSupportRequest,
          child: Text(
            'Envoyer au support',
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontLg,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}
