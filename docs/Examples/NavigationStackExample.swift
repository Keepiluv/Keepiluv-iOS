// MARK: - NavigationStack 패턴 완전한 예제
// 이 파일은 학습용 예제입니다. 실제 프로젝트에서는 Feature 모듈로 분리하세요.
// 프로젝트 canonical [Route] 배열 NavigationStack 패턴을 따릅니다.

import ComposableArchitecture
import SwiftUI

// MARK: - Route

enum HomeRoute: Hashable {
    case detail
    case settings
}

// MARK: - 1️⃣ Home Feature (Root)

@Reducer
struct HomeReducer {
    @ObservableState
    struct State: Equatable {
        var items: [Item] = Item.samples
        var routes: [HomeRoute] = []
        var detail: DetailReducer.State?
        var settings: SettingsReducer.State?

        mutating func syncChildStatesWithRoutes() {
            if !routes.contains(.detail) {
                detail = nil
            }
            if !routes.contains(.settings) {
                settings = nil
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case itemTapped(Item)
        case settingsButtonTapped
        case detail(DetailReducer.Action)
        case settings(SettingsReducer.Action)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                // System back/pop mutates NavigationStack(path:) directly.
                // Keep optional child states in sync with the remaining routes.
                state.syncChildStatesWithRoutes()
                return .none

            case .itemTapped(let item):
                state.detail = DetailReducer.State(item: item)
                state.routes.append(.detail)
                return .none

            case .settingsButtonTapped:
                state.settings = SettingsReducer.State()
                state.routes.append(.settings)
                return .none

            case .detail(.settingsButtonTapped):
                state.settings = SettingsReducer.State()
                state.routes.append(.settings)
                return .none

            case .settings(.delegate(.logoutRequested)):
                state.routes.removeAll()
                state.syncChildStatesWithRoutes()
                return .none

            case .detail, .settings:
                return .none
            }
        }
        .ifLet(\.detail, action: \.detail) {
            DetailReducer()
        }
        .ifLet(\.settings, action: \.settings) {
            SettingsReducer()
        }
    }
}

struct HomeView: View {
    @Bindable var store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack(path: $store.routes) {
            List {
                ForEach(store.items) { item in
                    Button {
                        store.send(.itemTapped(item))
                    } label: {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                Button {
                    store.send(.settingsButtonTapped)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .detail:
                    if let detailStore = store.scope(
                        state: \.detail,
                        action: \.detail
                    ) {
                        DetailView(store: detailStore)
                    }

                case .settings:
                    if let settingsStore = store.scope(
                        state: \.settings,
                        action: \.settings
                    ) {
                        SettingsView(store: settingsStore)
                    }
                }
            }
        }
    }
}

// MARK: - 2️⃣ Detail Feature (Child)

@Reducer
struct DetailReducer {
    @ObservableState
    struct State: Equatable {
        let item: Item
        var isLoading = false
        var details: String?
    }

    enum Action {
        case onAppear
        case settingsButtonTapped
        case detailsResponse(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [item = state.item] send in
                    try await Task.sleep(for: .seconds(1))
                    await send(.detailsResponse("Details for \(item.name)"))
                }

            case .settingsButtonTapped:
                // Parent가 처리 (HomeReducer에서 child action으로 받음)
                return .none

            case .detailsResponse(let details):
                state.isLoading = false
                state.details = details
                return .none
            }
        }
    }
}

struct DetailView: View {
    let store: StoreOf<DetailReducer>

    var body: some View {
        VStack(spacing: 20) {
            Text(store.item.name)
                .font(.largeTitle)

            if store.isLoading {
                ProgressView()
            } else if let details = store.details {
                Text(details)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                store.send(.settingsButtonTapped)
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - 3️⃣ Settings Feature (Child)

@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var notificationsEnabled = true
    }

    enum Action {
        case toggleNotifications
        case logoutButtonTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate {
            case logoutRequested
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications:
                state.notificationsEnabled.toggle()
                return .none

            case .logoutButtonTapped:
                return .send(.delegate(.logoutRequested))

            case .delegate:
                return .none
            }
        }
    }
}

struct SettingsView: View {
    let store: StoreOf<SettingsReducer>

    var body: some View {
        Form {
            Section {
                Toggle("Notifications", isOn: $store.notificationsEnabled.sending(\.toggleNotifications))
            }

            Section {
                Button("Logout") {
                    store.send(.logoutButtonTapped)
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Models

struct Item: Equatable, Identifiable {
    let id: UUID
    let name: String

    static let samples = [
        Item(id: UUID(), name: "Item 1"),
        Item(id: UUID(), name: "Item 2"),
        Item(id: UUID(), name: "Item 3")
    ]
}

// MARK: - Preview

#Preview {
    HomeView(
        store: Store(
            initialState: HomeReducer.State()
        ) {
            HomeReducer()
        }
    )
}
