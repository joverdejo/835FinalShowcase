//
//  read_text_file.swift
//  EITViz
//
//  Created by Joshua Verdejo on 2/1/21.
//

import Foundation
import UIKit

public class ReadTextFile{
    public init() {}
    public func readText() -> ([[Double]],[[Int]],[[Double]]){

        // Read the contents of the specified file
        // Josh TODO: make filename a variable
        let path = Bundle.main.path(forResource: "example_data_50khz.txt", ofType: nil)!
        let content = try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
        
        // Split the file into separate lines
        let lines = content.split(separator:"\n")
        // Iterate over each line and print the line
        var temp : [Double] = []
        var origin : [Double] = []
        var frames : [[Double]] = []
        var inOrigin = true
        for line in lines {
            if line.contains("origin"){
               continue
            }
            if inOrigin{
                if line.contains("frame"){
                    inOrigin = false
                    continue
                }
                else{
                    origin.append(Double(line)!)
                }
            }
            else if line.contains("frame"){
                frames.append(temp)
                temp = []
            }
            else{
                if line == "end of file"{
                    frames.append(temp)
                    break
                }
                else{
                    temp.append(Double(line)!)
                }
            }
        }
        // Do any additional setup after loading the view.
        // 0. build mesh
        let (mesh_obj, el_pos) = create(n_el: 32, h0:0.1, shape: "circle")
        // extract node, element, alpha
        let pts = mesh_obj["node"] as! [[Double]]
        let tri = mesh_obj["element"] as! [[Int]]

        print("past create, number of tri:", tri.count)

        let (el_dist, step) = (1, 1)
        let ex_mat = eit_scan_lines(ne: 32, dist: el_dist)


        let eit = BP(mesh: mesh_obj as! NSMutableDictionary, el_pos:el_pos, ex_mat:ex_mat, step:step, parser:"std")
        eit.setup(weight:"none")
        
        
        var ds_all : [[Double]] = []
        for frame in frames{
            ds_all.append(eit.solve(v1: frame, v0: origin))
        }
        print("past solve")
        return (pts,tri,ds_all)
        


    }
}
