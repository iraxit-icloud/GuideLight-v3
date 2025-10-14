//
//  Extensions.swift
//  GuideLight v3
//
//  Created by Indraneel Rakshit on 10/13/25.
//

import SceneKit

extension SCNVector3: Equatable {
    public static func == (lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
}
