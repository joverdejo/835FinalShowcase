//
//  generated_data.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/31/21.
//

import Foundation
import UIKit

public class GeneratedData{
    
    public init() {}
    
    public func showGeneratedData() -> ([Double], [[Double]], [[Int]]){
        // Do any additional setup after loading the view.
        // 0. build mesh
        let (mesh_obj, el_pos) = create(n_el: 16, h0:0.1, shape: "circle")
        // extract node, element, alpha
        let pts = mesh_obj["node"] as! [[Double]]
        let tri = mesh_obj["element"] as! [[Int]]
        
        // 1. problem setup
        let anomaly : [[String: Double]] = [["x": Double(0.5), "y": Double(0.5), "d": Double(0.1), "perm": Double(10.0)]]
        let mesh_new = set_perm(mesh:mesh_obj,anomaly: anomaly, background:1.0)
        var delta_perm : [Double] = []
        let (a,b) = (mesh_new["perm"] as! [Double], mesh_obj["perm"] as! [Double])
        
        for (i,j) in zip(a,b){
            delta_perm.append(i-j)
        }
        
        // 2. FEM forward simulations
        // setup EIT scan conditions
        let (el_dist, step) = (1, 1)
        let ex_mat = eit_scan_lines(ne: 16, dist: el_dist)
        
        // calculate simulated data
        let fwd = Forward(mesh: mesh_obj as! NSMutableDictionary, el_pos: el_pos)
        let f0 = fwd.solve_eit(ex_mat:ex_mat, step:step, perm:mesh_obj["perm"] as! [Double])
        let f1 = fwd.solve_eit(ex_mat:ex_mat, step:step, perm:mesh_new["perm"] as! [Double])
        
        // 3. naive inverse solver using back-projection
        let eit = BP(mesh: mesh_obj as! NSMutableDictionary, el_pos:el_pos, ex_mat:ex_mat, step:1, parser:"std")
        eit.setup(weight:"none")
 
        let ds : [Double] = eit.solve(v1: f1["v"] as! [Double], v0: f0["v"] as! [Double])
        
        return (ds,pts,tri)
    }
    
    public func generatedMesh(n_el:Int) -> (BP, [[Double]], [[Int]]){
        // Do any additional setup after loading the view.
        // 0. build mesh
        let (mesh_obj, el_pos) = create(n_el: n_el, h0:0.1, shape:"circle")
        // extract node, element, alpha
        let pts = mesh_obj["node"] as! [[Double]]
        let tri = mesh_obj["element"] as! [[Int]]
        // setup EIT scan conditions
        // adjacent stimulation (el_dist=1), adjacent measures (step=1)
        let (el_dist, step) = (1, 1)
        let ex_mat = eit_scan_lines(ne: n_el, dist: el_dist)
        // calculate simulated data
        // 3. naive inverse solver using back-projection        
        let eit = BP(mesh: mesh_obj as! NSMutableDictionary, el_pos:el_pos, ex_mat:ex_mat, step:step, parser:"std")
        eit.setup(weight:"none")
        return (eit,pts,tri)
    }
}
