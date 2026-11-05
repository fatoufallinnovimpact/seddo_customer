import SwiftUI
import WidgetKit
import ActivityKit

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
struct SeddoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // Lock Screen / Notification Banner Presentation matching Uber card style
            SeddoLockScreenLiveView(context: context)
                .activityBackgroundTint(Color.white)
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

/// Clean white Lock Screen card view matching the reference layout:
/// - Top Row: Headline & arrival status on Left, Vehicle in REAL COLOR on Right (NO duplicate logo)
/// - Middle Row: Route line with Departure pin on left, Arrival pin on right, and moving EcoCar
/// - Bottom Row: Driver name & model on Left, styled license plate badge on Right (as in reference Image 2)
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

    private var arrivalTimeText: String {
        let arrivalDate = Date().addingTimeInterval(TimeInterval(context.state.etaMinutes * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: arrivalDate)
    }

    private var etaHeadline: String {
        if isFinished {
            return "Course terminée"
        }
        if isArrivedAtPickup {
            return "Votre chauffeur est arrivé"
        }
        if isTrip {
            let dest = context.attributes.destinationText.trimmingCharacters(in: .whitespacesAndNewlines)
            return dest.isEmpty ? "En route vers la destination" : "En route vers \(dest)"
        }
        return context.state.etaMinutes > 0 ? "\(context.state.etaMinutes) min avant arrivée" : "Arrivée imminente"
    }

    private var statusSubtitle: String {
        if isFinished {
            return "Arrivé à destination"
        }
        if isArrivedAtPickup {
            return "Au point de départ"
        }
        if isTrip {
            if context.state.etaMinutes > 0 {
                return "Arrivée à \(arrivalTimeText) · \(context.state.etaMinutes) min"
            } else {
                return "Arrivée imminente"
            }
        }
        return "\(context.attributes.driverName) arrive bientôt"
    }

    private var plateText: String {
        context.attributes.licensePlate.isEmpty ? "DK-482-AB" : context.attributes.licensePlate
    }

    private var vehicleText: String {
        let color = context.attributes.carColor.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = context.attributes.carModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !color.isEmpty && !model.isEmpty {
            return "\(model) \(color)"
        }
        return model.isEmpty ? "Véhicule Seddo" : model
    }

    private func driverInitials(from name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2, let f = parts[0].first, let l = parts[1].first {
            return "\(f.uppercased())\(l.uppercased())"
        } else if let f = name.trimmingCharacters(in: .whitespacesAndNewlines).first {
            return String(name.prefix(2)).uppercased()
        }
        return "S"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Top Row: Left Column (ETA Headline & Status Subtitle) & Right (Vehicle in REAL COLOR)
            // NO duplicate brand logo inside the card, as requested!
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(etaHeadline)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 251/255, green: 91/255, blue: 0/255))
                        .lineLimit(1)

                    if isTrip && context.state.etaMinutes > 0 {
                        HStack(spacing: 3) {
                            Text("Arrivée à")
                                .foregroundColor(Color(red: 75/255, green: 85/255, blue: 99/255))
                            Text(arrivalTimeText)
                                .foregroundColor(Color(red: 251/255, green: 91/255, blue: 0/255))
                                .fontWeight(.bold)
                            Text("· \(context.state.etaMinutes) min")
                                .foregroundColor(Color(red: 75/255, green: 85/255, blue: 99/255))
                        }
                        .font(.system(size: 13, weight: .medium))
                    } else {
                        Text(statusSubtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 75/255, green: 85/255, blue: 99/255))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Vehicle side preview tinted to REAL car color
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                        .frame(width: 52, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 229/255, green: 231/255, blue: 235/255), lineWidth: 1)
                        )

                    Image(systemName: "car.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(carTint(from: context.attributes.carColor))
                }
            }

            // Middle Row: Route Track Line with Departure Pin (Left) and Destination Pin (Right)
            if !isArrivedAtPickup && !isFinished {
                SeddoRouteTrackView(progress: context.state.progress)
                    .frame(height: 28)
                    .padding(.top, 2)
            }

            // Bottom Row (Under the Track Line - Image 2): Driver Info (Left) + Plate Badge (Right)
            HStack(alignment: .center, spacing: 8) {
                // Driver Initials Avatar (Image 2)
                ZStack {
                    Circle()
                        .fill(Color(red: 38/255, green: 50/255, blue: 56/255))
                        .frame(width: 32, height: 32)
                    Text(driverInitials(from: context.attributes.driverName))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.attributes.driverName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 17/255, green: 24/255, blue: 39/255))
                        .lineLimit(1)

                    Text(vehicleText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 107/255, green: 114/255, blue: 128/255))
                        .lineLimit(1)
                }

                Spacer()

                // License plate in styled rounded badge with border (Image 2)
                Text(plateText)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 241/255, green: 245/255, blue: 249/255))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(red: 148/255, green: 163/255, blue: 184/255), lineWidth: 1)
                    )
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Horizontal route track line with moving EcoCar:
/// - Departure pin (green circle with white center) on extreme left
/// - Destination pin (Seddo orange circle with white center) on extreme right
/// - Continuous solid Seddo Orange (#FB5B00) line from start up to car
/// - Moving EcoCar badge positioned directly on the track
/// - Dashed neutral grey line from car to destination
@available(iOSApplicationExtension 16.1, *)
struct SeddoRouteTrackView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let centerY = geo.size.height / 2
            let startX: CGFloat = 16
            let endX: CGFloat = totalWidth - 16
            let trackWidth = endX - startX
            let clampedProgress = min(max(progress, 0.06), 0.94)
            let carX = startX + trackWidth * CGFloat(clampedProgress)

            ZStack(alignment: .leading) {
                // 1. Remaining route: Dashed line to destination
                Path { path in
                    path.move(to: CGPoint(x: carX + 12, y: centerY))
                    path.addLine(to: CGPoint(x: endX - 10, y: centerY))
                }
                .stroke(
                    Color(red: 203/255, green: 213/255, blue: 225/255),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [8, 6])
                )

                // 2. Traveled route: Solid Seddo Orange line from start
                Path { path in
                    path.move(to: CGPoint(x: startX + 10, y: centerY))
                    path.addLine(to: CGPoint(x: carX, y: centerY))
                }
                .stroke(
                    Color(red: 251/255, green: 91/255, blue: 0/255),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )

                // 3. Departure point icon (Left extreme): Green pin circle with white center
                ZStack {
                    Circle()
                        .fill(Color(red: 22/255, green: 163/255, blue: 74/255))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                .position(x: startX, y: centerY)

                // 4. Arrival point icon (Right extreme): Seddo Orange pin circle with white center
                ZStack {
                    Circle()
                        .fill(Color(red: 251/255, green: 91/255, blue: 0/255))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                .position(x: endX, y: centerY)

                // 5. Moving EcoCar badge sitting on track
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white)
                        .frame(width: 32, height: 18)
                        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1)
                        )

                    Image(systemName: "car.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 251/255, green: 91/255, blue: 0/255))
                }
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
        return Color(red: 120/255, green: 53/255, blue: 15/255)
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
