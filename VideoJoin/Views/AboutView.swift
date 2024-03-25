//
//  AboutView.swift
//  VideoJoin
//
//  Created by Anton Simonov on 29/2/24.
//

import SwiftUI

struct AboutView: View {
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    let supportURL = "https://videojoin.simoant.com/home/support"
    let policyURL = "https://videojoin.simoant.com/home/privacy"

    var body: some View {
        List {
            Section(header: Text("General")) {
                Link("Privacy Policy", destination: URL(string: policyURL)!)
                Link("Support", destination: URL(string: supportURL)!)
                Text("App Version: \(appVersion) Build:\(buildNumber)")
            }
        }
        .navigationBarTitle("About", displayMode: .inline)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
