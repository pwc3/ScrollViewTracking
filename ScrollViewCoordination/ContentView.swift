//
//  ContentView.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/28/22.
//

import Combine
import CombineSchedulers
import SwiftUI

// MARK: - Measure Size

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
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

extension View {
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        self.modifier(MeasureSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

// MARK: - Track Frame

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct TrackFrameModifier: ViewModifier {
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

// MARK: - Scrollable Container

struct ScrollableContainer<Header, Content>: View where Header: View, Content: View {
    @StateObject private var viewModel: ViewModel

    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _viewModel = StateObject(wrappedValue: ViewModel())
        self.header = header
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            header()
                .zIndex(-1)
                .measureSize {
                    viewModel.headerHeight = $0.height
                }
                .offset(y: viewModel.headerOffsetY)

            ScrollView {
                Color.clear
                    .frame(height: viewModel.headerHeight)
                    .trackFrame(in: .named("containerSpace")) {
                        viewModel.headerFrame.value = $0
                    }

                content()
            }
            .coordinateSpace(name: "containerSpace")
        }
    }
}

extension ScrollableContainer {
    @MainActor private class ViewModel: ObservableObject {

        enum State: Equatable {
            case show
            case hide
            case track(offsetY: CGFloat)
        }

        @Published var headerHeight: CGFloat = 0

        @Published var headerOffsetY: CGFloat = 0

        let headerFrame: CurrentValueSubject<CGRect, Never>

        private var cancellables: Set<AnyCancellable> = []

        init() {
            headerFrame = .init(.zero)
            let offsetY = headerFrame.map { $0.minY }

            let deltaY = Publishers.Zip(offsetY, offsetY.dropFirst())
                .map { (prev, curr) in
                    curr - prev
                }
                .eraseToAnyPublisher()

            Publishers.CombineLatest3(offsetY, deltaY, $headerHeight)
                .map { (offsetY, deltaY, headerHeight) -> State in
                    // if offsetY is between 0 and -headerHeight, track the position
                    if -headerHeight < offsetY && offsetY <= 0 {
                        return .track(offsetY: offsetY)
                    }

                    // if offsetY and deltaY are negative, hide
                    if offsetY < 0 && deltaY < 0 {
                        print("hide: offsetY =", offsetY)
                        return .hide
                    }

                    print("show: offsetY =", offsetY)
                    return .show
                }
                .removeDuplicates()
                .sink { [weak self] state in
                    switch state {
                    case .show:
                        withAnimation {
                            self?.headerOffsetY = 0
                        }

                    case .hide:
                        withAnimation {
                            self?.headerOffsetY = -(self?.headerHeight ?? 0)
                        }

                    case .track(let offsetY):
                        self?.headerOffsetY = offsetY
                    }
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - Demo

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Title bar")
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.gray)
                .zIndex(1)

            ScrollableContainer {
                Text("Filter bar")
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .background(.black)
                    .background(
                        GeometryReader { geom in

                        }
                    )
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

//struct ContentView: View {
//    @StateObject private var viewModel: ViewModel
//
//    private static let titleBarHeight: CGFloat = 44
//
//    private static let filterBarHeight: CGFloat = 32
//
//    init() {
//        _viewModel = StateObject(
//            wrappedValue: ViewModel(
//                titleBarHeight: Self.titleBarHeight,
//                filterBarHeight: Self.filterBarHeight
//            )
//        )
//    }
//
//    var body: some View {
//        ZStack(alignment: .top) {
//            Text("Title bar")
//                .frame(height: Self.titleBarHeight)
//                .frame(maxWidth: .infinity)
//                .background(Color.gray)
//                .zIndex(2)
//
//            Text("Filter bar")
//                .foregroundColor(.white)
//                .frame(height: Self.filterBarHeight)
//                .frame(maxWidth: .infinity)
//                .background(.black)
//                .offset(y: viewModel.filterBarOffsetY)
//                .zIndex(1)
//
//            ScrollView {
//                VStack {
//                    GeometryReader { geom in
//                        Color.clear
//                            .preference(
//                                key: OffsetPreferenceKey.self,
//                                value: geom.frame(in: .named("frameLayer")).minY
//                            )
//                    }
//                    .frame(width: 0, height: Self.filterBarHeight)
//
//                    ForEach(1..<101) { number in
//                        VStack(alignment: .leading) {
//                            Text(number.description)
//                                .padding(4)
//                                .padding(.leading, 8)
//                            Divider()
//                        }
//                    }
//                }
//                // this is needed to counter the offset below
//                // otherwise, the bottom cell(s) would not scroll on to the screen
//                .padding(.bottom, Self.titleBarHeight)
//            }
//            // move the scroll content down to accomodate being layered under the title barand filter bar
//            .offset(y: Self.titleBarHeight)
//            .coordinateSpace(name: "frameLayer")
//        }
//        .onPreferenceChange(OffsetPreferenceKey.self) { offset in
//            viewModel.offsetY.value = offset
//        }
//    }
//}
//
//extension ContentView {
//    @MainActor private class ViewModel: ObservableObject {
//        // Updated from the onPreferenceChange of the ContentView
//        let offsetY: CurrentValueSubject<CGFloat, Never>
//
//        // Only needed for debugging
//        // private var cancellables: Set<AnyCancellable> = []
//
//        @Published var filterBarOffsetY: CGFloat
//
//        init(titleBarHeight: CGFloat, filterBarHeight: CGFloat) {
//            filterBarOffsetY = titleBarHeight
//            offsetY = .init(0)
//
//            // Debugging
//            // offsetY.sink { print("offsetY:", $0) }.store(in: &cancellables)
//
//            let deltaY = Publishers.Zip(offsetY, offsetY.dropFirst())
//                .map { (prev, curr) in
//                    curr - prev
//                }
//                .eraseToAnyPublisher()
//
//            // Debugging
//            // deltaY.sink { print("deltaY:", $0) }.store(in: &cancellables)
//
//            let offsetToShowFilterBar = titleBarHeight
//            let offsetToHideFilterBar = titleBarHeight - filterBarHeight
//
//            Publishers.CombineLatest(offsetY, deltaY)
//                .map { offsetY, deltaY in
//                    let delta = titleBarHeight - offsetY
//                    if delta > 0 && delta < filterBarHeight {
//                        return offsetY
//                    }
//
//                    if offsetY >= titleBarHeight || deltaY > 0 {
//                        return offsetToShowFilterBar
//                    }
//
//                    return offsetToHideFilterBar
//                }
//                .removeDuplicates()
//                .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
//                // .print("filterBarOffsetY")
//                .receive(on: DispatchQueue.main.animation())
//                .assign(to: &self.$filterBarOffsetY)
//        }
//    }
//}
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
