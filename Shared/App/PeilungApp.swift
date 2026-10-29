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
    @State private var sync: CompanionSync

    init() {
        let odometerStore = Store<OdometerState>(name: "odometer")
        let markStore = Store<MarkStore.Contents>(name: "marks")
        let goalStore = Store<Goal>(name: "goal")
        #if DEBUG
        let demoPage = Demo.page
        if demoPage != nil {
            Demo.prepareStores(odometer: odometerStore, marks: markStore, goal: goalStore)
        }
        #endif
        let location = LocationModel()
        let navigator = Navigator(store: goalStore)
        _location = State(initialValue: location)
        let odometer = OdometerModel(pedometer: Pedometers.make(), store: odometerStore)
        let marks = MarkStore(store: markStore)
        _odometer = State(initialValue: odometer)
        _marks = State(initialValue: marks)
        _navigator = State(initialValue: navigator)
        let sync = CompanionSync(navigator: navigator, odometer: odometer, marks: marks)
        _sync = State(initialValue: sync)
        #if DEBUG
        if let demoPage {
            Demo.apply(location: location, navigator: navigator, page: demoPage)
            return
        }
        #endif
        sync.start()
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
