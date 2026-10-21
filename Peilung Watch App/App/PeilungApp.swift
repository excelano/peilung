// PeilungApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

@main
struct PeilungApp: App {
    @State private var location: LocationModel
    @State private var odometer: OdometerModel
    @State private var marks: MarkStore
    @State private var navigator: Navigator

    init() {
        let odometerStore = Store<OdometerState>(name: "odometer")
        let markStore = Store<MarkStore.Contents>(name: "marks")
        let targetStore = Store<Target>(name: "target")
        #if DEBUG
        let demoPage = Demo.page
        if demoPage != nil {
            Demo.prepareStores(odometer: odometerStore, marks: markStore, target: targetStore)
        }
        #endif
        let location = LocationModel()
        let navigator = Navigator(store: targetStore)
        _location = State(initialValue: location)
        _odometer = State(initialValue: OdometerModel(pedometer: Pedometers.make(), store: odometerStore))
        _marks = State(initialValue: MarkStore(store: markStore))
        _navigator = State(initialValue: navigator)
        #if DEBUG
        if let demoPage {
            Demo.apply(location: location, navigator: navigator, page: demoPage)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(location)
                .environment(odometer)
                .environment(marks)
                .environment(navigator)
        }
    }
}
