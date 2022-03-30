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

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

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

extension View {
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        self.modifier(MeasureSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

// MARK: - Track Frame

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

    private let coordinateSpaceName = "scrollViewCoordinates"

    var body: some View {
        ZStack(alignment: .top) {
            header()
                .measureSize {
                    viewModel.headerHeight = $0.height
                }
                .offset(y: viewModel.headerOffsetY)

            ScrollView {
                Color.clear
                    .frame(height: viewModel.headerHeight)
                    .trackFrame(in: .named(coordinateSpaceName)) {
                        viewModel.headerFrame.value = $0
                    }

                content()
            }
            .coordinateSpace(name: coordinateSpaceName)
        }
        .clipped()
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
                .compactMap { (offsetY, deltaY, headerHeight) -> State? in
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
                .sink { [weak self] state in
                    withAnimation {
                        switch state {
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

// MARK: - Demo

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Title bar")
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.gray)

            ScrollableContainer {
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
