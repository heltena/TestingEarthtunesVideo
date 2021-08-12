//
//  ActivityView.swift
//  TestingEarthtunesVideo
//
//  Created by Helio Tejedor on 8/12/21.
//

import SwiftUI

public struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?
    var excludedActivityTypes: [UIActivity.ActivityType] = []
    
    public init(activityItems: [Any], applicationActivities: [UIActivity]?) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        uiViewController.excludedActivityTypes = excludedActivityTypes
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView(activityItems: ["Hello"], applicationActivities: nil)
    }
}
