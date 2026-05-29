//
//  PokeRequestDTO.swift
//  DomainGoalInterface
//
//  Created by 정지훈 on 5/28/26.
//

import Foundation

/// 목표를 찌르기 위한 요청 DTO입니다.
public struct PokeRequestDTO: Encodable {
    public let date: String
    
    public init(date: String) {
        self.date = date
    }
}
