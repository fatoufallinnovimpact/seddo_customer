// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'WalkingDurationWidget.dart';
import '../../data/models/transit/TransitResponseModel.dart';

class TimelinePoint extends StatelessWidget {
  final String label;
  final bool isStart;
  final bool isFirstTrajet;
  final bool isEnd;
  final bool isWalking;
  final double lat;
  final double lon;
  final bool? isDestination;
  final TransitFullResponseModel? transit;

  const TimelinePoint({
    super.key,
    required this.label,
    this.isStart = false,
    this.isEnd = false,
    this.isWalking = false,
    this.isFirstTrajet = false,
    this.isDestination,
    required this.transit,
    required this.lat,
    required this.lon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isStart)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 2,
                    height: 55,
                    margin: EdgeInsets.only(left: 10),
                    child: CustomPaint(
                      painter: isWalking ? _DashPainter() : null,
                    ),
                  ),
                  if (isWalking && !isEnd)
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Row(
                        children: [
                          Icon(Icons.directions_walk, color: Colors.grey),
                          SizedBox(width: 4),
                          WalkingDurationWidget(
                            startLat: transit!.mainTripInfo!.stopEnd!.stopLat,
                            startLon: transit!.mainTripInfo!.stopEnd!.stopLon,
                            endLat: lat,
                            endLon: lon,
                          ),
                        ],
                      ),
                    ),
                ],
              ),

            SizedBox(
              width: MediaQuery.of(context).size.width - 50,
              child: Row(
                children: [
                  if (isDestination == null || !isDestination!)
                    Icon(
                      isStart
                          ? Icons.trip_origin_sharp
                          : (isEnd
                              ? Icons.location_on
                              : Icons.trip_origin_sharp),
                      color:
                          isStart
                              ? Color(0xFFE65100)
                              : (isEnd ? Colors.red : Colors.grey),
                      size: 20,
                    ),
                  SizedBox(width: 8),
                  if (isDestination == null || !isDestination!)
                    Expanded(
                      child: SizedBox(
                        height: 20,
                        child: Text(
                          overflow: TextOverflow.ellipsis,
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (!isEnd)
              Row(
                children: [
                  Container(
                    width: 2,
                    height: 55,
                    margin: EdgeInsets.only(left: 10),
                    child: CustomPaint(
                      painter: isWalking ? _DashPainter() : null,
                    ),
                  ),
                  if (isWalking)
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Row(
                        children: [
                          Icon(Icons.directions_walk, color: Colors.grey),
                          SizedBox(width: 4),
                          WalkingDurationWidget(
                            startLat: lat,
                            startLon: lon,
                            endLat: transit!.mainTripInfo!.stopStart!.stopLat,
                            endLon: transit!.mainTripInfo!.stopStart!.stopLon,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final Color color;

  _DashPainter({
    this.dashWidth = 5,
    this.dashSpace = 3,
    this.color = Colors.grey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startY = 0;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
