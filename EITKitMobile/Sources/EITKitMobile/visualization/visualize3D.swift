//
//  visualize.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/30/21.
//

import Foundation
import UIKit
import SceneKit
import ARKit


//map a single frame
@available(iOS 11.0, *)
public func mapSingle3D(ds:[Double],pts:[[Double]],tri:[[Int]]) -> SCNView{
    let (nodes) = makeMesh3D(ds: ds, pts: pts, tri: tri)
    return nodes
}
@available(iOS 11.0, *)
//map a single frame, from 2 bands
public func mapMulti3D(ds1:[Double], ds2: [Double],pts:[[Double]],tri:[[Int]], position:SCNVector3) -> SCNView{
    let (node) = makeMesh3DMulti(ds1: ds1, ds2: ds2, pts: pts, tri: tri, position:position)
    return node
}
@available(iOS 11.0, *)
public func mapMany3D(ds_all:[[Double]],pts:[[Double]],tri:[[Int]]) -> [ARSCNView]{
    //mapMany only does mesh, no colorbar yet
    var nodes = [ARSCNView]()
    for (_,ds) in ds_all.enumerated(){
        let (node) = makeMesh3D(ds: ds, pts: pts, tri: tri)
        nodes.append(node)
    }
    return nodes
}

@available(iOS 11.0, *)
public func makeMesh3D(ds:[Double],pts:[[Double]],tri:[[Int]]) -> ARSCNView{
    //v1,v2,v3 represent vertex points
    //color is mean of color at each point of vertex
    //minc and maxc are bounds of colors
    //returns the mesh, and the min/max values of the conductivity changes
    let xvals = pts.compactMap({$0[0]})
    let yvals = pts.compactMap({$0[1]})
    let (minx,miny,maxx,maxy,minc,maxc) = (xvals.min()!,yvals.min()!,xvals.max()!,yvals.max()!,ds.min()!,ds.max()!)
    var v1,v2,v3 : [Double]
    var c1,c2,c3 : Double
    var x1,x2,x3,y1,y2,y3,color : CGFloat
    let mesh = ARSCNView()
    for (i,t) in tri.enumerated(){
        v1 = pts[t[0]]
        v2 = pts[t[1]]
        v3 = pts[t[2]]
        x1 = transform(x: v1[0], a: minx, b: maxx, c: 0, d: 0.35)
        y1 = transform(x: v1[1], a: miny, b: maxy, c: 0, d: 0.35)
        x2 = transform(x: v2[0], a: minx, b: maxx, c: 0, d: 0.35)
        y2 = transform(x: v2[1], a: miny, b: maxy, c: 0, d: 0.35)
        x3 = transform(x: v3[0], a: minx, b: maxx, c: 0, d: 0.35)
        y3 = transform(x: v3[1], a: miny, b: maxy, c: 0, d: 0.35)
        c1 = ds[t[0]]
        c2 = ds[t[1]]
        c3 = ds[t[2]]
        color = transform(x: (c1+c2+c3)/3, a: minc, b: maxc, c: 0, d: 100)
        
        
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        path.addLine(to: CGPoint(x: x3, y: y3))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: 0.2)
        shape.firstMaterial?.diffuse.contents =  colors.intermediate(percentage: color).cgColor
        
        
        let shapeNode = SCNNode(geometry: shape)
        shapeNode.opacity = transformSnap(x: CGFloat((c1+c2+c3)/3), minc: CGFloat(minc), maxc: CGFloat(maxc))
        shapeNode.position = SCNVector3(0,0,0)
        shapeNode.name = "t"+String(i)
        mesh.scene.rootNode.addChildNode(shapeNode)
    }
    return mesh
}

//func mapMany3DMulti(ds_all:[[Double]],pts:[[Double]],tri:[[Int]]) -> [ARSCNView]{
//    //mapMany only does mesh, no colorbar yet
//    var nodes = [ARSCNView]()
//    var ds1 = [Double]()
//    var ds2 = [Double]()
//    for (_,ds) in ds_all.enumerated(){
//        if (ds1.count == 0){
//            ds1 = ds
//        }
//        else if (ds2.count == 0){
//            ds2 = ds
//        }
//        else{
//            let (node) = makeMesh3DMulti(ds1: ds1, ds2: ds2, pts: pts, tri: tri)
//            (ds1,ds2) = ([Double](),[Double]())
//            nodes.append(node)
//        }
//    }
//    return nodes
//}

//func makeMesh3DMulti(ds1:[Double], ds2:[Double],pts:[[Double]],tri:[[Int]]) -> ARSCNView{
//    // to work with mapMany3DMulti, change the SCNViews in there to ARSCNViews
//    //v1,v2,v3 represent vertex points
//    //color is mean of color at each point of vertex
//    //minc and maxc are bounds of colors
//    //returns the mesh, and the min/max values of the conductivity changes
//    let xvals = pts.compactMap({$0[0]})
//    let yvals = pts.compactMap({$0[1]})
//    let (minx,miny,maxx,maxy) = (xvals.min()!,yvals.min()!,xvals.max()!,yvals.max()!)
//    let (minc1,maxc1,minc2,maxc2) = (ds1.min()!,ds1.max()!,ds2.min()!,ds2.max()!)
//    var v1,v2,v3 : [Double]
//    var c11,c21,c31,c12,c22,c32 : Double
//    var x1,x2,x3,y1,y2,y3,color1,color2,r1,g1,b1,a1,r2,g2,b2,a2 : CGFloat
//    let mesh = ARSCNView()
//    let tcount = tri.count
//    var m1,m2,m3 : SCNMaterial
//    var mc1,mc2 : CGColor
//    var op1,op2 : CGFloat
//    var i = 0
//    for t in tri{
//        c11 = ds1[t[0]]
//        c21 = ds1[t[1]]
//        c31 = ds1[t[2]]
//        c12 = ds2[t[0]]
//        c22 = ds2[t[1]]
//        c32 = ds2[t[2]]
//        color1 = transform(x: (c11+c21+c31)/3, a: minc1, b: maxc1, c: 0, d: 100)
//        color2 = transform(x: (c12+c22+c32)/3, a: minc2, b: maxc2, c: 0, d: 100)
//        op1 = transformSnap(x: CGFloat((c11+c21+c31)/3), minc: CGFloat(minc1), maxc: CGFloat(maxc1))
//        op2 = transformSnap(x: CGFloat((c12+c22+c32)/3), minc: CGFloat(minc2), maxc: CGFloat(maxc2))
//        r1 = 0
//        g1 = 0
//        b1 = 0
//        a1 = 0
//        r2 = 0
//        g2 = 0
//        b2 = 0
//        a2 = 0
//        colors.intermediate(percentage: color1).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
//
//        colors.intermediate(percentage: color2).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
//
//        if (op1 + op2 > 0){
//            v1 = pts[t[0]]
//            v2 = pts[t[1]]
//            v3 = pts[t[2]]
//            x1 = CGFloat(v1[0])
//            y1 = CGFloat(v1[1])
//            x2 = CGFloat(v2[0])
//            y2 = CGFloat(v2[1])
//            x3 = CGFloat(v3[0])
//            y3 = CGFloat(v3[1])
//
//            let vertices: [SCNVector3] = [
//                SCNVector3(x1, y1, 0),
//                SCNVector3(x2, y2, 0),
//                SCNVector3(x3, y3, 0),
//                SCNVector3(x1, y1, 2),
//                SCNVector3(x2, y2, 2),
//                SCNVector3(x3, y3, 2),
//            ]
//
//            let source = SCNGeometrySource(vertices: vertices)
//
//            let indices: [UInt16] = [
//                0, 2, 1,
//                3, 4, 5,
//                4, 0, 1,
//                4, 3, 0,
//                3, 5, 2,
//                0, 3, 2,
//                1, 2, 4,
//                2, 5, 4
//
//            ]
//
//            var colors: [SCNVector3] = vertices.map { _ in SCNVector3(1, 1, 1) }
//
//            colors[0] = SCNVector3(r1,g1,b1)
//            colors[1] = SCNVector3(r1,g1,b1)
//            colors[2] = SCNVector3(r1,g1,b1)
//            colors[3] = SCNVector3(r2,g2,b2)
//            colors[4] = SCNVector3(r2,g2,b2)
//            colors[5] = SCNVector3(r2,g2,b2)
//
//            let colorSource = SCNGeometrySource(data: NSData(bytes: colors, length: MemoryLayout<SCNVector3>.size * colors.count) as Data,
//                                                semantic: .color,
//                                                vectorCount: colors.count,
//                                                usesFloatComponents: true,
//                                                componentsPerVector: 3,
//                                                bytesPerComponent: MemoryLayout<Float>.size,
//                                                dataOffset: 0,
//                                                dataStride: MemoryLayout<SCNVector3>.size)
//
//            let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
//
//            let geometry = SCNGeometry(sources: [source,colorSource], elements: [element])
//
//            let shapeNode = SCNNode(geometry: geometry)
//            shapeNode.position = SCNVector3(0,0,0)
//            shapeNode.name = "t"+String(i)
//            shapeNode.scale = SCNVector3(0.1,0.1,0.1)
//            mesh.scene.rootNode.addChildNode(shapeNode)
//            i+=1
//        }
//    }
//    return mesh
//}
@available(iOS 11.0, *)
public func mapMany3DMulti(ds_all:[[Double]],pts:[[Double]],tri:[[Int]], position:SCNVector3) -> [SCNView]{
    //mapMany only does mesh, no colorbar yet
    var nodes = [SCNView]()
    var ds1 = [Double]()
    var ds2 = [Double]()
    for (_,ds) in ds_all.enumerated(){
        if (ds1.count == 0){
            ds1 = ds
        }
        else if (ds2.count == 0){
            ds2 = ds
        }
        else{
            let (node) = makeMesh3DMulti(ds1: ds1, ds2: ds2, pts: pts, tri: tri, position: position)
            (ds1,ds2) = ([Double](),[Double]())
            nodes.append(node)
        }
    }
    return nodes
}
@available(iOS 11.0, *)
public func makeMesh3DMulti(ds1:[Double], ds2:[Double],pts:[[Double]],tri:[[Int]],position:SCNVector3) -> ARSCNView{
    //v1,v2,v3 represent vertex points
    //color is mean of color at each point of vertex
    //minc and maxc are bounds of colors
    //returns the mesh, and the min/max values of the conductivity changes
    let xvals = pts.compactMap({$0[0]})
    let yvals = pts.compactMap({$0[1]})
    let (minx,miny,maxx,maxy) = (xvals.min()!,yvals.min()!,xvals.max()!,yvals.max()!)
    let (minc1,maxc1,minc2,maxc2) = (ds1.min()!,ds1.max()!,ds2.min()!,ds2.max()!)
    var v1,v2,v3 : [Double]
    var c11,c21,c31,c12,c22,c32 : Double
    var x1,x2,x3,y1,y2,y3,color1,color2,r1,g1,b1,a1,r2,g2,b2,a2 : CGFloat
    let mesh = ARSCNView()
    var op1,op2 : CGFloat
    var i = 0
    for t in tri{
        c11 = ds1[t[0]]
        c21 = ds1[t[1]]
        c31 = ds1[t[2]]
        c12 = ds2[t[0]]
        c22 = ds2[t[1]]
        c32 = ds2[t[2]]
        color1 = transform(x: (c11+c21+c31)/3, a: minc1, b: maxc1, c: 0, d: 100)
        color2 = transform(x: (c12+c22+c32)/3, a: minc2, b: maxc2, c: 0, d: 100)
        op1 = transformSnap(x: CGFloat((c11+c21+c31)/3), minc: CGFloat(minc1), maxc: CGFloat(maxc1))
        op2 = transformSnap(x: CGFloat((c12+c22+c32)/3), minc: CGFloat(minc2), maxc: CGFloat(maxc2))
        r1 = 0
        g1 = 0
        b1 = 0
        a1 = 0
        r2 = 0
        g2 = 0
        b2 = 0
        a2 = 0
        colors.intermediate(percentage: color1).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        colors.intermediate(percentage: color2).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        //        if (op1 + op2 > 0){
        v1 = pts[t[0]]
        v2 = pts[t[1]]
        v3 = pts[t[2]]
        x1 = transform(x: v1[0], a: minx, b: maxx, c: 0, d: 0.35)
        y1 = transform(x: v1[1], a: miny, b: maxy, c: 0, d: 0.35)
        x2 = transform(x: v2[0], a: minx, b: maxx, c: 0, d: 0.35)
        y2 = transform(x: v2[1], a: miny, b: maxy, c: 0, d: 0.35)
        x3 = transform(x: v3[0], a: minx, b: maxx, c: 0, d: 0.35)
        y3 = transform(x: v3[1], a: miny, b: maxy, c: 0, d: 0.35)
        
        let vertices: [SCNVector3] = [
            SCNVector3(x1, y1, -0.1),
            SCNVector3(x2, y2, -0.1),
            SCNVector3(x3, y3, -0.1),
            SCNVector3(x1, y1, 0.1),
            SCNVector3(x2, y2, 0.1),
            SCNVector3(x3, y3, 0.1),
        ]
        
        let source = SCNGeometrySource(vertices: vertices)
        
        let indices: [UInt16] = [
            0, 2, 1,
            3, 4, 5,
            4, 0, 1,
            4, 3, 0,
            3, 5, 2,
            0, 3, 2,
            1, 2, 4,
            2, 5, 4
            
        ]
        
        var colors: [SCNVector3] = vertices.map { _ in SCNVector3(1, 1, 1) }
        
        colors[0] = SCNVector3(r1,g1,b1)
        colors[1] = SCNVector3(r1,g1,b1)
        colors[2] = SCNVector3(r1,g1,b1)
        colors[3] = SCNVector3(r2,g2,b2)
        colors[4] = SCNVector3(r2,g2,b2)
        colors[5] = SCNVector3(r2,g2,b2)
        
        let colorSource = SCNGeometrySource(data: NSData(bytes: colors, length: MemoryLayout<SCNVector3>.size * colors.count) as Data,
                                            semantic: .color,
                                            vectorCount: colors.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: MemoryLayout<SCNVector3>.size)
        
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [source,colorSource], elements: [element])
        
        let shapeNode = SCNNode(geometry: geometry)
        shapeNode.position = position
        shapeNode.name = "t"+String(i)
        // for Non AR view, make this much bigger
        shapeNode.opacity = (op1 == 1 || op2 == 1) ? 1 : 0
        mesh.scene.rootNode.addChildNode(shapeNode)
        i+=1
        
        //        }
    }
    return mesh
}
