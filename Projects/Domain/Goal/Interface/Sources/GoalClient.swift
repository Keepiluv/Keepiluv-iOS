//
//  GoalClient.swift
//  DomainGoalInt64erface
//
//  Created by 정지훈 on 1/26/26.
//

import Foundation

import ComposableArchitecture
import CoreNetworkInterface

/// 목표 정보를 조회하기 위한 Client입니다.
///
/// ## 사용 예시
/// ```swift
/// @Dependency(\.goalClient) var goalClient
/// let goalList = try await goalClient.fetchGoals("2026-02-06")
/// ```
public struct GoalClient {
    public var fetchGoals: (String) async throws -> GoalList
    public var createGoal: (GoalCreateRequestDTO) async throws -> Goal
    public var fetchGoalDetail: (String, Int64) async throws -> GoalDetail
    public var fetchGoalById: (Int64) async throws -> Goal
    public var fetchGoalEditList: (String) async throws -> [Goal]
    public var updateGoal: (Int64, GoalUpdateRequestDTO) async throws -> Goal
    public var deleteGoal: (Int64) async throws -> Void
    public var completeGoal: (Int64) async throws -> GoalCompleteResponseDTO
    public var pokePartner: (Int64, PokeRequestDTO) async throws -> Void
    
    /// 목표 조회 클로저를 주입하여 GoalClient를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let client = GoalClient(
    ///     fetchGoals: { _ in
    ///         return .init(hasEverRegisteredGoal: false, goals: [])
    ///     }
    /// )
    /// ```
    public init(
        fetchGoals: @escaping (String) async throws -> GoalList,
        createGoal: @escaping (GoalCreateRequestDTO) async throws -> Goal,
        fetchGoalDetail: @escaping (String, Int64) async throws -> GoalDetail,
        fetchGoalById: @escaping (Int64) async throws -> Goal,
        fetchGoalEditList: @escaping (String) async throws -> [Goal],
        updateGoal: @escaping (Int64, GoalUpdateRequestDTO) async throws -> Goal,
        deleteGoal: @escaping (Int64) async throws -> Void,
        completeGoal: @escaping (Int64) async throws -> GoalCompleteResponseDTO,
        pokePartner: @escaping (Int64, PokeRequestDTO) async throws -> Void
    ) {
        self.fetchGoals = fetchGoals
        self.createGoal = createGoal
        self.fetchGoalDetail = fetchGoalDetail
        self.fetchGoalById = fetchGoalById
        self.fetchGoalEditList = fetchGoalEditList
        self.updateGoal = updateGoal
        self.deleteGoal = deleteGoal
        self.completeGoal = completeGoal
        self.pokePartner = pokePartner
    }
}

extension GoalClient: TestDependencyKey {
    public static var testValue: GoalClient = Self(
        fetchGoals: { _ in
            assertionFailure("GoalClient.fetchGoals이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
            return .init(hasEverRegisteredGoal: false, goals: [])
        },
        createGoal: { _ in
            assertionFailure("GoalClient.createGoal이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
            let trashVerification = Goal.Verification(
                isCompleted: false,
                imageURL: nil,
                emoji: nil
            )

            return .init(
                id: 1,
                goalIcon: "ICON_DEFAULT",
                title: "",
                myVerification: trashVerification,
                yourVerification: trashVerification
            )
        },
        fetchGoalDetail: { _, _ in
            assertionFailure("GoalClient.fetchGoalDetail이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
            return .init(partnerNickname: "", completedGoals: [])
        },
        fetchGoalById: { _ in
            assertionFailure("GoalClient.fetchGoalById이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
            let trashVerification = Goal.Verification(
                isCompleted: false,
                imageURL: nil,
                emoji: nil
            )

            return .init(
                id: 1,
                goalIcon: "ICON_DEFAULT",
                title: "",
                myVerification: trashVerification,
                yourVerification: trashVerification
            )
        },
        fetchGoalEditList: { _ in
            
            return []
        },
        updateGoal: { _, _ in
            assertionFailure("GoalClient.updateGoal이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
            let trashVerification = Goal.Verification(
                isCompleted: false,
                imageURL: nil,
                emoji: nil
            )

            return .init(
                id: 1,
                goalIcon: "ICON_DEFAULT",
                title: "",
                myVerification: trashVerification,
                yourVerification: trashVerification
            )
        },
        deleteGoal: { _ in
            assertionFailure("GoalClient.deleteGoal이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
        },
        completeGoal: { _ in
            assertionFailure("GoalClient.completeGoal이 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
            return GoalCompleteResponseDTO(
                goalId: 1,
                goalName: "",
                goalStatus: "COMPLETED",
                completedAt: ""
            )
        },
        pokePartner: { _, _ in
            assertionFailure("GoalClient.pokePartner가 구현되지 않았습니다. withDependencies로 mock을 주입하세요.")
        }
    )
    
    public static var previewValue: GoalClient = Self(
        fetchGoals: { _ in
            .init(
                hasEverRegisteredGoal: true,
                goals: [
                    Goal(
                        id: 1,
                        goalIcon: "ICON_EXERCISE",
                        title: "운동하기",
                        myVerification: .init(
                            photologId: 101,
                            isCompleted: true,
                            imageURL: "https://picsum.photos/400",
                            emoji: nil
                        ),
                        yourVerification: .init(
                            photologId: 201,
                            isCompleted: true,
                            imageURL: "https://picsum.photos/400",
                            emoji: "LOVE"
                        ),
                        repeatCycle: .daily,
                        repeatCount: 1,
                        startDate: "2026-02-01",
                        endDate: nil
                    ),
                    Goal(
                        id: 2,
                        goalIcon: "ICON_BOOK",
                        title: "독서하기",
                        myVerification: .init(
                            photologId: nil,
                            isCompleted: false,
                            imageURL: nil,
                            emoji: nil
                        ),
                        yourVerification: .init(
                            photologId: 202,
                            isCompleted: true,
                            imageURL: "https://picsum.photos/400",
                            emoji: nil
                        ),
                        repeatCycle: .weekly,
                        repeatCount: 3,
                        startDate: "2026-01-01",
                        endDate: "2026-12-31"
                    )
                ]
            )
        },
        createGoal: { _ in
            Goal(
                id: 999,
                goalIcon: "ICON_DEFAULT",
                title: "새 목표",
                myVerification: .init(isCompleted: false, imageURL: nil, emoji: nil),
                yourVerification: .init(isCompleted: false, imageURL: nil, emoji: nil)
            )
        },
        fetchGoalDetail: { _, _ in
            .init(
                partnerNickname: "민정",
                completedGoals: [
                    .init(
                        goalName: "운동하기",
                        myPhotoLog: .init(
                            goalId: 1,
                            photologId: 1001,
                            goalName: "운동하기",
                            owner: .mySelf,
                            imageUrl: "https://picsum.photos/400",
                            comment: "오늘도성공",
                            reaction: nil,
                            createdAt: "2026-02-22T08:00:00Z"
                        ),
                        yourPhotoLog: .init(
                            goalId: 1,
                            photologId: 2001,
                            goalName: "운동하기",
                            owner: .you,
                            imageUrl: "https://picsum.photos/400",
                            comment: "나도완료!",
                            reaction: "LOVE",
                            createdAt: "2026-02-22T09:00:00Z"
                        )
                    ),
                    .init(
                        goalName: "독서하기",
                        myPhotoLog: .init(
                            goalId: 2,
                            photologId: 1002,
                            goalName: "독서하기",
                            owner: .mySelf,
                            imageUrl: "https://picsum.photos/400",
                            comment: "20페이지 읽음",
                            reaction: nil,
                            createdAt: "2026-02-21T10:00:00Z"
                        ),
                        yourPhotoLog: nil
                    )
                ]
            )
        },
        fetchGoalById: { id in
            Goal(
                id: id,
                goalIcon: "ICON_DEFAULT",
                title: "미리보기 목표",
                myVerification: .init(isCompleted: false, imageURL: nil, emoji: nil),
                yourVerification: .init(isCompleted: false, imageURL: nil, emoji: nil)
            )
        },
        fetchGoalEditList: { _ in
            [
                Goal(
                    id: 1,
                    goalIcon: "ICON_EXERCISE",
                    title: "운동하기",
                    myVerification: .init(isCompleted: false, imageURL: nil, emoji: nil),
                    yourVerification: .init(isCompleted: false, imageURL: nil, emoji: nil)
                )
            ]
        },
        updateGoal: { id, _ in
            Goal(
                id: id,
                goalIcon: "ICON_DEFAULT",
                title: "수정된 목표",
                myVerification: .init(isCompleted: false, imageURL: nil, emoji: nil),
                yourVerification: .init(isCompleted: false, imageURL: nil, emoji: nil)
            )
        },
        deleteGoal: { _ in
            return
        },
        completeGoal: { id in
            GoalCompleteResponseDTO(
                goalId: id,
                goalName: "미리보기 목표",
                goalStatus: "COMPLETED",
                completedAt: "2026-02-22T00:00:00Z"
            )
        },
        pokePartner: { _, _ in
            return
        }
    )
}

extension DependencyValues {
    public var goalClient: GoalClient {
        get { self[GoalClient.self] }
        set { self[GoalClient.self] = newValue }
    }
}
