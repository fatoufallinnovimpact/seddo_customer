import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Result object containing details of where the receipt was saved.
class ReceiptSaveResult {
  final bool success;
  final String fileName;
  final String primaryPath;
  final List<String> allSavedPaths;
  final String? errorMessage;

  const ReceiptSaveResult({
    required this.success,
    required this.fileName,
    required this.primaryPath,
    this.allSavedPaths = const [],
    this.errorMessage,
  });
}

/// Service responsible for generating and saving high-fidelity PDF receipts
/// matching the exact visual design of the Seddo receipt modal:
/// - Header with Seddo branding, date/time and green "Payé" badge
/// - Bold price and ride category
/// - Route card with distinct departure/arrival pins, dotted route line, and trip stats
/// - Driver information with initials avatar and license plate badge
/// - Orange Money payment details and reference code
/// - Scannable QR code verification footer
class ReceiptPdfService {
  // Brand color palette for PDF generation (aligned with AppColors)
  static const PdfColor _pdfPrimary = PdfColor.fromInt(0xFFFB5B00);
  static const PdfColor _pdfSlateDark = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _pdfTextSecondary = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _pdfCardBg = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor _pdfBorder = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _pdfBorderMedium = PdfColor.fromInt(0xFFD1D5DB);
  static const PdfColor _pdfPaidBg = PdfColor.fromInt(0xFFD1FAE5);
  static const PdfColor _pdfPaidText = PdfColor.fromInt(0xFF059669);
  static const PdfColor _pdfDeparturePin = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _pdfArrivalPin = PdfColor.fromInt(0xFFFB5B00);
  static const PdfColor _pdfPlateBg = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _pdfAvatarBg = PdfColor.fromInt(0xFFE2DBD3);
  static const PdfColor _pdfWhite = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _pdfBlack = PdfColor.fromInt(0xFF000000);
  static const PdfColor _pdfOrangeMoney = PdfColor.fromInt(0xFFFF6600);

  static String _cleanForPdf(String text) {
    return text
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('★', '*')
        .replaceAll('•', '.')
        .replaceAll('·', '-');
  }

  /// Generates the raw PDF bytes of the receipt
  static Future<Uint8List> generateReceiptPdfBytes({
    required String departureName,
    required String arrivalName,
    required String departureTime,
    required String arrivalTime,
    required String distanceText,
    required String durationText,
    required String dateText,
    required String priceText,
    required String rideType,
    required String driverName,
    required String driverCar,
    required String driverPlate,
    required String driverRating,
    required String paymentPhone,
    required String orangeRef,
  }) async {
    final pdf = pw.Document();

    final cleanDepName = _cleanForPdf(departureName);
    final cleanArrName = _cleanForPdf(arrivalName);
    final cleanDate = _cleanForPdf('$dateText - $departureTime a $arrivalTime');
    final cleanStats = _cleanForPdf('$distanceText - $durationText');
    final cleanPrice = _cleanForPdf(priceText);
    final cleanRideType = _cleanForPdf('$rideType - prix fixe');
    final cleanDriverName = _cleanForPdf(driverName);
    final cleanDriverCar = _cleanForPdf('$driverCar - Note: $driverRating/5');
    final cleanDriverPlate = _cleanForPdf(driverPlate);
    final cleanPayment = _cleanForPdf('Orange Money $paymentPhone');
    final cleanRef = _cleanForPdf(orangeRef);

    final initials = driverName.trim().isNotEmpty
        ? (driverName.trim().length >= 2
            ? driverName.trim().substring(0, 2).toUpperCase()
            : driverName.trim().toUpperCase())
        : 'MS';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Brand Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SEDDO',
                        style: pw.TextStyle(
                          color: _pdfPrimary,
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Recu officiel de course',
                        style: const pw.TextStyle(
                          color: _pdfTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _pdfPaidBg,
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 8,
                          height: 8,
                          decoration: const pw.BoxDecoration(
                            color: _pdfPaidText,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          'Paye',
                          style: pw.TextStyle(
                            color: _pdfPaidText,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),
              pw.Divider(color: _pdfBorder, thickness: 1),
              pw.SizedBox(height: 14),

              // 2. Date and Time Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    cleanDate,
                    style: const pw.TextStyle(
                      color: _pdfTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  pw.Text(
                    'Prix fixe garanti',
                    style: const pw.TextStyle(
                      color: _pdfTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // 3. Amount Section
              pw.Text(
                cleanPrice,
                style: pw.TextStyle(
                  fontSize: 34,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfSlateDark,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                cleanRideType,
                style: const pw.TextStyle(
                  fontSize: 13,
                  color: _pdfTextSecondary,
                ),
              ),

              pw.SizedBox(height: 18),

              // 4. Main Route & Details Card
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: _pdfCardBg,
                  borderRadius: pw.BorderRadius.circular(14),
                  border: pw.Border.all(color: _pdfBorder, width: 1.2),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Departure Point
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 14,
                          height: 14,
                          decoration: const pw.BoxDecoration(
                            color: _pdfDeparturePin,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            cleanDepName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: _pdfSlateDark,
                            ),
                          ),
                        ),
                        pw.Text(
                          departureTime,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: _pdfTextSecondary,
                          ),
                        ),
                      ],
                    ),

                    // Route connection & distance/time
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 6, top: 4, bottom: 4),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 2,
                            height: 20,
                            color: _pdfBorderMedium,
                          ),
                          pw.SizedBox(width: 16),
                          pw.Text(
                            cleanStats,
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: _pdfTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrival Point (Different color: Orange Seddo)
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 14,
                          height: 14,
                          decoration: const pw.BoxDecoration(
                            color: _pdfArrivalPin,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            cleanArrName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: _pdfSlateDark,
                            ),
                          ),
                        ),
                        pw.Text(
                          arrivalTime,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: _pdfTextSecondary,
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 14),
                    pw.Divider(color: _pdfBorder, thickness: 1),
                    pw.SizedBox(height: 14),

                    // Driver Row
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 38,
                          height: 38,
                          decoration: const pw.BoxDecoration(
                            color: _pdfAvatarBg,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              initials,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: _pdfSlateDark,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                cleanDriverName,
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _pdfSlateDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                cleanDriverCar,
                                style: const pw.TextStyle(
                                  fontSize: 11,
                                  color: _pdfTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: pw.BoxDecoration(
                            color: _pdfPlateBg,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            cleanDriverPlate,
                            style: pw.TextStyle(
                              color: _pdfWhite,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 14),
                    pw.Divider(color: _pdfBorder, thickness: 1),
                    pw.SizedBox(height: 12),

                    // Payment Row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Paiement',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: _pdfTextSecondary,
                          ),
                        ),
                        pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: pw.BoxDecoration(
                                color: _pdfBlack,
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                'OM',
                                style: pw.TextStyle(
                                  color: _pdfOrangeMoney,
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              cleanPayment,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _pdfSlateDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 12),
                    pw.Divider(color: _pdfBorder, thickness: 1),
                    pw.SizedBox(height: 12),

                    // Reference Row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Ref. Orange',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: _pdfTextSecondary,
                          ),
                        ),
                        pw.Text(
                          cleanRef,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfSlateDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // 5. Verification QR Code & Footer
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: _pdfCardBg,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: _pdfBorder, width: 1),
                ),
                child: pw.Row(
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://seddo.sn/verify/$cleanRef',
                      width: 48,
                      height: 48,
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Ce recu est une preuve officielle de transport delivree par Seddo.',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _pdfSlateDark,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Support : support@seddo.sn - Dakar, Senegal - Ref : $cleanRef',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: _pdfTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Merci pour votre confiance ! A tres bientot sur Seddo.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: _pdfTextSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Saves the PDF receipt directly to the user's physical phone storage
  /// (Downloads and Documents folders on Android, App Documents folder on iOS)
  /// so that when the user opens "Documents" or "Downloads" in their phone,
  /// the file is immediately available.
  static Future<ReceiptSaveResult> saveReceiptToDevice({
    required String departureName,
    required String arrivalName,
    required String departureTime,
    required String arrivalTime,
    required String distanceText,
    required String durationText,
    required String dateText,
    required String priceText,
    required String rideType,
    required String driverName,
    required String driverCar,
    required String driverPlate,
    required String driverRating,
    required String paymentPhone,
    required String orangeRef,
  }) async {
    try {
      final bytes = await generateReceiptPdfBytes(
        departureName: departureName,
        arrivalName: arrivalName,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        distanceText: distanceText,
        durationText: durationText,
        dateText: dateText,
        priceText: priceText,
        rideType: rideType,
        driverName: driverName,
        driverCar: driverCar,
        driverPlate: driverPlate,
        driverRating: driverRating,
        paymentPhone: paymentPhone,
        orangeRef: orangeRef,
      );

      final safeRef = orangeRef.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'Recu_Seddo_$safeRef.pdf';

      final List<String> savedPaths = [];
      String primaryPath = '';

      // 1. Android Public Downloads & Documents folders
      if (Platform.isAndroid) {
        final candidateDirs = [
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/Documents'),
          Directory('/sdcard/Download'),
          Directory('/sdcard/Documents'),
        ];

        for (final dir in candidateDirs) {
          try {
            if (dir.existsSync()) {
              final file = File('${dir.path}/$fileName');
              await file.writeAsBytes(bytes, flush: true);
              savedPaths.add(file.path);
              if (primaryPath.isEmpty) {
                primaryPath = file.path;
              }
            }
          } catch (_) {
            // Handled gracefully, will continue to other directories
          }
        }
      }

      // 2. Platform Downloads Directory via path_provider
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$fileName');
          await file.writeAsBytes(bytes, flush: true);
          if (!savedPaths.contains(file.path)) {
            savedPaths.add(file.path);
          }
          if (primaryPath.isEmpty) {
            primaryPath = file.path;
          }
        }
      } catch (_) {}

      // 3. Platform Documents Directory via path_provider
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        if (!savedPaths.contains(file.path)) {
          savedPaths.add(file.path);
        }
        if (primaryPath.isEmpty) {
          primaryPath = file.path;
        }
      } catch (_) {}

      // 4. External Storage Directory on Android
      if (Platform.isAndroid) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final file = File('${extDir.path}/$fileName');
            await file.writeAsBytes(bytes, flush: true);
            if (!savedPaths.contains(file.path)) {
              savedPaths.add(file.path);
            }
            if (primaryPath.isEmpty) {
              primaryPath = file.path;
            }
          }
        } catch (_) {}
      }

      if (savedPaths.isNotEmpty) {
        return ReceiptSaveResult(
          success: true,
          fileName: fileName,
          primaryPath: primaryPath,
          allSavedPaths: savedPaths,
        );
      } else {
        return ReceiptSaveResult(
          success: false,
          fileName: fileName,
          primaryPath: '',
          errorMessage: 'Impossible d\'écrire dans le stockage de l\'appareil.',
        );
      }
    } catch (e) {
      return ReceiptSaveResult(
        success: false,
        fileName: 'Recu_Seddo.pdf',
        primaryPath: '',
        errorMessage: e.toString(),
      );
    }
  }
}
