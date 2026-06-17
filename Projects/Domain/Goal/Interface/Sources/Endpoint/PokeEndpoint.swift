//
//  PokeEndpoint.swift
//  DomainGoalInterface
//
//  Created by Jiyong on 02/21/26.
//

import CoreNetworkInterface
import Foundation

/// 찌르기 관련 API 엔드포인트입니다.
public enum PokeEndpoint: Endpoint {
    /// 파트너에게 찌르기
    case poke(goalId: Int64, request: PokeRequestDTO)
}

extension PokeEndpoint {
    public var path: String {
        switch self {
        case let .poke(goalId, _):
            return "/api/v1/pokes/goals/\(goalId)"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .poke:
            return .post
        }
    }

    public var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }

    public var query: [URLQueryItem]? {
        nil
    }

    public var body: (any Encodable)? {
        switch self {
        case let .poke(_, request):
            return request
        }
    }

    public var requiresAuth: Bool { true }
    public var featureTag: FeatureTag { .poke }
}
