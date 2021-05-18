//
//  Point.swift
//  DelaunayTriangulationSwift
//
//  Created by Alex Littlejohn on 2016/01/08.
//  Copyright © 2016 zero. All rights reserved.
//

public struct Point: Hashable {
    
    public let x: Double
    public let y: Double
    public let idx: Int
    
    public init(x: Double, y: Double, idx: Int) {
        self.x = x
        self.y = y
        self.idx = idx
    }
}
