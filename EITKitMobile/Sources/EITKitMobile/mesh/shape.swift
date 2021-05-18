//
//  shape.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/18/21.
//

import Foundation
import Surge


public func circle(pts : [[Double]], pc : [Double]?=[], r:[Double]?=[1.0]) -> [Double]{
    /*
    Distance function for the circle centered at pc = [xc, yc]

    Parameters
    ----------
    pts : array_like
        points on 2D
    pc : array_like, optional
        center of points
    r : Double, optional
        radius

    Returns
    -------
    array_like
        distance of (points - pc) - r

    Note
    ----
    copied and modified from https://github.com/ckhroulev/py_distmesh2d
    */
    var pc2 = pc!
    if pc2.count == 0{
        pc2 = [0, 0]
    }
    var pdiff : [[Double]] = []
    for pt in pts{
        pdiff.append([pt[0]-pc2[0],pt[1]-pc2[1]])
    }
    return  dist(p: pdiff).map({$0 - r![0]})
}

func ellipse(pts : [[Double]], pc : [Double]?=[], ab:[Double]?=[])-> [Double]{
    /*
    Distance function for the ellipse
    centered at pc = [xc, yc], with a, b = [a, b]
    */
    var pc2 = pc
    var ab2 = ab
    if pc!.count == 0{
        pc2 = [0, 0]
    }
    if ab!.count <= 1{
        ab2 = [1.0, 2.0]
    }
    var pdiff : [[Double]] = []
    for pt in pts{
        pdiff.append([(pt[0]-pc2![0])/ab2![0],(pt[1]-pc2![1])/ab2![1]])
    }
    return  dist(p: pdiff).map({$0 - 1.0})
}

func unit_circle(pts: [[Double]])-> [Double]{
    // unit circle at (0,0)
    return circle(pts : pts, r : [1.0])
}

func box_circle(pts: [[Double]])-> [Double]{
    // unit circle at (0.5,0.5) with r=0.5
    return circle(pts:pts, pc: [0.5, 0.5], r: [0.5])
}

func ball(pts : [[Double]], pc : [Double]=[], r:[Double]=[1.0]) -> [Double]{
    /*
    generate balls in 3D (default: unit ball)

    See Also
    --------
    circle : generate circles in 2D
    */
    var pc2 = pc
    if pc2.count == 0{
        pc2 = [0,0,0]
    }
    return circle(pts:pts, pc:pc2, r:r)
}

func unit_ball(pts:[[Double]]) -> [Double]{
    // generate unit ball in 3D
    return ball(pts:pts)
}

func rectangle(pts:[[Double]], p1:[Double]=[], p2:[Double]=[]) -> [Double]{
    /*
    Distance function for the rectangle p1=[x1, y1] and p2=[x2, y2]

    Note
    ----
    p1 should be bottom-left, p2 should be top-right
    if p in rect(p1, p2), then (p-p1)_x and (p-p2)_x must have opposite sign

    Parameters
    ----------
    pts : array_like
    p1 : array_like, optional
        bottom left coordinates
    p2 : array_like, optional
        top tight coordinates

    Returns
    -------
    array_like
        distance
 */
    var (pt1, pt2) = (p1,p2)
    if p1.count == 0{
        pt1 = [0, 0]
    }
    if p2.count == 0{
        pt2 = [1, 1]
    }

    var pd1 : [[Double]] = []
    var pd2 : [[Double]] = []
    for pt in pts{
        pd1.append([pt[0]-pt1[0],pt[1]-pt1[1]])
        pd2.append([pt[0]-pt2[0],pt[1]-pt2[1]])
    }
    var pd_left, pd_right : [Double]
    (pd_left, pd_right) = ([],[])
    for (r1,r2) in zip(pd1,pd2){
        pd_left.append(-min(r1))
        pd_right.append(max(r2))
    }
    var final : [Double] = []
    for (i,j) in zip(pd_left, pd_right){
        final.append(min(i,j))
    }
    return final
}

func fix_points_fd(fd: ([[Double]],[Double]?,[Double]?) -> [Double], n_el:Int=16, pc:[Double]=[], shape: String) -> [[Double]]{
    /*
    return fixed and uniformly distributed points on
    fd with equally distributed angles

    Parameters
    ----------
    fd : distance function
    pc : array_like, optional
        center of points
    n_el : number of electrodes, optional

    Returns
    -------
    array_like
        coordinates of fixed points
    */
    var pc2 = pc
    if pc.count == 0{
        pc2 = [0, 0]
    }
    // initialize points
    let r : Double = 10.0
    var run : [Double] = []
    for i in 0..<n_el{
        run.append(Double(i))
    }
    let theta = 2.0 * Double.pi * run / Double(n_el)
    // add offset of theta
    var p_fix,pts,pts_new, ptcheck: [[Double]]
    (p_fix,pts,pts_new, ptcheck) = ([],[],[],[])
    for th in theta{
        let v = [-r * cos(th), r * sin(th)]
        p_fix.append(v)
        pts.append([v[0]+pc2[0],v[1]+pc2[1]])
        pts_new.append([Double.infinity,Double.infinity])
    }
    // project back on edges
    var c = false
    let d_eps : Double = 0.1
    let max_iter = 10
    var niter = 0
    while !c{
        // project on fd
        pts_new = edge_project(pts: pts, fd: fd, shape: shape)
        // project on rays
        let r = dist(p: pts_new)
        pts_new = []
        for (ri, ti) in zip(r, theta){
            pts_new.append([-ri * cos(ti), ri * sin(ti)])
        }
        // check convergence
        for (pt,pn) in zip(pts,pts_new){
            ptcheck.append([pn[0]-pt[0],pn[1]-pt[1]])
        }
        c = dist(p: ptcheck).reduce(0,+) < d_eps || niter > max_iter
        pts = pts_new
        niter += 1
        ptcheck = []
    }
    return pts_new
}


func dist_diff(d1: [Double], d2:[Double])-> [Double]{
    /*Distance function for the difference of two sets.

    Parameters
    ----------
    d1 : array_like
    d2 : array_like
        distance of two functions

    Returns
    -------
    array_like
        maximum difference

    Note
    ----
    boundary is denoted by d=0
    copied and modified from https://github.com/ckhroulev/py_distmesh2d
    */
    var final : [Double] = []
    for (i,j) in zip(d1, d2){
        final.append(max(i,-j))
    }
    return final
}

func dist_intersect(d1: [Double], d2:[Double])-> [Double]{
    /*Distance function for the intersection of two sets.

    Parameters
    ----------
    d1 : array_like
    d2 : array_like
        distance of two functions

    Returns
    -------
    array_like

    Note
    ----
    boundary is denoted by d=0
    copied and modified from https://github.com/ckhroulev/py_distmesh2d
    */
    var final : [Double] = []
    for (i,j) in zip(d1, d2){
        final.append(max(i,j))
    }
    return final
}


func dist_union(d1: [Double], d2:[Double])-> [Double]{
    /*Distance function for the union of two sets.

    Parameters
    ----------
    d1 : array_like
    d2 : array_like
        distance of two functions

    Returns
    -------
    array_like

    Note
    ----
    boundary is denoted by d=0
    copied and modified from https://github.com/ckhroulev/py_distmesh2d
    */
    var final : [Double] = []
    for (i,j) in zip(d1, d2){
        final.append(min(i,j))
    }
    return final
}

public func area_uniform(p: [[Double]])->[Double]{
    /*uniform mesh distribution

    Parameters
    ----------
    p : array_like
        points coordinates

    Returns
    -------
    array_like
        ones

    */
    return [Double](repeating: 1.0, count: p.count)
}
