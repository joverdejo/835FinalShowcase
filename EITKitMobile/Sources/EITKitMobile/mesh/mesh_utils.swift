//
//  mesh_utils.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/17/21.
//

import Foundation
import Surge

public func dist(p:[[Double]]) -> [Double]{
    /* distances to origin of nodes. '3D', 'ND' compatible
     
     Parameters
     ----------
     p : array_like
     points in 2D, 3D. i.e., in 3D
     [[x, y, z],
     [2, 3, 3],
     ...
     [1, 2, 1]]
     
     Returns
     -------
     array_like
     distances of points to origin
     */
    //Josh: Not sure on this
    //    if p.ndim == 1{
    //        d = np.sqrt(np.sum(p ** 2))
    //    }
    //    else{
    //        d = np.sqrt(np.sum(p ** 2, axis=1))
    //    }
    var temp = Double(0.0)
    var d : [Double] = []
    for i in p{
        for n in i{
            temp += pow(n, 2.0)
        }
        d.append(sqrt(temp))
        temp = 0.0
    }
    return d
}

func edge_project(pts: [[Double]], fd : ([[Double]],[Double]?,[Double]?) -> [Double], h0:Double=1.0, shape: String) -> [[Double]] {
    //    project points back on edge
    let g_vec = edge_grad(p: pts, fd: fd, h0: h0, shape:shape)
    var final : [[Double]] = []
    var temp : [Double] = []
    for (r1,r2) in zip(pts,g_vec){
        for (x,y) in zip(r1,r2){
            temp.append(x-y)
        }
        final.append(temp)
        temp = []
    }
    return final
    //return pts - g_vec
}

func edge_grad(p: [[Double]], fd : ([[Double]],[Double]?,[Double]?) -> [Double], h0:Double=1.0, shape: String)-> [[Double]]{
    /*
     project points back on the boundary (where fd=0) using numerical gradient
     3D, ND compatible
     
     Parameters
     ----------
     p : array_like
     points on 2D, 3D
     fd : str
     function handler of distances
     h0 : Double
     minimal distance
     
     Returns
     -------
     array_like
     gradients of points on the boundary
     
     Note
     ----
     numerical gradient:
     f'_x = (f(p+delta_x) - f(p)) / delta_x
     f'_y = (f(p+delta_y) - f(p)) / delta_y
     f'_z = (f(p+delta_z) - f(p)) / delta_z
     
     you should specify h0 according to your actual mesh size
     */
    let d_eps = 1e-8 * h0
    let r = shape == "circle" ? [1.0] : [1.0, 2.0]
    let d = fd(p,[],r)
    // calculate the gradient of each axis
    let ndim = p[0].count
    var pts_xyz : [[Double]] = []
    for pt in p{
        pts_xyz.append(pt)
        pts_xyz.append(pt)
    }
    var delta_xyz : [[Double]] = []
    var deps_xyz : [[Double]] = []
    let id = identityMatrix(size: ndim)
    let id2 = identityMatrix(size: ndim, c:d_eps)
    for _ in 0..<p.count{
        delta_xyz.append(contentsOf: id)
        deps_xyz.append(contentsOf: id2)
    }
    var summed : [[Double]] = []
    for (i,j) in zip(pts_xyz,deps_xyz){
        summed.append(Surge.add(i,j))
    }
    //Josh: Assumption of 2D
    let dists = fd(summed,[],r)
    var d2 : [Double] = []
    for i in d{
        d2.append(i)
        d2.append(i)
    }
    var g : [[Double]] = []
    var gsq : [Double] = []
    var temp : [Double] = []
    var tempsq : Double = 0
    var s = 0
    var g_num : [[Double]] = []
    for (i,j) in zip(dists,d2){
        temp.append((i-j)/d_eps)
        tempsq += pow((i-j)/d_eps,2)
        s += 1
        if s == 2{
            g.append(temp)
            gsq.append(tempsq)
            temp = []
            tempsq = 0
            s = 0
        }
    }
    var n = 0
    for (temp,tempsq) in zip(g,gsq){
        g_num.append([(temp[0]/tempsq)*d[n],(temp[1]/tempsq)*d[n]])
        n += 1
    }
    return g_num
}

//from rosettacode.com
func identityMatrix(size: Int,c:Double=1.0) -> [[Double]] {
    return (0..<size).map({i in
        return (0..<size).map({ $0 == i ? 1.0*c : 0.0})
    })
}

func check_order(no2xy : [[Double]], el2no : [[Int]]) -> [[Int]]{
    /*
     loop over all elements, calculate the Area of Elements (aoe)
     if AOE > 0, then the order of element is correct
     if AOE < 0, reorder the element
     
     Parameters
     ----------
     no2xy : NDArray
     Nx2 ndarray, (x,y) locations for points
     el2no : NDArray
     Mx3 ndarray, elements (triangles) connectivity
     
     Returns
     -------
     NDArray
     ae, area of each element
     
     Notes
     -----
     tetrahedron should be parsed that the sign of volume is [1, -1, 1, -1]
     */
    let (el_num, n_vertices) = (el2no.count,el2no[0].count)
    // select ae function
    var _fn : ([[Double]]) -> Double
    // Josh: Was an if, elif
    if n_vertices == 3{
        _fn = tri_area
    }
    else{
        _fn = tet_volume
    }
    // calculate ae and re-order tri if necessary
    var new_el2no = el2no
    for ei in 0..<el_num{
        let no = new_el2no[ei]
        var xy : [[Double]] = []
        for i in no{
            xy.append(no2xy[i])
        }
        let v = _fn(xy)
        
        if v < 0{
            (new_el2no[ei][1], new_el2no[ei][2]) = (new_el2no[ei][2], new_el2no[ei][1])
        }
    }
    return new_el2no
}

func tri_area(xy : [[Double]]) -> Double{
    /*
     return area of a triangle, given its tri-coordinates xy
     
     Parameters
     ----------
     xy : NDArray
     (x,y) of nodes 1,2,3 given in counterclockwise manner
     
     Returns
     -------
     Double
     area of this element
     */
    var s : [[Double]] = []
    s = [[xy[2][0] - xy[1][0],xy[2][1] - xy[1][1]],[xy[0][0] - xy[2][0],xy[0][1] - xy[2][1]]]
    let a_tot = 0.50 * det2x2(s1: s[0], s2: s[1])
    // (should be positive if tri-points are counter-clockwise)
    return a_tot
}

func det2x2(s1: [Double], s2: [Double]) -> Double{
    // Calculate the determinant of a 2x2 matrix
    return Double(s1[0] * s2[1] - s1[1] * s2[0])
}

func tet_volume(xyz : [[Double]]) -> Double{
    //calculate the volume of tetrahedron
    var s : [[Double]] = []
    for (x,y) in zip([2,3,0],[1,3,2]){
        s.append(Surge.sub(xyz[x].map { Double($0) },xyz[y].map { Double($0) }))
    }
    let v_tot = (1.0 / 6.0) * Surge.det(Matrix(s))!
    return v_tot
}
