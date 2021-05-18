//
//  visualize.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/30/21.
//

import Foundation
import UIKit
import SceneKit


public func mapSingle(ds:[Double],pts:[[Double]],tri:[[Int]], w: Double, shape: String) -> (UIView,UIView){
    let padding : Double = 10
    let (mesh, minc, maxc) = makeMesh(ds: ds, pts: pts, tri: tri, w: w, padding: padding, shape:shape)
    let (colorbar, lowBound, highBound, conductivityLabel) = generateColorbar(ds: ds, pts: pts, tri: tri, w: w, padding: padding,minc:minc,maxc: maxc)
    let info = UIView()
    info.frame = CGRect(x: 0,y: 0,width: w,height: w)
    info.layer.insertSublayer(colorbar, at: 1)
    info.addSubview(lowBound)
    info.addSubview(highBound)
    info.addSubview(conductivityLabel)
    
    return (mesh,info)
    
}


public func mapMany(ds_all:[[Double]],pts:[[Double]],tri:[[Int]],w:Double, shape: String) -> [UIView]{
    //mapMany only does mesh, no colorbar yet
    var meshes = [UIView]()
    var mins = [Double]()
    var maxs = [Double]()
    let padding : Double = 10
    for (i,ds) in ds_all.enumerated(){
        let (mesh, minc, maxc) = makeMesh(ds: ds, pts: pts, tri: tri, w: w, padding: padding, shape:shape)
        mesh.tag = i+100
        meshes.append(mesh)
        mins.append(minc)
        maxs.append(maxc)
    }
        return meshes
}



public func makeMesh(ds:[Double],pts:[[Double]],tri:[[Int]], w: Double, padding: Double, shape:String) -> (UIView,Double,Double){
    //v1,v2,v3 represent vertex points
    //color is mean of color at each point of vertex
    //minc and maxc are bounds of colors
    //returns the mesh, and the min/max values of the conductivity changes
    let xvals = pts.compactMap({$0[0]})
    let yvals = pts.compactMap({$0[1]})
//    let vals = tri.compactMap({(ds[$0[0]]+ds[$0[1]]+ds[$0[2]])/3})
    let (minx,miny,maxx,maxy,minc,maxc) = (xvals.min()!,yvals.min()!,xvals.max()!,yvals.max()!,ds.min()!,ds.max()!)
    var v1,v2,v3 : [Double]
    var c1,c2,c3 : Double
    var x1,x2,x3,y1,y2,y3,color : CGFloat
    let mesh = UIView()
    let is_circle = (shape == "circle")
    let wx = is_circle ? w : w/2
    for t in tri{
        v1 = pts[t[0]]
        x1 = transform(x: v1[0], a: minx, b: maxx, c: 0, d: wx)
        y1 = transform(x: v1[1], a: miny, b: maxy, c: w, d: 0)
        v2 = pts[t[1]]
        x2 = transform(x: v2[0], a: minx, b: maxx, c: 0, d: wx)
        y2 = transform(x: v2[1], a: miny, b: maxy, c: w, d: 0)
        v3 = pts[t[2]]
        x3 = transform(x: v3[0], a: minx, b: maxx, c: 0, d: wx)
        y3 = transform(x: v3[1], a: miny, b: maxy, c: w, d: 0)
        c1 = ds[t[0]]
        c2 = ds[t[1]]
        c3 = ds[t[2]]
        color = transform(x: (c1+c2+c3)/3, a: minc, b: maxc, c: 0, d: 100)
        let shape = CAShapeLayer()
        shape.strokeColor = colors.intermediate(percentage: color).cgColor
//        shape.fillColor = colors.intermediate(percentage: color).cgColor
        shape.fillColor = .none
        
         let path = UIBezierPath()
         path.move(to: CGPoint(x: x1, y: y1))
         path.addLine(to: CGPoint(x: x2, y: y2))
         path.addLine(to: CGPoint(x: x3, y: y3))
         path.addLine(to: CGPoint(x: x1, y: y1))
         path.close()
         shape.path = path.cgPath
         mesh.layer.addSublayer(shape)
    }
    let degrees = CGFloat(90); //the value in degrees
    mesh.transform = CGAffineTransform(rotationAngle: CGFloat(degrees * (CGFloat.pi/180.0)))
    mesh.frame = CGRect(x: 0, y: 0, width: w, height: w)
    return (mesh,minc,maxc)
}

