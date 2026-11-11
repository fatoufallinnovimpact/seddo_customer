import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'TransitInterTimeline.dart';
import 'WalkingDurationWidget.dart';
import '../../data/models/transit/Stop.dart';
import '../../data/models/transit/StopTimeResponse.dart';
import '../../data/models/transit/TransitResponseModel.dart';

String formatTimeToHHmm(String? time) {
  if (time == null) return '';
  try {
    return DateFormat('HH:mm').format(DateFormat('HH:mm:ss').parse(time));
  } catch (_) {
    return time;
  }
}

class TimelineTile extends StatefulWidget {
  final TransitFullResponseModel transit;
  final TransitFullResponseModel nexttransit;
  final StopModel? nextStop;
  final String? label;
  final StopTimeResponseModel? stopTimeResponse;
  final bool isLast;
  final Position? currentPosition;
  final double? lat;
  final double? lon;
  final bool destination;

  const TimelineTile({
    super.key,
    required this.transit,
    this.isLast = false,
    required this.nexttransit,
    this.nextStop,
    this.label,
    this.stopTimeResponse,
    this.currentPosition,
    this.lat,
    this.lon,
    required this.destination,
  });

  @override
  State<TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<TimelineTile> {
  bool _showStops = false; // État pour contrôler l'affichage
  String normalizeText(String? input) {
    try {
      return utf8.decode(input!.runes.toList());
    } catch (e) {
      return input!;
    }
  }

  String replaceUnderscores(String text) {
    return text.replaceAll('_', ' ');
  }

  String convertDelayToMinutes(int delayInSeconds) {
    final minutes = delayInSeconds ~/ 60;
    final seconds = delayInSeconds.abs() % 60;

    if (delayInSeconds.isNegative) {
      return minutes.abs() != 0 ? "-${minutes.abs()} min " : "${seconds}s";
    } else {
      return minutes != 0 ? "+$minutes min" : "${seconds}s";
    }
  }

  String getFormattedTravelDuration(String departure, String arrival) {
    // Convertir les heures en DateTime
    final depParts = departure.split(':').map(int.parse).toList();
    final arrParts = arrival.split(':').map(int.parse).toList();

    final now = DateTime.now();
    final depTime = DateTime(
      now.year,
      now.month,
      now.day,
      depParts[0],
      depParts[1],
      depParts[2],
    );
    var arrTime = DateTime(
      now.year,
      now.month,
      now.day,
      arrParts[0],
      arrParts[1],
      arrParts[2],
    );

    // Si l’arrivée est avant le départ → on suppose que c’est le jour suivant
    if (arrTime.isBefore(depTime)) {
      arrTime = arrTime.add(Duration(days: 1));
    }

    final duration = arrTime.difference(depTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
    } else {
      return '$minutes min';
    }
  }

  double computeTimelineHeight(int count) {
    if (count <= 0) return 0.0;

    const double rowHeightWithLine = 56.0;
    const double rowHeightLast = 28.0;

    return (count) * rowHeightWithLine + rowHeightLast;
  }

  @override
  Widget build(BuildContext context) {
    final timelineHeight = computeTimelineHeight(
      widget.transit.intermediateStopsWithTimes.length,
    );

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                widget.nextStop != null
                    ? Image.asset(
                      "assets/transit/arretbus.png",
                      width: 25,
                      height: 25,
                    )
                    : Container(
                      height: 25,
                      width: 25,
                      margin: EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage("assets/transit/arretbus.png"),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                Expanded(
                  child: Text(
                    widget.nextStop != null
                        ? "  ${widget.label!}"
                        : normalizeText(
                          widget.transit.mainTripInfo!.stopStart?.stopName
                              .toString(),
                        ),
                  ),
                ),
              ],
            ),
            Container(
              width: 2,
              margin: EdgeInsets.only(left: 10),
              height:
                  widget.isLast
                      ? (widget.nextStop != null &&
                              widget.stopTimeResponse == null
                          ? 80
                          : _showStops
                          ? timelineHeight
                          : 150)
                      : _showStops
                      ? timelineHeight
                      : 150,
              color: Colors.grey,
            ),
            Row(
              children: [
                SizedBox(
                  height: 120,
                  width: MediaQuery.of(context).size.width - 32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: EdgeInsets.only(left: 10),
                          color: Colors.grey,
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 100,
                          child: Row(
                            children: [
                              widget.nextStop != null
                                  ? widget.stopTimeResponse != null
                                      ? const Icon(
                                        Icons.train_outlined,
                                        color: Colors.grey,
                                      )
                                      : Icon(
                                        Icons.train_outlined,
                                        color: Colors.grey,
                                      )
                                  : Icon(
                                    Icons.trip_origin_sharp,
                                    color: Color(0xFFE65100),
                                  ),
                              SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  width: 200,
                                  child: Text(
                                    widget.isLast && widget.nextStop != null
                                        ? widget.stopTimeResponse != null
                                            ? "Gare de ${widget.nextStop!.stop_name}"
                                            : ""
                                        : normalizeText(
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .stopEnd!
                                              .stopName,
                                        ),
                                    style: TextStyle(
                                      overflow: TextOverflow.visible,
                                    ),
                                    softWrap: true, // Enable text wrapping
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.nextStop == null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: 2,
                              height: 60,
                              margin: EdgeInsets.only(left: 10),
                              child: CustomPaint(painter: DashPainter()),
                            ),
                            if (widget.nextStop == null &&
                                widget.transit.mainTripInfo!.stopEnd!.stopId !=
                                    widget
                                        .nexttransit
                                        .mainTripInfo!
                                        .stopEnd!
                                        .stopId)
                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 4),
                                    WalkingDurationWidget(
                                      startLat:
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .stopEnd!
                                              .stopLat,
                                      startLon:
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .stopEnd!
                                              .stopLon,
                                      endLat:
                                          widget
                                              .nexttransit
                                              .mainTripInfo!
                                              .stopStart!
                                              .stopLat,
                                      endLon:
                                          widget
                                              .nexttransit
                                              .mainTripInfo!
                                              .stopStart!
                                              .stopLon,
                                    ),
                                  ],
                                ),
                              ),

                            if (widget.nextStop == null &&
                                widget.transit.mainTripInfo!.stopEnd!.stopId ==
                                    widget
                                        .nexttransit
                                        .mainTripInfo!
                                        .stopEnd!
                                        .stopId &&
                                !widget.destination)
                              Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 4),
                                    WalkingDurationWidget(
                                      startLat:
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .stopEnd!
                                              .stopLat,
                                      startLon:
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .stopEnd!
                                              .stopLon,
                                      endLat: widget.lat!,
                                      endLon: widget.lon!,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(width: 10),
        Positioned(
          left: 30,
          right: 0,
          top: 40,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            margin: EdgeInsets.only(bottom: 20),
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: .4),
            ),
            child:
                widget.nextStop != null
                    ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              margin: EdgeInsets.only(left: 16),
                              child:
                                  widget.stopTimeResponse == null
                                      ? Image.asset(
                                        "assets/transit/aftu.png",
                                        width: 100,
                                      )
                                      : Image.asset(
                                        "assets/transit/aftu.png",
                                        width: 100,
                                      ),
                            ),

                            Container(
                              margin: EdgeInsets.only(right: 16),
                              child: Text(
                                widget.stopTimeResponse != null
                                    ? widget
                                        .stopTimeResponse!
                                        .trip
                                        .tripShortName
                                    : widget.nextStop!.stop_name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(width: 16),
                            widget.stopTimeResponse != null
                                ? Text(
                                  '${widget.label} -> ${widget.nextStop!.stop_name}',
                                )
                                : Text(
                                  "Laissez vous transporTER",
                                  style: TextStyle(fontSize: 16),
                                ),
                          ],
                        ),

                        SizedBox(height: 10),
                        if (widget.stopTimeResponse != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(width: 16),
                                  Container(
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.only(left: 5, right: 5),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          widget.stopTimeResponse != null
                                              ? '${widget.stopTimeResponse!.duration} min'
                                              : "",
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Container(
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.only(left: 5, right: 5),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.place_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          widget.stopTimeResponse != null
                                              ? '${widget.stopTimeResponse!.distance} km'
                                              : "",
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.stopTimeResponse != null)
                                Container(
                                  margin: EdgeInsets.only(right: 16),
                                  child: const Icon(Icons.directions_outlined),
                                ),
                            ],
                          ),
                      ],
                    )
                    : Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            widget.nextStop != null
                                ? Image.asset(
                                  "assets/transit/aftu.png",
                                  width: 60,
                                )
                                : widget
                                        .transit
                                        .mainTripInfo!
                                        .stop
                                        .transitType ==
                                    "BRT"
                                ? Image.asset(
                                  "assets/transit/brt.png",
                                  width: 90,
                                )
                                : widget
                                        .transit
                                        .mainTripInfo!
                                        .stop
                                        .transitType ==
                                    "DDD"
                                ? Image.asset(
                                  "assets/transit/dddk.png",
                                  width: 60,
                                )
                                : Image.asset(
                                  "assets/transit/aftu.png",
                                  width: 60,
                                ),

                            SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        "Ligne de bus : ",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        replaceUnderscores(
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .trip!
                                              .routeId,
                                        ),
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  /* Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    "Distance : ",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    "${(double.parse(transit.destinationStopTime!.shapeDistTraveled) - double.parse(transit.departureStopTime!.shapeDistTraveled)).toStringAsFixed(2)} KM",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),*/
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        "Heure de départ: ",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        formatTimeToHHmm(
                                          widget
                                              .transit
                                              .mainTripInfo!
                                              .departureStopTime!
                                              .departureTime,
                                        ),

                                        // "${getFormattedTravelDuration(transit.mainTripInfo!.departureStopTime!.departureTime, transit.mainTripInfo!.destinationStopTime!.arrivalTime)}",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Column(
                          children: [
                            if (widget
                                    .transit
                                    .intermediateStopsWithTimes
                                    .length >
                                2)
                              SizedBox(height: 20),
                            if (widget
                                    .transit
                                    .intermediateStopsWithTimes
                                    .length >
                                2)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showStops =
                                        !_showStops; // Inverser l'état au clic
                                  });
                                },
                                child: Container(
                                  height: 35,
                                  padding: EdgeInsets.only(left: 10, right: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: .2,
                                    ),
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Center(
                                        child: Text(
                                          "( ${widget.transit.intermediateStopsWithTimes.length - 2} ) Arrêts intermédiaires",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _showStops
                                            ? Icons.keyboard_arrow_up_outlined
                                            : Icons
                                                .keyboard_arrow_down_outlined,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(height: 10),
                            if (_showStops)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: TransitInterTimeline(
                                  items:
                                      widget
                                                  .transit
                                                  .intermediateStopsWithTimes
                                                  .length >
                                              2
                                          ? widget
                                              .transit
                                              .intermediateStopsWithTimes
                                              .sublist(
                                                1,
                                                widget
                                                        .transit
                                                        .intermediateStopsWithTimes
                                                        .length -
                                                    1,
                                              )
                                          : [],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
          ),
        ),
      ],
    );
  }
}

class DashPainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final Color color;

  DashPainter({
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

class DashPainter1 extends CustomPainter {
  final double dashWidth;
  final double dashSpacing;
  final Color color;

  DashPainter1({
    required this.dashWidth,
    required this.dashSpacing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpacing;
    }
  }

  @override
  bool shouldRepaint(DashPainter1 oldDelegate) => false;
}
