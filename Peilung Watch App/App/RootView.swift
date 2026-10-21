// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The vertical pages, and the sensors each one needs: GPS while the app is on screen,
/// the heading only on Navigate, live pedometer updates only on Odometer. One
/// NavigationStack holds every page: a stack per page nests navigation controllers,
/// which UIKit rejects with an exception.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocationModel.self) private var location
    @Environment(OdometerModel.self) private var odometer
    @Environment(Navigator.self) private var navigator

    var body: some View {
        @Bindable var navigator = navigator
        NavigationStack {
            TabView(selection: $navigator.page) {
                NavigateView().tag(Page.navigate)
                OdometerView().tag(Page.odometer)
                HereView().tag(Page.here)
                MarksView().tag(Page.marks)
            }
            .tabViewStyle(.verticalPage)
        }
        .onChange(of: scenePhase, initial: true) { updateSensors() }
        .onChange(of: navigator.page) { updateSensors() }
        .onChange(of: location.location?.timestamp) {
            if let coordinate = location.freshLocation()?.coordinate {
                odometer.offerStartFix(Coordinate(coordinate))
            }
        }
    }

    private func updateSensors() {
        guard scenePhase != .background else {
            location.stop()
            odometer.unwatch()
            return
        }
        location.start()
        if navigator.page == .navigate {
            location.startHeading()
        } else {
            location.stopHeading()
        }
        if navigator.page == .odometer {
            odometer.watch()
        } else {
            odometer.unwatch()
        }
    }
}
