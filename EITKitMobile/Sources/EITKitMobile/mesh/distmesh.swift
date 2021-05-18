//
//  distmesh.swift
//  EITViz
//
//  Created by Joshua Verdejo on 1/4/21.
//

import Foundation
import Surge

public class DISTMESH{
    var fd : ([[Double]],[Double]?,[Double]?) -> [Double]
    var fh : ([[Double]]) -> [Double]
    var h0 : Double
    var deps : Double
    var geps : Double
    var densityctrlfreq : Int
    var dptol : Double
    var ttol : Double
    var Fscale : Double
    var deltat : Double
    var n_dim : Int
    var num_triangulate : Int
    var num_move : Int
    var num_density : Int
    var verbose : Bool
    var pfix : [[Double]]
    var nfix : Int
    var p : [[Double]]
    var N : Int
    var pold : [[Double]]
    var bars : [[Int]]
    var edge_combinations : [[Int]]
    var t : [[Int]]
    var shape : String
    var r : [Double]
    
    public init( fd : @escaping ([[Double]],[Double]?,[Double]?) -> [Double], fh : @escaping ([[Double]]) -> [Double], h0:Double=0.1, p_fix:[[Double]]=[], bbox:[[Double]]=[], density_ctrl_freq:Int=30, deltat:Double=0.1, dptol:Double=0.001, ttol:Double=0.1, Fscale:Double=1.2, verbose:Bool=false, shape: String){
        /*initial distmesh class

        Parameters
        ----------
        fd : str
            function handle for distance of boundary
        fh : str
            function handle for distance distributions
        h0 : Double, optional
            Distance between points in the initial distribution p0,
            default=0.1 For uniform meshes, h(x,y) = constant,
            the element size in the final mesh will usually be
            a little larger than this input.
        p_fix : array_like, optional
            fixed points, default=[]
        bbox : array_like, optional
            bounding box for region, bbox=[xmin, ymin, xmax, ymax].
            default=[-1, -1, 1, 1]
        density_ctrl_freq : int, optional
            cycles of iterations of density control, default=20
        deltat : Double, optional
            mapping forces to distances, default=0.2
        dptol : Double, optional
            exit criterion for minimal distance all points moved, default=0.01
        ttol : Double, optional
            enter criterion for re-delaunay the lattices, default=0.1
        Fscale : Double, optional
            rescaled string forces, default=1.2
            if set too small, points near boundary will be pushed back
            if set too large, points will be pushed towards boundary

        Notes
        -----
        */
        // shape description
        self.fd = fd
        self.fh = fh
        self.h0 = h0

        // a small gap, allow points who are slightly outside of the region
        self.deps = sqrt(Double.ulpOfOne) * h0
        self.geps = 1e-1 * h0

        // control the distmesh computation flow
        self.densityctrlfreq = density_ctrl_freq
        self.dptol = dptol
        self.ttol = ttol
        self.Fscale = Fscale
        self.deltat = deltat
        var new_bbox = bbox
        // default bbox is 2D
        if bbox.count == 0{
            new_bbox = [[-1, -1], [1, 1]]
        }
        // p : coordinates (x,y) or (x,y,z) of meshes
        var p : [[Double]]
        self.n_dim = new_bbox[0].count
        p = bbox2d_init(h0: h0, bbox: new_bbox)
        // control debug messages
        self.verbose = verbose
        self.num_triangulate = 0
        self.num_density = 0
        self.num_move = 0
        
        
        //Josh: Keep track of shape
        
        self.shape = shape
        self.r = self.shape == "circle" ? [1.0] : [1.0, 2.0]
        
        // keep points inside (minus distance) with a small gap (geps)
        var temp : [[Double]] = []
        let check = fd(p, [], self.r)
        for (i,n) in p.enumerated(){
            if check[i] < self.geps{
                temp.append(n)
            }
        }
        p = temp  // pylint: disable=E1136
        self.pfix = p_fix
        self.nfix = p_fix.count
        
        // remove duplicated points of p and p_fix
        // avoid overlapping of mesh points
        if (self.nfix > 0){
            p = remove_duplicate_nodes(p: p, pfix: p_fix, geps: self.geps)
            var temp = pfix
            temp.append(contentsOf: p)
            p = temp
        }
        // store p and N
        self.N = p.count
        self.p = p
        // initialize pold with inf: it will be re-triangulate at start
        let polder = [Double](repeating: Double.infinity, count: self.n_dim)
        self.pold = [[Double]](repeating: polder, count: self.N)
        // build edges list for triangle or tetrahedral. i.e., in 2D triangle
        // edge_combinations is [[0, 1], [1, 2], [2, 0]]
        self.edge_combinations = [[0, 1], [0, 2], [1, 2]]

        // triangulate, generate simplices and bars
        self.bars = []
        self.t = []
        self.triangulate()

    }
    public func is_retriangulate() -> Bool{
        // test whether re-triangulate is needed
        var dists : [[Double]] = []
        for (pt1,pt2) in zip(self.p,self.pold){
            dists.append([pt1[0]-pt2[0],pt1[1]-pt2[1]])
        }
        //Checkpoint: Looks to be doing the same calculation
        return max(dist(p: dists)) > (self.h0 * self.ttol)
    }
    
    public func triangulate(){
        // retriangle by delaunay
        self.num_triangulate += 1
        // pnew[:] = pold[:] makes a new copy, not reference
        self.pold = self.p
        // triangles where the points are arranged counterclockwise
        var iDict : [Point:Int] = [:]
        var points : [Point] = []
        for (i,pt) in self.p.enumerated(){
            let point = Point(x: Double(Double(pt[0])), y: Double(pt[1]))
            points.append(point)
            iDict[point] = i
        }
        let d_tri = doTriangulate(points)
        var tri : [[Int]] = []
        for triangle in d_tri{
            tri.append([iDict[triangle.point1]!,iDict[triangle.point2]!,iDict[triangle.point3]!])
        }
        var pmid : [[Double]] = []
        for t in tri{
            let p1 = self.p[t[0]]
            let p2 = self.p[t[1]]
            let p3 = self.p[t[2]]
            pmid.append([(p1[0]+p2[0]+p3[0])/3,(p1[1]+p2[1]+p3[1])/3])
        }
        // keeps only interior points
        var temp : [[Int]] = []
        var t : [[Int]] = []
        let r = shape == "circle" ? [1.0] : [1.0, 2.0]
        for (i,n) in self.fd(pmid, [], r).enumerated(){
            if n < -self.geps{
                temp.append(tri[i])
            }
        }
        t = temp  // pylint: disable=E1136

        // extract edges (bars)
        var bars : [[Int]] = []
        var barSet : Set<String> = []
        for b in t{
            for edge in self.edge_combinations{
                let x = edge[0]
                let y = edge[1]
                let a = min(b[x],b[y])
                let b = max(b[x],b[y])
                if !barSet.contains(String(a)+"/"+String(b)){
                    barSet.insert(String(a)+"/"+String(b))
                    bars.append([a,b])
                }
            }
        }
        self.bars = bars
        
        self.t = t
    }
    func bar_length() -> ([[Double]], [[Double]], [[Double]], Bool){
        // the forces of bars (python is by-default row-wise operation)
        // two node of a bar
        var flag = false
        var bars_a, bars_b, bars_ab, barvec, L, hbars, L0 : [[Double]]
        (bars_a, bars_b, bars_ab, barvec, L, hbars, L0)  = ([],[],[],[],[],[],[])
        for b in self.bars{
            bars_a.append(self.p[b[0]])
            bars_b.append(self.p[b[1]])
            barvec.append([self.p[b[0]][0]-self.p[b[1]][0],self.p[b[0]][1]-self.p[b[1]][1]])
            bars_ab.append([(self.p[b[0]][0]+self.p[b[1]][0])/2,(self.p[b[0]][1]+self.p[b[1]][1])/2])
        }
        for i in dist(p: barvec){
            L.append([i])
        }
        for i in self.fh(bars_ab){
            hbars.append([i])
        }
        // L : length of bars, must be column ndarray (2D)
        // density control on bars
        // L0 : desired lengths (Fscale matters!)
        var Lsq, hbarsq : Double
        (Lsq, hbarsq) = (0,0)
        for n in L{
            Lsq += pow(n[0],2.0)
        }
        
        for n in hbars{
            hbarsq += pow(n[0],2.0)
        }
        
        for (i,n) in hbars.enumerated(){
            L0.append([n[0] * self.Fscale * sqrt(Lsq / hbarsq)])
            if L[i][0]*2 < L0[i][0]{
                flag = true
            }
        }
        return (L, L0, barvec, flag)
    }
    public func bar_force(L: [[Double]], L0: [[Double]], barvec: [[Double]]) -> [[Double]]{
        //optimization: running rows_flat in same for loop as data, getting rid of fvec stuff
        // forces on bars
        var F : [[Double]] = []
        for (l1,l2) in zip(L0,L){
            F.append([max(l1[0]-l2[0],0)])
        }
        var rows_flat : [Int] = []
        var data : [Double] = []
        for (i,b) in barvec.enumerated(){
            data.append(contentsOf: [F[i][0]*(b[0]/L[i][0]), F[i][0]*(b[1]/L[i][0]),-F[i][0]*(b[0]/L[i][0]), -F[i][0]*(b[1]/L[i][0])])
        }
        // normalized and vectorized forces
        // now, we get forces and sum them up on nodes
        // using sparse matrix to perform automatic summation
        // rows : left, left, right, right (2D)
        //      : left, left, left, right, right, right (3D)
        // cols : x, y, x, y (2D)
        //      : x, y, z, x, y, z (3D)
        let ctemp = [[Int]](repeatElement([0,1,0,1], count: F[0].count)).flatMap({$0})
        let cols = [[Int]](repeating: ctemp, count: F.count)
        let cols_flat = cols.flatMap({$0})
        for b in self.bars{
            rows_flat.append(contentsOf: [b[0],b[0],b[1],b[1]])
        }
        var Ftot = [[Double]](repeating: [Double](repeatElement(0.0, count: self.n_dim)), count: self.N)
        for i in 0..<data.count{
            Ftot[rows_flat[i]][cols_flat[i]] += data[i]
        }
        // zero out forces at fixed points, as they do not move
        for i in 0..<self.pfix.count{
            Ftot[i][0] = 0
            Ftot[i][1] = 0
        }
        return Ftot
    }
    public func density_control(L: [[Double]], L0: [[Double]], dscale:Double=3.0){
        /*
        Density control - remove points that are too close
        L0 : Kx1, L : Kx1, bars : Kx2
        bars[L0 > 2*L] only returns bar[:, 0] where L0 > 2L
        */
        self.num_density += 1
        // quality control
        var ixdel : [Int] = []
        var ixout : [Bool] = []
        for (i,j) in zip(L0,L){
            ixout.append(i[0]>dscale*j[0])
        }
        let nrange = Array(0..<self.nfix)
        for (i,check) in ixout.enumerated(){
            if check{
                let (x,y) = (self.bars[i][0],self.bars[i][1])
                if !(nrange.contains(x)){
                    ixdel.append(x)
                }
                if !(nrange.contains(y)){
                    ixdel.append(y)
                }
            }
        }
        ixdel.sort()
        var temp : [Int] = []
        for num in 0..<self.N{
            if !(ixdel.contains(num)){
                temp.append(num)
            }
        }
        self.p = temp.map({self.p[$0]})
        self.N = self.p.count
        self.pold = [[Double]](repeating: [Double](repeating: Double.infinity, count: self.n_dim), count: self.N)
    }
    func move_p(Ftot:[[Double]])-> Bool{
        // update p
        self.num_move += 1
        // move p along forces
        for i in 0..<self.p.count{
            self.p[i][0] += self.deltat * Ftot[i][0]
            self.p[i][1] += self.deltat * Ftot[i][1]
        }
        // if there is any point ends up outside
        // move it back to the closest point on the boundary
        // using the numerical gradient of distance function
        let d = self.fd(self.p, [], self.r)
        var ix : [Bool] = []
        var p_edge : [[Double]] = []
        var pvals : [Int] = []
        for (i,n) in d.enumerated(){
            ix.append(n>0)
            if n>0{
                pvals.append(i)
                p_edge.append(self.p[i])
            }
        }
        if pvals.count > 0 {
            for (i,n) in zip(edge_project(pts: p_edge, fd: self.fd, h0: self.geps, shape: self.shape),pvals){
                self.p[n][0] = i[0]
                self.p[n][1] = i[1]
            }
        }
        // check whether convergence : no big movements
        var dm : [[Double]] = []
        for (i,n) in d.enumerated(){
            if n < -self.geps{
                dm.append(Ftot[i])
            }
        }
        let delta_move = max(dist(p: dm)) * self.deltat
        let score = delta_move < self.dptol * self.h0
        return score
    }
}


    func bbox2d_init(h0 : Double, bbox : [[Double]]) -> [[Double]]{
    /*
    generate points in 2D bbox (not including the ending point of bbox)

    Parameters
    ----------
    h0 : Double
        minimal distance of points
    bbox : array_like
        [[x0, y0],
         [x1, y1]]

    Returns
    -------
    array_like
        points in bbox
    */
    var (x1,x2,y1,y2) = (bbox[0][0], bbox[1][0], bbox[0][1], bbox[1][1])
    var xy1 : [Double] = []
    for v1 in stride(from: x1, to: x2, by: h0){
        xy1.append(v1)
    }
    
    var xy2 : [Double] = []
        for v2 in stride(from: y1, to: y2, by: h0 * sqrt(3) / 2.0){
            xy2.append(v2)
        }
    var x = [[Double]](repeatElement(xy1, count: xy2.count))
    var y : [[Double]] = []
    while y1 < y2{
        y.append([Double](repeating: y1, count: xy1.count))
        y1 += h0 * sqrt(3) / 2.0
    }
    var p : [[Double]] = []
    for row in 0..<x.count{
        if row % 2 != 0{
            x[row] = x[row].map({$0 + h0 / 2.0})
            }
    }

    for (i,j) in zip(x.flatMap({$0}),y.flatMap({$0})){
        p.append([i,j])
    }
        return p
    }

    func remove_duplicate_nodes(p: [[Double]], pfix: [[Double]], geps: Double) -> [[Double]]{
    /* remove duplicate points in p who are closed to pfix. 3D, ND compatible

    Parameters
    ----------
    p : array_like
        points in 2D, 3D, ND
    pfix : array_like
        points that are fixed (can not be moved in distmesh)
    geps : Double, optional (default=0.01*h0)
        minimal distance that two points are assumed to be identical

    Returns
    -------
    array_like
        non-duplicated points
    */
    var temp,ptemp : [[Double]]
    (temp,ptemp) = ([],[])
    var pnew = p
    for row in pfix{
        for pt in pnew{
            temp.append([pt[0]-row[0],pt[1]-row[1]])
        }
        let pdist = dist(p: temp)
        for (i,d) in pdist.enumerated(){
            if d>geps{
                ptemp.append(pnew[i])
            }
        }
        pnew = ptemp
        ptemp = []
        temp = []
    }
    return pnew

    }
public func build(fd : @escaping ([[Double]],[Double]?,[Double]?) -> [Double], fh : @escaping ([[Double]]) -> [Double], pfix:[[Double]]=[], bbox:[[Double]]=[], h0:Double=0.1, densityctrlfreq:Int=10, maxiter:Int=500, verbose:Bool=false, shape: String) -> ([[Double]], [[Int]]){
    /*main function for distmesh

    See Also
    --------
    DISTMESH : main class for distmesh

    Parameters
    ----------
    maxiter : int, optional
        maximum iteration numbers, default=1000

    Returns
    -------
    p : array_like
        points on 2D bbox
    t : array_like
        triangles describe the mesh structure

    Notes
    -----
    there are many python or hybrid python + C implementations in github,
    this implementation is merely implemented from scratch
    using PER-OLOF PERSSON's Ph.D thesis and SIAM paper.

    .. [1] P.-O. Persson, G. Strang, "A Simple Mesh Generator in MATLAB".
       SIAM Review, Volume 46 (2), pp. 329-345, June 2004

    Also, the user should be aware that, equal-edged tetrahedron cannot fill
    space without gaps. So, in 3D, you can lower dptol, or limit the maximum
    iteration steps.

    */
    var g_dptol, g_ttol, g_Fscale, g_deltat : Double
    (g_dptol, g_ttol, g_Fscale, g_deltat) = (0.001, 0.1, 1.3, 0.2)
    if bbox.count == 0{
        (g_dptol, g_ttol, g_Fscale, g_deltat) = (0.001, 0.1, 1.2, 0.2)
    }
    else{
        if bbox.count != 2{
            print("please specify lower and upper bound of bbox")
        }
        if bbox[0].count == 2{
            // default parameters for 2D
             (g_dptol, g_ttol, g_Fscale, g_deltat) = (0.001, 0.1, 1.3, 0.2)
        }
        else{
            // default parameters for 3D
            (g_dptol, g_ttol, g_Fscale, g_deltat) = (0.001, 0.1, 1.1, 0.1)
        }
    }
    // initialize distmesh
    let dm = DISTMESH(fd: fd,fh: fh,h0: h0,p_fix: pfix,bbox: bbox,density_ctrl_freq: densityctrlfreq,deltat: g_deltat,dptol: g_dptol,ttol: g_ttol,Fscale: g_Fscale,verbose:verbose, shape: shape)
    // now iterate to push to equilibrium
    for i in 0..<maxiter{
        
        if dm.is_retriangulate(){
            dm.triangulate()
        }
        // calculate bar forces
        let (L, L0, barvec, flag) = dm.bar_length()
        // density control
        
        if flag && (i % densityctrlfreq) == 0{
            print("here",i)
            dm.density_control(L: L, L0: L0)
            continue
        }
        
        // calculate bar forces
        
        let Ftot = dm.bar_force(L: L, L0: L0, barvec: barvec)
        
        // update p
        
        let converge = dm.move_p(Ftot: Ftot)
        // the stopping ctriterion (movements interior are small)
    if converge{
            break
        }
    }
    // at the end of iteration, (p - pold) is small, so we recreate delaunay
    dm.triangulate()
    // you should remove duplicate nodes and triangles
    return (dm.p, dm.t)
}


