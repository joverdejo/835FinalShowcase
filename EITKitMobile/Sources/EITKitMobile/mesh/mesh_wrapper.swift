//
//  mesh_wrapper.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/20/21.
//

import Foundation

public func create(n_el:Int=16, fd:  @escaping ([[Double]],[Double]?,[Double]?) -> [Double] = circle, fh:@escaping ([[Double]]) -> [Double]=area_uniform, h0:Double=0.1, p_fix:[[Double]]=[], bbox:[[Double]]=[], shape: String) -> (NSDictionary,[Int]){
    /*
    Generating 2D/3D meshes using distmesh (pyEIT built-in)

    Parameters
    ----------
    n_el: int
        number of electrodes (point-type electrode)
    fd: function
        distance function (circle in 2D, ball in 3D)
    fh: function
        mesh size quality control function
    p_fix: NDArray
        fixed points
    bbox: NDArray
        bounding box
    h0: Double
        initial mesh size, default=0.1

    Returns
    -------
    mesh_obj: dict
        {'element', 'node', 'perm'}
    */
    // infer dim
    var fd2 = fd
    if (shape == "circle"){
        fd2 = circle
    }
    else if (shape == "ellipse"){
        fd2 = ellipse
    }
    var new_bbox = bbox
    if bbox.count == 0{
        new_bbox = [[-1, -1], [1, 1]]
    }
    let n_dim = new_bbox[0].count
    if n_dim != 2 && n_dim != 3{
        print("TypeError: distmesh only supports 2D or 3D")
    }
    if new_bbox.count != 2{
        print("TypeError: please specify lower and upper bound of bbox")
    }
    var new_pfix = p_fix
    if p_fix.count == 0{
        if n_dim == 2{
            new_pfix = fix_points_fd(fd: fd2, n_el: n_el, shape: shape)
        }
    }

    // 1. build mesh
    var (p, t) = build(fd:fd, fh:fh, pfix:new_pfix, bbox:new_bbox, h0:h0, shape:shape)
    // 2. check whether t is counter-clock-wise, otherwise reshape it
    t = check_order(no2xy: p, el2no: t)
    // 3. generate electrodes, the same as p_fix (top n_el)
    let el_pos = Array(0..<n_el)
    // 4. init uniform element permittivity (sigma)
    let perm = [Double](repeating: 1.0, count: t.count)
    // 5. build output structure
    let mesh : NSMutableDictionary = ["element": t, "node": p, "perm": perm]
    return (mesh, el_pos)
}

public func set_perm(mesh: NSDictionary, anomaly: [[String:Double]]=[], background:Double = -1.0) -> NSMutableDictionary{
    /*
     wrapper for pyEIT interface

    Note
    ----
    update permittivity of mesh, if specified.

    Parameters
    ----------
    mesh: dict
        mesh structure
    anomaly: dict, optional
        anomaly is a dictionary (or arrays of dictionary) contains,
        {'x': val, 'y': val, 'd': val, 'perm': val}
        all permittivity on triangles whose distance to (x,y) are less than (d)
        will be replaced with a new value, 'perm' may be a complex value.
    background: Double, optional
        set background permittivity

    Returns
    -------
    mesh_obj: dict
        updated mesh structure, {'element', 'node', 'perm'}
    */
    let pts = mesh["element"] as! [[Int]]
    let tri = mesh["node"] as! [[Double]]
    var perm = mesh["perm"] as! [Double]
    var tri_centers : [[Double]] = []
    for row in pts{
        let a = tri[row[0]]
        let b = tri[row[1]]
        let c = tri[row[2]]
        tri_centers.append([(a[0]+b[0]+c[0])/3,(a[1]+b[1]+c[1])/3])
    }

    let n = perm.count

    // reset background if needed
        if background != -1.0{
        perm = [Double](repeating: background, count: n)
        }

    // assign anomaly values (for elements in regions)
        var idx : [Bool] = []
        var tri_xyz : [Double] = []
        if !(anomaly.isEmpty){
        for (attr) in anomaly{
            let d = attr["d"]
            // find elements whose distance to (cx,cy) is smaller than d
            if (attr["z"] != nil){
            tri_xyz = tri_centers.map({sqrt(pow($0[0]-attr["x"]!,2.0)+pow($0[1]-attr["y"]!,2.0)+pow($0[2]-attr["z"]!,2.0))})
            }
            let tri_xy : [Double] = tri_centers.map({sqrt(pow($0[0]-attr["x"]!,2.0)+pow($0[1]-attr["y"]!,2.0))})
            if (attr["z"] != nil){
                idx = tri_xyz.map({$0<d!})
            }
            else{
                idx = tri_xy.map({$0<d!})
            }
            // update permittivity within indices
            for (i,n) in idx.enumerated(){
                if n{
                    perm[i] = attr["perm"]!
                }
            }
    }
        }
        let mesh_new : NSMutableDictionary = ["node": tri, "element": pts, "perm": perm]
    return mesh_new
        }
