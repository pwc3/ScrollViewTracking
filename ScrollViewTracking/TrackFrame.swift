//
//  TrackFrame.swift
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

/**
 Use a `PreferenceKey` to communicate a view's frame up the view hierarchy.
 */
private struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String : CGRect] = [:]

    static func reduce(value: inout [String : CGRect], nextValue: () -> [String : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/**
 Attach a `GeometryReader` to the background of the content. The `GeometryReader` fills the
 available space, so it will match the size of the content. We just use a clear color so
 it's invisible to the user and use the `preference` view modifier to communicate the frame
 up the view hierarchy.
 */
private struct TrackFrameModifier: ViewModifier {
    var name: String

    var coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: FramePreferenceKey.self,
                        value: [name: geometry.frame(in: coordinateSpace)]
                    )
            }
        )
    }
}

/**
 This view modifier makes it simple to track the frame of a particular view. The coordinate space is
 provided which should match the coordinate space of the scroll view.

 Whenever the frame changes (which occurs when the preference changes), the `action` block is called
 with the frame as an argument.
 */
extension View {
    func trackFrame(name: String, in coordinateSpace: CoordinateSpace, perform action: @escaping (CGRect) -> Void) -> some View {
        self.modifier(TrackFrameModifier(name: name, coordinateSpace: coordinateSpace))
            .onPreferenceChange(FramePreferenceKey.self) { newValue in
                newValue[name].map {
                    action($0)
                }
            }
    }
}
