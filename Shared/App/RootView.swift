// RootView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
#if os(watchOS)
import WidgetKit
#endif

/// The pages, and the sensors each one needs: GPS while the screen is up, the heading
/// only on Navigate, live pedometer updates only on Odometer. A dimmed screen stops them
/// all, since watchOS can leave the app dimmed in front for hours, and on an always-on
/// watch the dimmed app can stay `.active`.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(LocationModel.self) private var location
    @Environment(OdometerModel.self) private var odometer
    @Environment(Navigator.self) private var navigator
    @AppStorage(Units.storageKey) private var units = Units.localeDefault
    @AppStorage(NorthReference.storageKey) private var reference = NorthReference.magnetic

    var body: some View {
        pages
        #if DEBUG
        .overlay { if Demo.samplesHaptics { HapticsSampler() } }
        #endif
        .onChange(of: scenePhase, initial: true) { updateSensors() }
        .onChange(of: isLuminanceReduced) { updateSensors() }
        .onChange(of: navigator.page) { updateSensors() }
        #if os(watchOS)
        .onChange(of: widgetState, initial: true) {
            WidgetState.store.save(widgetState)
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
        .onChange(of: location.location?.timestamp) {
            if let coordinate = location.freshLocation()?.coordinate {
                odometer.offerStartFix(Coordinate(coordinate))
            }
        }
    }

    #if os(watchOS)
    /// Vertical pages under one NavigationStack: a stack per page nests navigation
    /// controllers, which UIKit rejects with an exception.
    private var pages: some View {
        @Bindable var navigator = navigator
        return NavigationStack {
            TabView(selection: $navigator.page) {
                NavigateView().tag(Page.navigate)
                OdometerView().tag(Page.odometer)
                HereView().tag(Page.here)
                MarksView().tag(Page.marks)
            }
            .tabViewStyle(.verticalPage)
        }
    }
    #else
    /// A tab bar, with a stack per tab.
    private var pages: some View {
        @Bindable var navigator = navigator
        return TabView(selection: $navigator.page) {
            tab(.navigate, "Navigate", systemImage: "location.north.circle") { NavigateView().padding() }
            tab(.odometer, "Odometer", systemImage: "figure.walk") { OdometerView().padding() }
            tab(.here, "Here", systemImage: "mappin.and.ellipse") { HereView().padding() }
            tab(.marks, "Marks", systemImage: "list.bullet") { MarksView() }
        }
    }

    private func tab(_ page: Page, _ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        NavigationStack {
            content().navigationBarTitleDisplayMode(.inline)
        }
        .tabItem { Label(title, systemImage: systemImage) }
        .tag(page)
    }
    #endif

    #if os(watchOS)
    private var widgetState: WidgetState {
        let north = North(reference, declination: location.declination)
        let run = odometer.state
        return WidgetState(goal: navigator.goal?.title(north: north), trackingStart: run.startDate,
                           trackingEnd: run.endDate, trackedDistance: run.finalDistance, units: units)
    }
    #endif

    private func updateSensors() {
        guard scenePhase == .active, !isLuminanceReduced else {
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
