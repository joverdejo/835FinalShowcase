//
//  arduino_comms.swift
//  EITViz
//
//  Created by Joshua Verdejo on 2/18/21.
//

import Foundation

public func parseFrame(_ input: String) -> [Double]{
    let input_st = String(input.enumerated().map { $0 > 0 && $0 % 6 == 0 ? [" ", $1] : [$1]}.joined())
    let input_split = input_st.components(separatedBy: " ")
    var frame = [Double]()
    for x in input_split{
        let val = String(x)
        if !(val == "origin" || val == "framef" || val == "framei" ){
            frame.append(Double(val)!)
        }
    }
    return frame
}

