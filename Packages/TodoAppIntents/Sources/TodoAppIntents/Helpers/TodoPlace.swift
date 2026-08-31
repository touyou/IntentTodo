//
//  TodoPlace.swift
//  TodoAppIntents
//

import CoreLocation
import GeoToolbox

/// Bridges between the App Intents native `PlaceDescriptor` (GeoToolbox) type and
/// the CloudKit-safe primitives (name + coordinate) stored on `TodoItem`.
enum TodoPlace {
    /// The CloudKit-safe primitives a `PlaceDescriptor` decomposes into — the same
    /// three values `TodoItem` stores and `descriptor(name:latitude:longitude:)`
    /// reassembles.
    struct Components {
        let name: String?
        let latitude: Double?
        let longitude: Double?
    }

    /// Reconstructs a `PlaceDescriptor` from stored primitives, or `nil` if there
    /// is no usable location.
    static func descriptor(name: String?, latitude: Double?, longitude: Double?) -> PlaceDescriptor? {
        if let latitude, let longitude {
            return PlaceDescriptor(
                representations: [.coordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))],
                commonName: name
            )
        }
        if let name {
            return PlaceDescriptor(representations: [.address(name)], commonName: name)
        }
        return nil
    }

    /// Decomposes a `PlaceDescriptor` into the primitives stored on the model.
    ///
    /// Currently unused: `AddTodoIntent.location` stays a `String` to avoid the SSU build
    /// failure, so nothing takes the return trip. Kept as the counterpart of
    /// `descriptor(name:latitude:longitude:)`.
    static func decompose(_ place: PlaceDescriptor) -> Components {
        Components(
            name: place.commonName,
            latitude: place.coordinate?.latitude,
            longitude: place.coordinate?.longitude
        )
    }
}
