//
//  ContentView.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/28/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Title bar")
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.gray)

            FloatingHeaderContainer {
                Text("Filter bar")
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .background(.black)
            } content: {
                ForEach(1..<101) { index in
                    VStack(alignment: .leading) {
                        Text(index.description)
                            .padding(4)
                            .padding(.leading, 8)
                        Divider()
                    }
                }
            }
        }
    }
}
