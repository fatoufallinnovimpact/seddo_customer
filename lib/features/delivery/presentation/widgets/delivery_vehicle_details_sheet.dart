import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_info_modal.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';

/// Panneau de détails du véhicule de livraison (Express Moto ou Express Cargo)
/// Conforme aux maquettes et demandes :
/// - Monte jusqu'en haut de l'écran en plein écran avec Safe Area adaptée pour que
///   la flèche retour et la localisation soient parfaitement visibles sur TOUT téléphone (encoche, Dynamic Island, etc.)
/// - Image en haut : assets/images/express.png pour la moto et assets/images/cargo.png pour le cargo
/// - Défilement / glissement du haut vers le bas : toute la page bouge ENSEMBLE de haut en bas (swipe down to dismiss)
class DeliveryVehicleDetailsSheet extends StatefulWidget {
  final String pickupAddress;
  final String initialDeliveryType; // 'moto' ou 'cargo'
  final int motoPrice;
  final int cargoPrice;
  final VoidCallback onOpenOrderForm;

  const DeliveryVehicleDetailsSheet({
    super.key,
    required this.pickupAddress,
    required this.initialDeliveryType,
    this.motoPrice = 500,
    this.cargoPrice = 2600,
    required this.onOpenOrderForm,
  });

  static Future<String?> show(
    BuildContext context, {
    required String pickupAddress,
    required String initialDeliveryType,
    int motoPrice = 500,
    int cargoPrice = 2600,
    required VoidCallback onOpenOrderForm,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryVehicleDetailsSheet(
        pickupAddress: pickupAddress,
        initialDeliveryType: initialDeliveryType,
        motoPrice: motoPrice,
        cargoPrice: cargoPrice,
        onOpenOrderForm: onOpenOrderForm,
      ),
    );
  }

  @override
  State<DeliveryVehicleDetailsSheet> createState() =>
      _DeliveryVehicleDetailsSheetState();
}

class _DeliveryVehicleDetailsSheetState
    extends State<DeliveryVehicleDetailsSheet>
    with SingleTickerProviderStateMixin {
  late String _selectedType;

  // Gestion du glissement vertical de toute la page ensemble (Swipe down to dismiss)
  double _dragOffsetY = 0.0;
  late AnimationController _springBackController;
  Animation<double>? _springBackAnimation;
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialDeliveryType;

    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _springBackController.addListener(() {
      setState(() {
        _dragOffsetY = _springBackAnimation?.value ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _springBackController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  void _selectVehicle(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _closeSheet() {
    Navigator.of(context).pop(_selectedType);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    if (delta > 0) {
      setState(() {
        _dragOffsetY += delta;
      });
    } else if (delta < 0 && _dragOffsetY > 0) {
      setState(() {
        _dragOffsetY = math.max(0.0, _dragOffsetY + delta);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetY > 110 || velocity > 350) {
      _closeSheet();
    } else if (_dragOffsetY > 0) {
      _springBackAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _springBackController,
          curve: Curves.easeOutCubic,
        ),
      );
      _springBackController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMoto = _selectedType == 'moto';
    final mediaQuery = MediaQuery.of(context);

    // Calcul de la zone sécurisée en haut : s'adapte à tout téléphone (notch, Dynamic Island, perforation)
    final safeTop = math.max(
      mediaQuery.padding.top,
      mediaQuery.viewPadding.top,
    );
    final topBarPadding = safeTop > 0 ? safeTop + 8 : 16.0;
    final bottomPadding = mediaQuery.padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_selectedType);
        }
      },
      child: Transform.translate(
        // Déplace toute la page ensemble vers le bas lors du glissement du doigt
        offset: Offset(0, _dragOffsetY),
        child: GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Container(
            height: mediaQuery.size.height,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // 1. Barre supérieure : Bouton retour, Adresse de prise en charge, Icône Info
                // Parfaitement dégagée et visible sur n'importe quel smartphone
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topBarPadding, 16, 8),
                  child: Row(
                    children: [
                      // Flèche retour circulaire
                      Material(
                        color: const Color(0xFFF1F5F9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _closeSheet,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.arrow_back,
                              color: Color(0xFF1E293B),
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      // Titre centré (Adresse de prise en charge)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            widget.pickupAddress,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      // Bouton Info
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF64748B),
                            size: 22,
                          ),
                          onPressed: () {
                            DeliveryInfoModal.show(
                              context,
                              deliveryType: _selectedType,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Contenu scrollable (Illustration, Titres, Cartes, À savoir)
                // Écoute également le scroll pour que tirer en haut entraîne toute la page
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        if (_contentScrollController.hasClients &&
                            _contentScrollController.offset <= 0 &&
                            (notification.scrollDelta ?? 0) < 0) {
                          setState(() {
                            _dragOffsetY += -(notification.scrollDelta ?? 0);
                          });
                          return true;
                        } else if (_dragOffsetY > 0 &&
                            (notification.scrollDelta ?? 0) > 0) {
                          setState(() {
                            _dragOffsetY = math.max(
                              0.0,
                              _dragOffsetY - (notification.scrollDelta ?? 0),
                            );
                          });
                          return true;
                        }
                      } else if (notification is OverscrollNotification) {
                        if (notification.overscroll < 0) {
                          setState(() {
                            _dragOffsetY += -notification.overscroll;
                          });
                          return true;
                        }
                      } else if (notification is ScrollEndNotification) {
                        if (_dragOffsetY > 0) {
                          _onVerticalDragEnd(
                            DragEndDetails(primaryVelocity: 0.0),
                          );
                        }
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _contentScrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Illustration Hero (express.png pour moto, cargo.png pour cargo)
                          Center(
                            child: SizedBox(
                              height: 165,
                              child: Image.asset(
                                isMoto
                                    ? 'assets/images/express.png'
                                    : 'assets/images/cargo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Grand titre "Livraison"
                          Text(
                            'Livraison',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Sous-titre
                          Text(
                            isMoto
                                ? 'Pour les petits colis et documents'
                                : 'Transportez de gros volumes',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Ligne de prix et estimation : "à partir de X F · Y min. >"
                          InkWell(
                            onTap: () {},
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'à partir de ',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              '${isMoto ? widget.motoPrice : widget.cargoPrice} F',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' · ${isMoto ? "13 min." : "5 min."} ',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Color(0xFF0F172A),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Cartes de sélection de véhicule (Sans contours / no border)
                          Row(
                            children: [
                              // Carte Express Moto
                              Expanded(
                                child: _buildVehicleCard(
                                  title: 'Express Moto',
                                  timeBadge: '13 min.',
                                  price: 'à partir de ${widget.motoPrice} F',
                                  imagePath: 'assets/images/livraison.png',
                                  isSelected: isMoto,
                                  onTap: () => _selectVehicle('moto'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Carte Express Cargo (Image cargo.png agrandie)
                              Expanded(
                                child: _buildVehicleCard(
                                  title: 'Express Cargo',
                                  timeBadge: '5 min.',
                                  price: 'à partir de ${widget.cargoPrice} F',
                                  imagePath: 'assets/images/cargo.png',
                                  isSelected: !isMoto,
                                  onTap: () => _selectVehicle('cargo'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Section "À savoir"
                          Text(
                            'À savoir',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Boîte À savoir avec les 3 étapes numérotées
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                // Étape 1
                                _buildStepRow(
                                  stepNumber: '1',
                                  title:
                                      'Appuyez sur « Ouvrir le formulaire de commande »',
                                  subtitle:
                                      'Bouton situé en bas de cet écran',
                                ),

                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    thickness: 0.8,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),

                                // Étape 2 (Dynamique selon Moto ou Cargo)
                                _buildStepRow(
                                  stepNumber: '2',
                                  title: 'Sélectionnez les options requises',
                                  subtitle: isMoto
                                      ? 'Jusqu\'à la porte, jusqu\'au porche, ou dans l\'intervalle de temps'
                                      : 'Volume, déménageurs, itinéraire et vitesse de prise en charge',
                                ),

                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    thickness: 0.8,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),

                                // Étape 3
                                _buildStepRow(
                                  stepNumber: '3',
                                  title: 'Sélectionnez le mode paiement',
                                  subtitle:
                                      'Tout est prêt, passez votre commande',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Barre d'action inférieure fixe
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 12),
                  child: Row(
                    children: [
                      // Mode de paiement à gauche (SANS contours)
                      ValueListenableBuilder<String>(
                        valueListenable:
                            PaymentMethodsService().selectedCodeNotifier,
                        builder: (context, code, _) {
                          final assetPath =
                              PaymentMethodsService.getAssetForCode(code);
                          final isCash =
                              code.toUpperCase().trim() == 'CASH';

                          return Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () =>
                                  PaymentMethodModal.show(context),
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 48,
                                height: 52,
                                child: Center(
                                  child: isCash
                                      ? Image.asset(
                                          assetPath,
                                          width: 40,
                                          height: 28,
                                          fit: BoxFit.contain,
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.asset(
                                            assetPath,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 8),

                      // Bouton central "Accéder au formulaire de commande"
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(_selectedType);
                              widget.onOpenOrderForm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Accéder au formulaire\nde commande',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Flèche vers le bas à droite (ferme et descend le modal) - SANS card
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _closeSheet,
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            width: 44,
                            height: 52,
                            child: Center(
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1E293B),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Carte de sélection sans contour (border: null) avec image bien dimensionnée
  Widget _buildVehicleCard({
    required String title,
    required String timeBadge,
    required String price,
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isCargo = imagePath.contains('cargo');

    return Material(
      color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge temps + Image véhicule
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      timeBadge,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Image.asset(
                    imagePath,
                    width: isCargo ? 68 : 52,
                    height: isCargo ? 40 : 36,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Étape avec puce noire numérotée pour "À savoir"
  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cercle noir avec numéro blanc
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
