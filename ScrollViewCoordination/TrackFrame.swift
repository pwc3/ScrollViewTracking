//
//  TrackFrame.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/30/22.
//

import SwiftUI

/**
 Use a `PreferenceKey` to communicate a view's frame up the view hierarchy.

 We could extend this by attaching a `Hashable` identifier to the `TrackFrameModifier` and then
 building a dictionary of identifier to `CGRect` in the `reduce(value:nextValue:)` function.
 */
private struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/**
 Attach a `GeometryReader` to the background of the content. The `GeometryReader` fills the
 available space, so it will match the size of the content. We just use a clear color so
 it's invisible to the user and use the `preference` view modifier to communicate the frame
 up the view hierarchy.
 */
private struct TrackFrameModifier: ViewModifier {
    var coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: FramePreferenceKey.self,
                        value: geometry.frame(in: coordinateSpace)
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
    func trackFrame(in coordinateSpace: CoordinateSpace, perform action: @escaping (CGRect) -> Void) -> some View {
        self.modifier(TrackFrameModifier(coordinateSpace: coordinateSpace))
            .onPreferenceChange(FramePreferenceKey.self, perform: action)
    }
}
