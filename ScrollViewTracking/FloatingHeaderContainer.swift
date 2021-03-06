//
//  FloatingHeaderContainer.swift
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

import Combine
import SwiftUI

/**
 A scrollabie view with a header that hides when scrolling down (swiping up) and shows when scrolling up (swiping down).
 */
struct FloatingHeaderContainer<Header, Content>: View where Header: View, Content: View {
    @StateObject private var viewModel: ViewModel

    /// The header that will be shown or hidden when scrolling.
    @ViewBuilder var header: () -> Header

    /// The scrollable content.
    @ViewBuilder var content: () -> Content

    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _viewModel = StateObject(wrappedValue: ViewModel())
        self.header = header
        self.content = content
    }

    /// Symbolic constant for the coordinate space name, used in frame computations.
    private let scrollViewCoordinateSpace = "scrollViewCoordinates"

    var body: some View {
        // Use a ZStack to put the header on top of the scroll view.
        ZStack(alignment: .top) {
            ScrollView {
                // It seems a VStack is implicitly added to the scroll view if we don't specify one.
                // The implicitly-added one has a non-zero spacing value.
                VStack(spacing: 0) {
                    // Place a blank space at the top of the scroll view to match the header's height.
                    // When shown, the header will overlap this space. The idea is to never show this
                    // space without the header obscuring it, so we need to track it's location so as
                    // to hide the header when it scroll off screen and show the header when it comes
                    // back on screen.
                    Color.clear
                        .frame(height: viewModel.headerHeight)
                        .trackFrame(name: "scrollViewHeader", in: .named(scrollViewCoordinateSpace)) {
                            viewModel.headerFrame.send($0)
                        }

                    // Place the content below the blank space used to track scrolling.
                    content()
                }
            }

            // Specify the coordinate space of the scroll view for use when tracking the frame.
            .coordinateSpace(name: scrollViewCoordinateSpace)

            // Place the header second, on top of the scroll view.
            header()
                // Measure the header's actual size and save its height to the view model.
                .measureSize(name: "headerSize") {
                    viewModel.headerHeight = $0.height
                }

                // Offset the header vertically per the view model's computations. Since we
                // specify that the ZStack is clipped, moving this to a negative offset will
                // hide the header. An offset of 0 will show it in its default location.
                .offset(y: viewModel.headerOffsetY)
        }
        .clipped()
    }
}

extension FloatingHeaderContainer {
    @MainActor private class ViewModel: ObservableObject {

        // The action determined by the current scroll offset, scroll velocity, and header height.
        private enum Action: Equatable {
            case show
            case hide

            // This action allows us to track the scroll view initially if the user
            // is slowly scrolling down (swiping up).
            case track(offsetY: CGFloat)
        }

        // Tracks the header height, used in the header offset calculations.
        // Using a CurrentValueSubject here does not display correctly on first appearance.
        @Published var headerHeight: CGFloat = 0

        // Use a subject to track the scroll view's offset so we can show/hide the header.
        let headerFrame: CurrentValueSubject<CGRect, Never>

        // Publish the header offset to trigger a layout change.
        @Published var headerOffsetY: CGFloat = 0

        private var cancellables: Set<AnyCancellable> = []

        init() {
            // Map the scroll view's header frame to find the offset, which is the minY coordinate of the frame.
            headerFrame = .init(.zero)
            let offsetY = headerFrame.map { $0.minY }

            // Combine the offset with the previous offset to compute the velocity.
            let deltaY = Publishers.Zip(offsetY, offsetY.dropFirst())
                .map { (prev, curr) in
                    curr - prev
                }

            Publishers.CombineLatest3(offsetY, deltaY, $headerHeight)
                // Combine the offset, velocity, and header height to determine an action.
                .compactMap { (offsetY, deltaY, headerHeight) -> Action? in
                    if -headerHeight < offsetY && offsetY <= 0 && deltaY < 0 {
                        return .track(offsetY: offsetY)
                    }
                    else if offsetY < 0 && deltaY < 0 {
                        return .hide
                    }
                    else if offsetY < 0 && deltaY >= 0 {
                        return .show
                    }
                    return nil
                }
                .removeDuplicates()

                /*
                 Using the combine-schedulers library (https://github.com/pointfreeco/combine-schedulers.git),
                 we could change this to:

                 ```
                 .receive(on: DispatchQueue.main.animated())
                 .map { action in
                     switch action {
                         case .show: return 0
                         case .hide: return -headerHeight.value
                         case .track(let offsetY): return offsetY
                     }
                 }
                 .assign(to: &self.$headerOffsetY)
                 ```

                 This approach doesn't require any external libraries though. We simply animate the change
                 to the headerOffsetY value.
                 */
                .sink { [weak self] action in
                    withAnimation {
                        switch action {
                        case .show:
                            self?.headerOffsetY = 0

                        case .hide:
                            self?.headerOffsetY = -(self?.headerHeight ?? 0)

                        case .track(let offsetY):
                            self?.headerOffsetY = offsetY
                        }
                    }
                }
                .store(in: &cancellables)
        }
    }
}
