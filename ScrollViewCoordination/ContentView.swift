//
//  ContentView.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/28/22.
//

import Combine
import CombineSchedulers
import SwiftUI

private struct OffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    @StateObject private var viewModel: ViewModel

    private static let titleBarHeight: CGFloat = 44

    private static let filterBarHeight: CGFloat = 32

    init() {
        _viewModel = StateObject(
            wrappedValue: ViewModel(
                titleBarHeight: Self.titleBarHeight,
                filterBarHeight: Self.filterBarHeight
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Text("Title bar")
                .frame(height: Self.titleBarHeight)
                .frame(maxWidth: .infinity)
                .background(Color.gray)
                .zIndex(2)

            Text("Filter bar")
                .foregroundColor(.white)
                .frame(height: Self.filterBarHeight)
                .frame(maxWidth: .infinity)
                .background(.black)
                .offset(y: viewModel.filterBarOffsetY)
                .zIndex(1)

            ScrollView {
                VStack {
                    GeometryReader { geom in
                        Color.clear
                            .preference(
                                key: OffsetPreferenceKey.self,
                                value: geom.frame(in: .named("frameLayer")).minY
                            )
                    }
                    .frame(width: 0, height: Self.filterBarHeight)

                    ForEach(1..<101) { number in
                        VStack(alignment: .leading) {
                            Text(number.description)
                                .padding(4)
                                .padding(.leading, 8)
                            Divider()
                        }
                    }
                }
                // this is needed to counter the offset below
                // otherwise, the bottom cell(s) would not scroll on to the screen
                .padding(.bottom, Self.titleBarHeight)
            }
            // move the scroll content down to accomodate being layered under the title barand filter bar
            .offset(y: Self.titleBarHeight)
            .coordinateSpace(name: "frameLayer")
        }
        .onPreferenceChange(OffsetPreferenceKey.self) { offset in
            viewModel.offsetY.value = offset
        }
    }
}

extension ContentView {
    @MainActor private class ViewModel: ObservableObject {
        // Updated from the onPreferenceChange of the ContentView
        let offsetY: CurrentValueSubject<CGFloat, Never>

        // Only needed for debugging
        // private var cancellables: Set<AnyCancellable> = []

        @Published var filterBarOffsetY: CGFloat

        init(titleBarHeight: CGFloat, filterBarHeight: CGFloat) {
            filterBarOffsetY = titleBarHeight
            offsetY = .init(0)

            // Debugging
            // offsetY.sink { print("offsetY:", $0) }.store(in: &cancellables)

            let deltaY = Publishers.Zip(offsetY, offsetY.dropFirst())
                .map { (prev, curr) in
                    curr - prev
                }
                .eraseToAnyPublisher()

            // Debugging
            // deltaY.sink { print("deltaY:", $0) }.store(in: &cancellables)

            let offsetToShowFilterBar = titleBarHeight
            let offsetToHideFilterBar = titleBarHeight - filterBarHeight

            Publishers.CombineLatest(offsetY, deltaY)
                .map { offsetY, deltaY in
                    let delta = titleBarHeight - offsetY
                    if delta > 0 && delta < filterBarHeight {
                        return offsetY
                    }

                    if offsetY >= titleBarHeight || deltaY > 0 {
                        return offsetToShowFilterBar
                    }

                    return offsetToHideFilterBar
                }
                .removeDuplicates()
                .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
                // .print("filterBarOffsetY")
                .receive(on: DispatchQueue.main.animation())
                .assign(to: &self.$filterBarOffsetY)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
