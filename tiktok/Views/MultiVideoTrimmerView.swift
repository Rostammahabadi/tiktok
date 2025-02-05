//
//  MultiVideoTrimmer.swift
//  tiktok
//
//  Created by Rostam on 2/4/25.
//

import SwiftUI
import AVKit

/// A simple multi-video trimmer screen.
struct MultiVideoTrimmerView: View {
    let urls: [URL]
    let onComplete: () -> Void
    @State private var currentIndex = 0
    
    var body: some View {
        VStack {
            if currentIndex < urls.count {
                VideoTrimmerView(url: urls[currentIndex])
            }
            HStack {
                Text("\(currentIndex + 1) of \(urls.count)")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if currentIndex < urls.count - 1 {
                    Button("Next") {
                        currentIndex += 1
                    }
                } else {
                    Button("Done") {
                        onComplete()
                    }
                }
            }
            .padding()
        }
    }
}
