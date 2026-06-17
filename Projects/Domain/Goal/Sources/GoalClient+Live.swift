//
//  GoalClient+Live.swift
//  DomainGoalInterface
//
//  Created by 정지훈 on 1/26/26.
//

import ComposableArchitecture
import CoreNetworkInterface
import DomainGoalInterface

extension GoalClient: @retroactive DependencyKey {
    public static let liveValue: GoalClient = .live()
    
    // GoalClient의 기본 구현입니다.
    // swiftlint:disable:next function_body_length
    static func live() -> GoalClient {
        @Dependency(\.networkClient) var networkClient

        return .init(
            fetchGoals: { date in
                do {
                    let response: GoalListResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.fetchGoalList(date: date)
                    )
                    return response.toEntity(response)
                } catch {
                    throw error
                }
            },
            createGoal: { request in
                do {
                    let response: GoalCreateResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.createGoal(request)
                    )
                    return response.toEntity(response)
                } catch {
                    throw error
                }
            },
            fetchGoalDetail: { date, goalId in
                do {
                    let response: DetailGoalListResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.fetchGoalDetail(date: date, goalId: goalId)
                    )
                    return response.toEntity(response)
                } catch {
                    throw error
                }
            },
            fetchGoalById: { goalId in
                do {
                    let response: GoalCreateResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.fetchGoalById(goalId: goalId)
                    )
                    
                    return response.toEntity(response)
                } catch {
                    throw error
                }
            },
            fetchGoalEditList: { date in
                do {
                    let response: GoalEditListResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.fetchGoalEditList(date: date)
                    )
                    
                    return response.toEntity(response)
                } catch {
                    throw error
                }
            },
            updateGoal: { goalId, request in
                do {
                    let response: GoalCreateResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.updateGoal(goalId: goalId, request)
                    )
                    return response.toEntity(response)
                } catch {
                    throw error
                }
            },
            deleteGoal: { goalId in
                do {
                    let _: EmptyResponse = try await networkClient.request(
                        endpoint: GoalEndpoint.deleteGoal(goalId: goalId)
                    )
                } catch {
                    throw error
                }
            },
            completeGoal: { goalId in
                do {
                    let response: GoalCompleteResponseDTO = try await networkClient.request(
                        endpoint: GoalEndpoint.completeGoal(goalId: goalId)
                    )
                    return response
                } catch {
                    throw error
                }
            },
            pokePartner: { goalId, requestDTO in
                do {
                    let _: EmptyResponse = try await networkClient.request(
                        endpoint: PokeEndpoint.poke(
                            goalId: goalId,
                            request: requestDTO
                        )
                    )
                } catch {
                    throw error
                }
            }
        )
    }
}

private struct EmptyResponse: Decodable {}
