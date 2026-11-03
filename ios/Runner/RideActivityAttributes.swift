import Foundation
import ActivityKit

/// Definition of ActivityAttributes for Seddo VTC rides.
/// Complies with Apple's strict 4 KB payload limit.
public struct RideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var status: String
        public var statusLabel: String
        public var etaMinutes: Int
        public var progress: Double
        public var updatedAtTimestamp: Int

        public init(
            status: String,
            statusLabel: String,
            etaMinutes: Int,
            progress: Double,
            updatedAtTimestamp: Int
        ) {
            self.status = status
            self.statusLabel = statusLabel
            self.etaMinutes = etaMinutes
            self.progress = progress
            self.updatedAtTimestamp = updatedAtTimestamp
        }
    }

    // Static data fixed for the duration of the ride
    public var rideId: String
    public var driverName: String
    public var carModel: String
    public var carColor: String
    public var licensePlate: String
    public var departureText: String
    public var destinationText: String

    public init(
        rideId: String,
        driverName: String,
        carModel: String,
        carColor: String,
        licensePlate: String,
        departureText: String,
        destinationText: String
    ) {
        self.rideId = rideId
        self.driverName = driverName
        self.carModel = carModel
        self.carColor = carColor
        self.licensePlate = licensePlate
        self.departureText = departureText
        self.destinationText = destinationText
    }
}
