//
//  ContentView.swift
//  ScrollViewTracking
//
//  Copyright (c) 2022 Rocket Insights, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
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
                HeaderView()
            } content: {
                BodyView()
            }
        }
    }
}

struct HeaderView: View {
    private var values: [String] {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return (1..<21).map {
            formatter.string(from: NSNumber(value: $0))!
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Originally, I used Color.clear here with .frame(width: 20).
                // This caused the horizontal scroll view to fill the height of the screen.
                // Using a Spacer works as intended
                Spacer(minLength: 20)

                ForEach(values, id: \.self) {
                    Text($0)
                        .foregroundColor(.white)
                        .padding([.top, .bottom], 8)
                }

                Spacer(minLength: 20)
            }
        }
        .background(Color(white: 0.2))
    }
}

struct BodyView: View {
    var body: some View {
        ForEach(1..<101) { index in
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                Text(index.description)
                    .padding()
            }
        }
    }
}
