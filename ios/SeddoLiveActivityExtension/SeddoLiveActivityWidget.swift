import SwiftUI
import WidgetKit
import ActivityKit

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
struct SeddoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // Lock Screen / Notification Banner Presentation
            SeddoLockScreenLiveView(context: context)
                .activityBackgroundTint(Color(red: 17/255, green: 24/255, blue: 39/255))
                .activitySystemActionForegroundColor(Color.white)
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
                                .foregroundColor(Color(red: 34/255, green: 197/255, blue: 94/255))
                        } else {
                            Text("Arrivé")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 34/255, green: 197/255, blue: 94/255))
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
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 22/255, green: 163/255, blue: 74/255),
                                                Color(red: 34/255, green: 197/255, blue: 94/255)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
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
                HStack(spacing: 3) {
                    Image(systemName: "car.fill")
                        .foregroundColor(carTint(from: context.attributes.carColor))
                        .font(.system(size: 12))
                    if context.state.etaMinutes > 0 {
                        Text("\(context.state.etaMinutes)m")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 4)
            } compactTrailing: {
                // Mini progress gauge
                ProgressView(value: context.state.progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 34/255, green: 197/255, blue: 94/255)))
                    .frame(width: 14, height: 14)
                    .padding(.trailing, 4)
            } minimal: {
                Image(systemName: "car.fill")
                    .foregroundColor(carTint(from: context.attributes.carColor))
                    .font(.system(size: 12))
            }
        }
    }
}

/// Lock Screen banner view matching Seddo design guidelines
@available(iOSApplicationExtension 16.1, *)
struct SeddoLockScreenLiveView: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header: Seddo brand + ETA Badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "car.circle.fill")
                        .foregroundColor(Color(red: 34/255, green: 197/255, blue: 94/255))
                        .font(.system(size: 18, weight: .bold))
                    Text("SEDDO COURSE")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.0)
                        .foregroundColor(.white)
                }

                Spacer()

                // ETA Badge
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    if context.state.etaMinutes > 0 {
                        Text("\(context.state.etaMinutes) min")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Arrivé")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 22/255, green: 163/255, blue: 74/255))
                .cornerRadius(12)
            }

            // Driver & Vehicle Card
            HStack(alignment: .center, spacing: 12) {
                // Vehicle color preview badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: "car.fill")
                        .foregroundColor(carTint(from: context.attributes.carColor))
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.driverName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Text(context.attributes.carModel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Circle()
                            .fill(carTint(from: context.attributes.carColor))
                            .frame(width: 6, height: 6)

                        Text(context.attributes.carColor)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                // License Plate Tag
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.attributes.licensePlate)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 254/255, green: 240/255, blue: 138/255))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                }
            }

            // Progress Bar & Status Text
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 7)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 22/255, green: 163/255, blue: 74/255),
                                        Color(red: 34/255, green: 197/255, blue: 94/255),
                                        Color(red: 74/255, green: 222/255, blue: 128/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width * CGFloat(context.state.progress), geo.size.width)), height: 7)
                    }
                }
                .frame(height: 7)

                HStack {
                    Text(context.state.statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 34/255, green: 197/255, blue: 94/255))

                    Spacer()

                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(Color(red: 17/255, green: 24/255, blue: 39/255))
    }
}

/// Helper extracting a displayable SwiftUI Color from the carColor string or hex
func carTint(from colorStr: String) -> Color {
    let clean = colorStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if clean.contains("noir") || clean.contains("black") {
        return Color(white: 0.2)
    }
    if clean.contains("blanc") || clean.contains("white") {
        return Color.white
    }
    if clean.contains("rouge") || clean.contains("red") {
        return Color(red: 220/255, green: 38/255, blue: 38/255)
    }
    if clean.contains("bleu") || clean.contains("blue") {
        return Color(red: 37/255, green: 99/255, blue: 235/255)
    }
    if clean.contains("jaune") || clean.contains("yellow") {
        return Color(red: 245/255, green: 158/255, blue: 11/255)
    }
    if clean.contains("gris") || clean.contains("grey") || clean.contains("argent") {
        return Color(red: 156/255, green: 163/255, blue: 175/255)
    }
    if clean.contains("vert") || clean.contains("green") {
        return Color(red: 22/255, green: 163/255, blue: 74/255)
    }

    // Hex parsing fallback
    let hex = clean.replacingOccurrences(of: "#", with: "")
    if hex.count == 6, let intVal = UInt64(hex, radix: 16) {
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    return Color.white
}
#endif
