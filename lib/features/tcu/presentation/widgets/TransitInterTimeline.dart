import 'package:flutter/material.dart';
import '../../data/models/transit/TransitResponseModel.dart';

const Color transitSecondaryColor = Color(0xFF0D47A1);

class TransitInterTimeline extends StatelessWidget {
  final List<TransitResponseInterModel> items;

  const TransitInterTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final isLast = item == items.last;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne de l'icône + ligne verticale
            Column(
              children: [
                const Icon(
                  Icons.circle,
                  color: transitSecondaryColor,
                  size: 10,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: transitSecondaryColor,
                  ),
              ],
            ),
            const SizedBox(width: 8),

            // Nom de l'arrêt
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.stop?.stopName ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (!isLast) const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
