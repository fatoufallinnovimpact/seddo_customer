import SwiftUI
import WidgetKit
import ActivityKit

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
struct SeddoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // Translucent glass Lock Screen / Notification Banner presentation
            SeddoLockScreenLiveView(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(Color(red: 251/255, green: 91/255, blue: 0/255))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .foregroundColor(carTint(from: context.attributes.carColor))
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.driverName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(context.attributes.licensePlate)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.etaMinutes > 0 {
                            Text("\(context.state.etaMinutes) min")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(Color(red: 251/255, green: 91/255, blue: 0/255))
                        } else {
                            Text("Arrivé")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 251/255, green: 91/255, blue: 0/255))
                        }
                        Text(context.state.statusLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Progress bar in Seddo Orange
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 251/255, green: 91/255, blue: 0/255))
                                    .frame(width: max(0, min(geo.size.width * CGFloat(context.state.progress), geo.size.width)), height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text(context.attributes.carModel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(carTint(from: context.attributes.carColor))
                                    .frame(width: 8, height: 8)
                                Text(context.attributes.carColor)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(Color(red: 22/255, green: 163/255, blue: 74/255))
                        .frame(width: 22, height: 22)
                    Image(systemName: "car.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.leading, 4)
            } compactTrailing: {
                Text(context.state.etaMinutes > 0 ? "\(context.state.etaMinutes) min" : "Arrivé")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 22/255, green: 163/255, blue: 74/255))
                    .padding(.trailing, 4)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(Color(red: 22/255, green: 163/255, blue: 74/255))
                        .frame(width: 22, height: 22)
                    Image(systemName: "car.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .bold))
                }
            }
        }
    }
}

/// Translucent Lock Screen card view matching the reference layout:
/// - Top Row Left: Seddo brand icon + "Arrivée dans X min" + "[Couleur] [Modèle]"
/// - Top Row Right: License plate in rounded badge + Car preview in REAL COLOR
/// - Middle Row: Solid horizontal line (NO dashed/dotted line) + Top-Down car in REAL COLOR + Destination ring (○)
@available(iOSApplicationExtension 16.1, *)
struct SeddoLockScreenLiveView: View {
    let context: ActivityViewContext<RideActivityAttributes>

    private var isFinished: Bool {
        context.state.progress >= 0.98 ||
        context.state.statusLabel.localizedCaseInsensitiveContains("terminée") ||
        context.state.statusLabel.localizedCaseInsensitiveContains("terminé")
    }

    private var isArrivedAtPickup: Bool {
        !isFinished && (
            context.state.status.localizedCaseInsensitiveContains("arrived") ||
            (context.state.statusLabel.localizedCaseInsensitiveContains("arrivé") && !context.state.statusLabel.localizedCaseInsensitiveContains("destination")) ||
            (context.state.statusLabel.localizedCaseInsensitiveContains("prise en charge") && context.state.statusLabel.localizedCaseInsensitiveContains("arrivé"))
        )
    }

    private var isTrip: Bool {
        !isFinished && !isArrivedAtPickup && (
            context.state.statusLabel.localizedCaseInsensitiveContains("destination") ||
            context.state.statusLabel.localizedCaseInsensitiveContains("trajet") ||
            context.state.status.localizedCaseInsensitiveContains("progress")
        )
    }

    private var etaHeadline: String {
        if isFinished {
            return "Course terminée"
        }
        if isArrivedAtPickup {
            return "Chauffeur arrivé"
        }
        if context.state.etaMinutes > 0 {
            return "Arrivée dans \(context.state.etaMinutes) min"
        }
        return "Arrivée imminente"
    }

    private var vehicleSubtitle: String {
        let color = context.attributes.carColor.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = context.attributes.carModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !color.isEmpty && !model.isEmpty {
            return "\(color.capitalized) \(model)"
        }
        return model.isEmpty ? "Véhicule Seddo" : model
    }

    private var plateText: String {
        context.attributes.licensePlate.isEmpty ? "AA-647-JZ" : context.attributes.licensePlate
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top Row: App Icon + Headline + Vehicle Subtitle (Left), Plate Badge + Car Preview (Right)
            HStack(alignment: .center, spacing: 10) {
                // Seddo Brand Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 235/255, green: 25/255, blue: 25/255))
                        .frame(width: 38, height: 38)

                    Text("seddo")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(etaHeadline)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(vehicleSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                // Right Column: License plate badge + Car preview in REAL COLOR
                VStack(alignment: .trailing, spacing: 3) {
                    Text(plateText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )

                    // Side-view car preview colored with REAL vehicle color
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(carTint(from: context.attributes.carColor))
                        .padding(.trailing, 2)
                }
            }

            // Middle Row: Continuous Solid Route Line with Top-Down Car in REAL COLOR and Destination Ring (○)
            if !isArrivedAtPickup && !isFinished {
                SeddoRouteTrackView(
                    progress: context.state.progress,
                    carColor: context.attributes.carColor
                )
                .frame(height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.65))
        )
    }
}

/// Realistic Top-Down car view matching the vehicle marker on maps:
/// - Body tinted in REAL car color from API
/// - Wheels, windshields, roof, headlights, drop shadow
@available(iOSApplicationExtension 16.1, *)
struct TopDownCarView: View {
    let tintColor: Color

    var body: some View {
        ZStack {
            // Soft drop shadow
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.35))
                .frame(width: 38, height: 20)
                .offset(y: 2)
                .blur(radius: 2)

            // 4 Wheels
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.15))
                    .frame(width: 7, height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.15))
                    .frame(width: 7, height: 3)
            }
            .offset(y: -9)

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.15))
                    .frame(width: 7, height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.15))
                    .frame(width: 7, height: 3)
            }
            .offset(y: 9)

            // Car main body in real vehicle color
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tintColor)
                .frame(width: 36, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                )

            // Front Windshield (curved dark bar on right)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.2))
                .frame(width: 4, height: 12)
                .offset(x: 6)

            // Rear Window (dark bar on left)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.2))
                .frame(width: 3, height: 11)
                .offset(x: -8)

            // Roof
            RoundedRectangle(cornerRadius: 3)
                .fill(tintColor.opacity(0.85))
                .frame(width: 13, height: 11)
                .offset(x: -1)

            // Headlights
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 254/255, green: 240/255, blue: 138/255))
                    .frame(width: 2.5, height: 2.5)
                Circle()
                    .fill(Color(red: 254/255, green: 240/255, blue: 138/255))
                    .frame(width: 2.5, height: 2.5)
            }
            .offset(x: 17)
        }
    }
}

/// Horizontal route track line with moving top-down car:
/// - Continuous solid line (NO dashed/dotted line, trait plein)
/// - Solid Seddo Orange (#FB5B00) traveled track
/// - Top-down car sitting on the track colored with REAL vehicle color
/// - Destination circle ring (○) on the extreme right
@available(iOSApplicationExtension 16.1, *)
struct SeddoRouteTrackView: View {
    let progress: Double
    let carColor: String

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let centerY = geo.size.height / 2
            let startX: CGFloat = 8
            let endX: CGFloat = totalWidth - 14
            let trackWidth = endX - startX
            let clampedProgress = min(max(progress, 0.05), 0.95)
            let carX = startX + trackWidth * CGFloat(clampedProgress)

            ZStack(alignment: .leading) {
                // 1. Full solid horizontal line across the track (NO dashed line, trait plein)
                Path { path in
                    path.move(to: CGPoint(x: startX, y: centerY))
                    path.addLine(to: CGPoint(x: endX - 10, y: centerY))
                }
                .stroke(
                    Color.white.opacity(0.35),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )

                // 2. Traveled portion: Solid Seddo Orange line from start
                Path { path in
                    path.move(to: CGPoint(x: startX, y: centerY))
                    path.addLine(to: CGPoint(x: carX, y: centerY))
                }
                .stroke(
                    Color(red: 251/255, green: 91/255, blue: 0/255),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )

                // 3. Destination circle ring (○) on the right end
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
                    .frame(width: 14, height: 14)
                    .position(x: endX, y: centerY)

                // 4. Moving Top-Down Car on the track colored with the REAL vehicle color
                TopDownCarView(tintColor: carTint(from: carColor))
                    .position(x: carX, y: centerY)
            }
        }
    }
}

/// Helper extracting a displayable SwiftUI Color from the carColor string or hex
func carTint(from colorStr: String) -> Color {
    let clean = colorStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if clean.contains("noir") || clean.contains("black") {
        return Color(white: 0.15)
    }
    if clean.contains("blanc") || clean.contains("white") {
        return Color(white: 0.85)
    }
    if clean.contains("rouge") || clean.contains("red") || clean.contains("bordeaux") {
        return Color(red: 220/255, green: 38/255, blue: 38/255)
    }
    if clean.contains("bleu") || clean.contains("blue") {
        return Color(red: 37/255, green: 99/255, blue: 235/255)
    }
    if clean.contains("jaune") || clean.contains("yellow") {
        return Color(red: 245/255, green: 158/255, blue: 11/255)
    }
    if clean.contains("gris") || clean.contains("grey") || clean.contains("argent") || clean.contains("silver") {
        return Color(red: 156/255, green: 163/255, blue: 175/255)
    }
    if clean.contains("vert") || clean.contains("green") {
        return Color(red: 22/255, green: 163/255, blue: 74/255)
    }
    if clean.contains("orange") {
        return Color(red: 234/255, green: 88/255, blue: 12/255)
    }
    if clean.contains("marron") || clean.contains("brown") {
        return Color(red: 140/255, green: 70/255, blue: 30/255)
    }

    // Hex parsing fallback
    let hex = clean.replacingOccurrences(of: "#", with: "")
    if hex.count == 6, let intVal = UInt64(hex, radix: 16) {
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    return Color(red: 156/255, green: 163/255, blue: 175/255)
}
#endif
