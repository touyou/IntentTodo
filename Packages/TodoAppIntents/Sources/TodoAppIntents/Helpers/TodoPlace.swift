//
//  TodoPlace.swift
//  TodoAppIntents
//

import CoreLocation
import GeoToolbox

/// Bridges between the App Intents native `PlaceDescriptor` (GeoToolbox) type and
/// the CloudKit-safe primitives (name + coordinate) stored on `TodoItem`.
enum TodoPlace {
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
    static func decompose(_ place: PlaceDescriptor) -> (name: String?, latitude: Double?, longitude: Double?) {
        (place.commonName, place.coordinate?.latitude, place.coordinate?.longitude)
    }
}
