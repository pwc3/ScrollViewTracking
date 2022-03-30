//
//  TrackFrame.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/30/22.
//

import SwiftUI

private struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct TrackFrameModifier: ViewModifier {
    var coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: FramePreferenceKey.self,
                    value: geometry.frame(in: coordinateSpace))
            }
        )
    }
}

extension View {
    func trackFrame(in coordinateSpace: CoordinateSpace, perform action: @escaping (CGRect) -> Void) -> some View {
        self.modifier(TrackFrameModifier(coordinateSpace: coordinateSpace))
            .onPreferenceChange(FramePreferenceKey.self, perform: action)
    }
}
