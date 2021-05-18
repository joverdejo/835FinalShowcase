//
//  utils.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/7/21.
//

import Foundation


public func eit_scan_lines(ne: Int=16, dist:Int=1) -> [[Int]]{
    /*
    generate scan matrix

    Parameters
    ----------
    ne: int
        number of electrodes
    dist: int
        distance between A and B (default=1)

    Returns
    -------
    ex_mat: NDArray
        stimulation matrix

    Notes
    -----
    in the scan of EIT (or stimulation matrix), we use 4-electrodes
    mode, where A, B are used as positive and negative stimulation
    electrodes and M, N are used as voltage measurements

    1 (A) for positive current injection,
    -1 (B) for negative current sink

    dist is the distance (number of electrodes) of A to B
    in 'adjacent' mode, dist=1, in 'apposition' mode, dist=ne/2

    Examples
    --------
    # let the number of electrodes, ne=16

    if mode=='neighbore':
        ex_mat = eit_scan_lines()
    elif mode=='apposition':
        ex_mat = eit_scan_lines(dist=8)

    WARNING
    -------
    ex_mat is a local index, where it is ranged from 0...15, within the range
    of the number of electrodes. In FEM applications, you should convert ex_mat
    to global index using the (global) el_pos parameters.
    */
    var ex : [[Int]] = []
    for i in 0..<ne{
    ex.append([i, (i + dist) % ne])
    }
    return ex
}


public func mesh_setup(_ n: Int, shape:String) -> (BP,[[Double]],[[Int]]){
        let (mesh_obj, el_pos) = create(n_el: n, h0:0.1, shape:shape)
        let pts = mesh_obj["node"] as! [[Double]]
        let tri = mesh_obj["element"] as! [[Int]]
        let (el_dist, step) = (1, 1)
        let ex_mat = eit_scan_lines(ne: n, dist: el_dist)
        print("past scan")
        print("solved eit")
        let eit = BP(mesh: mesh_obj as! NSMutableDictionary, el_pos:el_pos, ex_mat:ex_mat, step:step, parser:"std")
        print("setup")
        eit.setup(weight:"none")
        print("setup done")
    
    return (eit,pts,tri)
}
