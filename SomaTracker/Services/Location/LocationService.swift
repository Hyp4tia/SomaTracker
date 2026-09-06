//
//  LocationService.swift
//  SomaTracker
//
//  Lightweight location service detecting the user's city and neighborhood for AI Journal tagging.
//

import Foundation
import CoreLocation
import Observation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var currentLocationString: String = ""
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Asynchronously fetches the current city & area string, e.g. "Cairo, Egypt" or "Los Angeles, CA"
    func fetchCurrentLocation() async -> String {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        guard let location = manager.location else {
            return currentLocationString
        }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let place = placemarks.first {
                let locality = place.locality ?? place.subAdministrativeArea ?? ""
                let adminArea = place.administrativeArea ?? place.country ?? ""
                if !locality.isEmpty && !adminArea.isEmpty {
                    let formatted = "\(locality), \(adminArea)"
                    self.currentLocationString = formatted
                    return formatted
                } else if !locality.isEmpty {
                    self.currentLocationString = locality
                    return locality
                } else if let name = place.name {
                    self.currentLocationString = name
                    return name
                }
            }
        } catch {
            print("[LocationService] Geocoding notice: \(error.localizedDescription)")
        }

        return currentLocationString
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let place = placemarks.first {
                let locality = place.locality ?? place.subAdministrativeArea ?? ""
                let adminArea = place.administrativeArea ?? place.country ?? ""
                if !locality.isEmpty && !adminArea.isEmpty {
                    self.currentLocationString = "\(locality), \(adminArea)"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal
    }
}
