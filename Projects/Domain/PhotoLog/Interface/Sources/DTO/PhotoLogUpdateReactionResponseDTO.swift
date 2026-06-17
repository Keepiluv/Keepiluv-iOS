//
//  PhotoLogUpdateReactionResponseDTO.swift
//  DomainPhotoLogInterface
//
//  Created by 정지훈 on 2/11/26.
//

import Foundation

public struct PhotoLogUpdateReactionResponseDTO: Decodable {
    public let photologId: Int64
    public let reaction: String

    public init(photologId: Int64, reaction: String) {
        self.photologId = photologId
        self.reaction = reaction
    }
}
