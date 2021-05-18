//
//  fem.swift
//  EITViz
//
//  Created by Joshua Verdejo on 12/23/20.

import Foundation
import Surge
import Accelerate

public class Forward{
    //FEM forward computing code
    var el_pos : [Int]
    var pts : [[Double]]
    var tri : [[Int]]
    var tri_perm : [Double]
    var ref : Int
    var n_pts : Int
    var n_dim : Int
    var n_tri : Int
    var n_vertices : Int
    var ne : Int
    
    public init(mesh : NSMutableDictionary, el_pos: [Int]){
        /*
         A good FEM forward solver should only depend on
         mesh structure and the position of electrodes
         
         Parameters
         ----------
         mesh: dict
         mesh structure, {'node', 'element', 'perm'}
         el_pos: NDArray
         numbering of electrodes positions
         
         Note
         ----
         1, The nodes are continuous numbered, the numbering of an element is
         CCW (counter-clock-wise).
         2, The Jacobian and the boundary voltages used the SIGN information,
         for example, V56 = V6 - V5 = -V65. If you are using absolute boundary
         voltages for imaging, you MUST normalize it with the signs of v0
         under each current-injecting pattern.
         */
        self.pts = mesh["node"]! as! [[Double]]
        self.tri = mesh["element"]! as! [[Int]]
        self.tri_perm = mesh["perm"]! as! [Double]
        self.el_pos = el_pos
        
        // reference electrodes [ref node should not be on electrodes]https://github.com/cgarciae/NDArray/issues
        var ref_el = 0
        while (self.el_pos.contains(ref_el)){
            ref_el = ref_el + 1
        }
        self.ref = ref_el
        
        // infer dimensions from mesh
        self.n_pts = self.pts.count
        self.n_dim = self.pts[0].count
        self.n_tri = self.tri.count
        self.n_vertices = self.tri[0].count
        self.ne = el_pos.count
    }
    public func solve_eit(ex_mat: [[Int]] = [], step: Int = 1, perm: [Double] = [], parser: String = "std") -> NSMutableDictionary{
        /*
         EIT simulation, generate perturbation matrix and forward v
         
         Parameters
         ----------
         ex_mat: NDArray
         numLines x n_el array, stimulation matrix
         step: int
         the configuration of measurement electrodes (default: adjacent)
         perm: NDArray
         Mx1 array, initial x0. must be the same size with self.tri_perm
         parser: str
         see voltage_meter for more details.
         
         Returns
         -------
         jac: NDArray
         number of measures x n_E complex array, the Jacobian
         v: NDArray
         number of measures x 1 array, simulated boundary measures
         b_matrix: NDArray
         back-projection mappings (smear matrix)
         */
        // initialize/extract the scan lines (default: apposition)
        var new_ex_mat = ex_mat
        if (ex_mat.count == 0){
            new_ex_mat = eit_scan_lines(ne: 16, dist: 8)
        }
        
        var perm0 : [Double] = []
        
        // initialize the permittivity on element
        if (perm.count == 0){
            perm0 = self.tri_perm
        }
        else if (perm.count == 1){
            perm0 = [Double](repeating: 1.0, count: self.n_tri)
        }
        else{
            assert (perm.count == self.n_tri)
            perm0 = perm
        }
        // calculate f and Jacobian iteratively over all stimulation lines
        var jac : [[[Double]]] = []
        var v : [[Double]] = []
        var b_matrix : [[Double]] = []
        let n_lines = new_ex_mat.count
        
        var ex_line : [Int] = []
        var f : [Double] = []
        var jac_i : [[Double]] = []
        var f_el = [Double](repeating: 0.0, count: self.el_pos.count)
        
        for i in 0..<n_lines{
            // FEM solver of one stimulation pattern, a row in ex_mat
            ex_line = new_ex_mat[i]
            let solved = self.solve(ex_line: ex_line, perm: perm0)
            f = solved["f"] as! [Double]
            jac_i = solved["jac"] as! [[Double]]
            var count = 0
            for j in self.el_pos{
                f_el[count] = f[j]
                count += 1
            }
            // boundary measurements, subtract_row-voltages on electrodes
            let diff_op = voltage_meter(ex_line: ex_line, n_el: self.ne, step: step, parser: parser)
            let v_diff = subtract_row(v: f_el, pairs: diff_op)
            let jac_diff = subtract_row2D(v: jac_i, pairs: diff_op)
            
            // build bp projection matrix
            // 1. we can either smear at the center of elements, using
            //    >> fe = np.mean(f[self.tri], axis=1)
            // 2. or, simply smear at the nodes using f
            let b = smear(f: f, fb: f_el, pairs: diff_op)
            // append
            v.append(v_diff)
            jac.append(jac_diff)
            b_matrix.append(contentsOf: b)
        }
        // update output, now you can call p.jac, p.v, p.b_matrix
        let pde_result : NSMutableDictionary = [:]
        pde_result["jac"] = jac[0]
        pde_result["v"] = Array(v.joined())
        pde_result["b_matrix"] = b_matrix
        return pde_result
    }
    public func invert(matrix : [Double]) -> [Double] {
        var inMatrix = matrix
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Double](repeating: 0.0, count: Int(N))
        var error : __CLPK_integer = 0
        
        withUnsafeMutablePointer(to: &N) {
            dgetrf_($0, $0, &inMatrix, $0, &pivots, &error)
            dgetri_($0, &inMatrix, $0, &pivots, &workspace, $0, &error)
        }
        return inMatrix
    }
    
    public func solve(ex_line : [Int], perm : [Double]) -> NSMutableDictionary{
        /*
         with one pos (A), neg(B) driven pairs, calculate and
         compute the potential distribution (complex-valued)
         
         The calculation of Jacobian can be skipped.
         Currently, only simple electrode model is supported,
         CEM (complete electrode model) is under development.
         
         Parameters
         ----------
         ex_line: NDArray
         stimulation (scan) patterns/lines
         perm: NDArray
         permittivity on elements (initial)
         
         Returns
         -------
         f: NDArray
         potential on nodes
         J: NDArray
         Jacobian
         */
        // 1. calculate local stiffness matrix (on each element)
        let ke = calculate_ke(pts: self.pts, tri: self.tri)
        
        // 2. assemble to global K
        let kg = assemble_sparse(ke: ke, tri: self.tri, perm: perm, n_pts: self.n_pts, ref: self.ref)
        
        // 3. calculate electrode impedance matrix R = K^{-1}
        
        let r_matrix_flat = invert(matrix: kg.flatMap({$0}))
        var r_matrix = [[Double]](repeating: [Double](repeating: 0.0, count: kg.count), count: kg.count)
        for i in 0..<kg.count{
            for j in 0..<kg.count{
                r_matrix[i][j] = r_matrix_flat[i*kg.count+j]
            }
        }
        var r_el : [[Double]] = []
        for i in self.el_pos {
            r_el.append(r_matrix[i])
        }
        // 4. solving nodes potential using boundary conditions
        let b = self._natural_boundary(ex_line: ex_line)
        //check the product of fmatrix
        let fMatrix = Surge.mul(Matrix(r_matrix), Vector(b))
        var f : [Double] = []
        for n in fMatrix{
            f.append(n)
        }
        
        
        // 5. build Jacobian matrix column wise (element wise)
        //    Je = Re*Ke*Ve = (nex3) * (3x3) * (3x1)
        let temp = [Double](repeatElement(0, count: self.n_tri))
        var jac = [[Double]](repeatElement(temp, count: self.ne))
        var rel_temp : [[Double]] = []
        for (i, e) in self.tri.enumerated(){
            for n in 0..<r_el.count{
                rel_temp.append([r_el[n][e[0]],r_el[n][e[1]],r_el[n][e[2]]])
            }
            let x = Surge.mul(Surge.mul(Matrix(rel_temp),Matrix(ke[i])),Vector([f[e[0]],f[e[1]],f[e[2]]]))
            var id = 0
            for n in 0..<jac.count{
                jac[n][i] = x[id]
                id += 1
            }
            rel_temp = []
        }
        let d : NSMutableDictionary = [:]
        d["f"] = f
        d["jac"] = jac
        return d
    }
    
    public func _natural_boundary(ex_line : [Int]) -> [Double]{
        /*
         Notes
         -----
         Generate the Neumann boundary condition. In utils.py,
         you should note that ex_line is local indexed from 0...15,
         which need to be converted to global node number using el_pos.
         */
        let drv_a_global = self.el_pos[ex_line[0]]
        let drv_b_global = self.el_pos[ex_line[1]]
        
        // global boundary condition
        var b = [Double](repeating: 0, count: self.n_pts)
        b[drv_a_global] = 1.0
        b[drv_b_global] = -1.0
        
        return b
    }
    
    public func smear(f: [Double], fb: [Double], pairs: [[Int]]) -> [[Double]]{
        /*
         build smear matrix B for bp
         
         Parameters
         ----------
         f: NDArray
         potential on nodes
         fb: NDArray
         potential on adjacent electrodes
         pairs: NDArray
         electrodes numbering pairs
         
         Returns
         -------
         B: NDArray
         back-projection matrix
         */
        var b_matrix : [[Double]] = []
        for p in pairs{
            let i = p[0]
            let j = p[1]
            let f_min = min(fb[i], fb[j])
            let f_max = max(fb[i], fb[j])
            let c1 : [Double] = f.map({($0>f_min && $0<=f_max) ? 1.0 : 0.0})
            b_matrix.append(c1)
        }
        return b_matrix
    }
    
    public func subtract_row(v:[Double], pairs: [[Int]]) -> [Double]{
        /*
         v_diff[k] = v[i, :] - v[j, :]
         
         Parameters
         ----------
         v: NDArray
         Nx1 boundary measurements vector
         in pyeit (or NxM matrix)
         Josh: in sweit, not implemented
         pairs: NDArray
         Nx2 subtract_row pairs
         
         Returns
         -------
         v_diff: NDArray
         difference measurements
         */
        var i, j : [Int]
        var v_diff : [Double]
        (i,j,v_diff) = ([],[],[])
        
        for p in pairs{
            i.append(p[0])
            j.append(p[1])
        }
        // row-wise/element-wise operation on matrix/vector v
        for (x,y) in zip(i,j){
            v_diff.append(v[x] - v[y])
        }
        return v_diff
    }
    
    public func subtract_row2D(v:[[Double]], pairs: [[Int]]) -> [[Double]]{
        /*
         v_diff[k] = v[i, :] - v[j, :]
         
         Parameters
         ----------
         v: NDArray
         Nx1 boundary measurements vector
         in pyeit (or NxM matrix)
         Josh: in sweit, not implemented
         pairs: NDArray
         Nx2 subtract_row pairs
         
         Returns
         -------
         v_diff: NDArray
         difference measurements
         */
        var i, j : [Int]
        (i,j) = ([],[])
        var v_diff : [[Double]] = []
        var v_diff_temp : [Double] = []
        for p in pairs{
            i.append(p[0])
            j.append(p[1])
        }
        // row-wise/element-wise operation on matrix/vector v
        for (x,y) in zip(i,j){
            let temp = Surge.sub(v[x], v[y])
            for i in temp{
                v_diff_temp.append(i)
            }
            v_diff.append(v_diff_temp)
            v_diff_temp = []
        }
        
        return v_diff
    }
    
    public func voltage_meter(ex_line : [Int], n_el: Int=16, step: Int=1, parser:String="std") -> [[Int]]{
        /*
         extract subtract_row-voltage measurements on boundary electrodes.
         we direct operate on measurements or Jacobian on electrodes,
         so, we can use LOCAL index in this module, do not require el_pos.
         
         Notes
         -----
         ABMN Model.
         A: current driving electrode,
         B: current sink,
         M, N: boundary electrodes, where v_diff = v_n - v_m.
         
         'no_meas_current': (EIDORS3D)
         mesurements on current carrying electrodes are discarded.
         
         Parameters
         ----------
         ex_line: NDArray
         2x1 array, [positive electrode, negative electrode].
         n_el: int
         number of total electrodes.
         step: int
         measurement method (two adjacent electrodes are used for measuring).
         parser: str
         if parser is 'fmmu', or 'rotate_meas' then data are trimmed,
         boundary voltage measurements are re-indexed and rotated,
         start from the positive stimulus electrodestart index 'A'.
         if parser is 'std', or 'no_rotate_meas' then data are trimmed,
         the start index (i) of boundary voltage measurements is always 0.
         
         Returns
         -------
         v: NDArray
         (N-1)*2 arrays of subtract_row pairs
         */
        // local node
        let drv_a = ex_line[0]
        let drv_b = ex_line[1]
        var i0 : Int
        if parser.contains("fmmu") || parser.contains("rotate_meas"){
            i0 = drv_a
        }
        else {
            i0 = 0
        }
        
        // build differential pairs
        var v : [[Int]] = []
        for a in i0..<i0 + n_el{
            let m = a % n_el
            let n = (m + step) % n_el
            // if any of the electrodes is the stimulation electrodes
            if !(m == drv_a || m == drv_b || n == drv_a || n == drv_b){
                // the order of m, n matters
                v.append([n, m])
            }
        }
        let diff_pairs = v
        return diff_pairs
    }
    
    public func assemble_sparse(ke: [[[Double]]], tri : [[Int]], perm: [Double], n_pts:Int, ref:Int=0) -> [[Double]]{
        /*
         Assemble the stiffness matrix (using sparse matrix)
         
         Parameters
         ----------
         ke: NDArray
         n_tri x (n_dim x n_dim) 3d matrix
         tri: NDArray
         the structure of mesh
         perm: NDArray
         n_tri x 1 conductivities on elements
         n_pts: int
         number of nodes
         ref: int
         reference electrode
         
         Returns
         -------
         K: NDArray
         k_matrix, NxN array of complex stiffness matrix
         
         Notes
         -----
         you may use sparse matrix (IJV) format to automatically add the local
         stiffness matrix to the global matrix.
         */
        n_tri = tri.count
        n_vertices = tri[0].count
        
        // New: use IJV indexed sparse matrix to assemble K (fast, prefer)
        // index = np.array([np.meshgrid(no, no, indexing='ij') for no in tri])
        // note: meshgrid is slow, using handcraft sparse index, for example
        // let tri=[[1, 2, 3], [4, 5, 6]], then indexing='ij' is equivalent to
        // row = [1, 1, 1, 2, 2, 2, ...]
        // col = [1, 2, 3, 1, 2, 3, ...]
        var row, col : [Int]
        (row, col) = ([],[])
        var data : [Double] = []
        for n in tri{
            for x in n {
                row.append(contentsOf: [Int](repeating: x, count: n_vertices))
            }
            for _ in 0..<n_vertices{
                col.append(contentsOf: n)
            }
        }
        for z in 0..<n_tri{
            for row in ke[z]{
                for val in row{
                    data.append(val*perm[z])
                }
            }
        }
        
        // set reference nodes before constructing sparse matrix, where
        // K[ref, :] = 0, K[:, ref] = 0, K[ref, ref] = 1.
        // write your own mask code to set the corresponding locations of data
        // before building the sparse matrix, for example,
        // data = mask_ref_node(data, row, col, ref)
        
        // for efficient sparse inverse (csc)
        let sparse_temp = [Double](repeating: 0.0, count: n_pts)
        var A = [[Double]](repeating: sparse_temp, count: n_pts)
        for i in 0..<data.count{
            A[row[i]][col[i]] += data[i]
        }
        
        // place reference electrode
        if 0 <= ref && ref < n_pts{
            A[ref] = [Double](repeating: 0.0, count: n_pts)
            for (i) in 0..<A.count{
                A[i][ref] = 0.0
            }
            A[ref][ref] = 1.0
        }
        return A
    }
    
    public func calculate_ke(pts: [[Double]], tri: [[Int]]) -> [[[Double]]]{
        /*
         Calculate local stiffness matrix on all elements.
         
         Parameters
         ----------
         pts: NDArray
         Nx2 (x,y) or Nx3 (x,y,z) coordinates of points
         tri: NDArray
         Mx3 (triangle) or Mx4 (tetrahedron) connectivity of elements
         
         Returns
         -------
         ke_array: NDArray
         n_tri x (n_dim x n_dim) 3d matrix
         */
        n_tri = tri.count
        n_vertices = tri[0].count
        
        // check dimension
        // '3' : triangles
        // '4' : tetrahedrons
        
        // default data types for ke
        var ke : [[Double]]
        let temp1 = [Double](repeating: 0.0, count: n_vertices)
        let temp2 = [[Double]](repeating: temp1, count: n_vertices)
        var ke_array = [[[Double]]](repeating: temp2, count: n_tri)
        //    var ke_array = np.zeros((n_tri, n_vertices, n_vertices))
        var xy : [[Double]] = []
        var no : [Int] = []
        //Delaunay: Reversing the list
        for ei in 0..<n_tri{
            no = tri[ei]
            xy.append(contentsOf: no.map({pts[$0]}))
            //        var no = tri[ei, :]
            //        var xy = pts[no]
            // compute the KIJ (permittivity=1.)
            // Josh: Just doing this condition for now
            //        if n_vertices == 3{
            //            ke = _k_triangle(xy: xy)
            //        }
            ke = _k_triangle(xy: xy)
            //        else if n_vertices == 4{
            //            ke = _k_tetrahedron(xy: xy)
            //        }
            ke_array[ei] = ke
        }
        
        return ke_array
    }
    
    public func _k_triangle(xy: [[Double]]) -> [[Double]]{
        /*
         given a point-matrix of an element, solving for Kij analytically
         using barycentric coordinates (simplex coordinates)
         
         Parameters
         ----------
         xy: NDArray
         (x,y) of nodes 1,2,3 given in counterclockwise manner
         
         Returns
         -------
         ke_matrix: NDArray
         local stiffness matrix
         */
        var s : [[Double]] = []
        var temp : [Double] = []
        for (x,y) in zip([2, 0, 1],[1, 2, 0]){
            for (i,j) in zip(xy[x],xy[y]){
                temp.append(i-j)
            }
            s.append(temp)
            temp = []
        }
        
        // area of triangles. Note, abs is removed since version 2020,
        // user must make sure all triangles are CCW (conter clock wised).
        // at = 0.5 * la.det(s[[0, 1]])
        let at = 0.5 * det2x2(s1: s[0], s2: s[1])
        
        // (e for element) local stiffness matrix
        let ke_m = Surge.mul(Matrix(s), Surge.transpose(Matrix(s))) / (4.0 * at)
        var ke_matrix : [[Double]] = []
        for row in ke_m{
            ke_matrix.append(Array(row))
        }
        
        return ke_matrix
    }
    
    public func det2x2(s1: [Double], s2: [Double]) -> Double{
        // Calculate the determinant of a 2x2 matrix
        return Double(s1[0] * s2[1] - s1[1] * s2[0])
    }
}
