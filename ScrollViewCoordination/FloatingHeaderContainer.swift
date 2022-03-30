//
//  FloatingHeaderContainer.swift
//  ScrollViewCoordination
//
//  Created by Paul Calnan on 3/30/22.
//

import Combine
import SwiftUI

struct FloatingHeaderContainer<Header, Content>: View where Header: View, Content: View {
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

extension FloatingHeaderContainer {
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
