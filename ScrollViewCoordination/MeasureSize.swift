//
//  MeasureSize.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/30/22.
//

import SwiftUI

/**
 Uses a `PreferenceKey` to communicate a view's size up the view hierarcny.

 We could extend this by attaching a `Hashable` identifier to the `MeasureSizeModifier` and then
 building a dictionary of identifier to `CGSize` in the `reduce(value:nextValue:)` function.
 */
private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/**
 Attach a `GeometryReader` to the background of the content. The `GeometryReader` fills the
 available space, so it will match the size of the content. We just use a clear color so
 it's invisible to the user and use the `preference` view modifier to communicate the frame
 up the view hierarchy.
 */
private struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SizePreferenceKey.self,
                    value: geometry.size)
            }
        )
    }
}

/**
 This view modifier makes it simple to measure the size of a particular view.

 Whenever the size changes (which occurs when the preference changes), the `action` block is called
 with the size as an argument.
 */
extension View {
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        self.modifier(MeasureSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

