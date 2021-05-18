//
//  bp.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/7/21.
//

import Foundation
import Surge

public class BP: EitBase{
    // A naive inversion of (Euclidean) back projection.
    public func setup(weight: String="none"){
        // setup BP
        self.params = ["weight": weight]

        // BP: H is the smear matrix B, which must be transposed for node imaging.
        var temp : [[Double]] = []
        for row in Surge.transpose(Matrix(self.H)){
            temp.append(Array(row))
        }
        self.H = temp
    }
    
}
