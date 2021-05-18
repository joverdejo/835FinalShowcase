//
//  base.swift
//  EITViz
//
//  Created by Joshua Verdejo on 12/22/20.
//

import Foundation
import Surge

public class EitBase: NSObject{
    /*
    A base EIT solver.
    */
    
    var mesh : NSMutableDictionary
    var el_pos : [Int]
    var ex_mat : [[Int]]
    var step : Int
    var perm : [Double]
    var jac_normalized : Bool
    var parser : String
    var pts, tri : [[Double]]
    var no_num : Int
    var n_dim : Int
    var el_num : Int
    var n_vertices : Int
    var params : [String: String]
    var xg : [Double]
    var yg : [Double]
    var mask : [Double]
    var fwd : Forward
    var H, B : [[Double]]
    var v0, v0_sign : [Double]
    var J : [[Double]]

    public init(mesh: NSMutableDictionary, el_pos: [Int], ex_mat: [[Int]] = [], step: Int = 1, perm: [Double] = [], jac_normalized:Bool = false, parser: String = "std"){
        /*
        Parameters
        ----------
        mesh: dict
            mesh structure
        el_pos: array_like
            position (numbering) of electrodes
        ex_mat: array_like, optional (default: opposition)
            2D array, each row is one stimulation pattern/line
        step: int, optional
            measurement method
        perm: array_like, optional
            initial permittivity in generating Jacobian
        jac_normalized: Boolean (default is False)
            normalize the jacobian using f0 computed from input perm
        parser: str, optional, default is 'std'
            parsing the format of each frame in measurement/file

        Notes
        -----
        parser is required for your code to be compatible with
        (a) simulation data set or (b) FMMU data set
        */
        if (ex_mat.isEmpty){
            self.ex_mat = eit_scan_lines(ne: el_pos.count, dist: 8)
        }
        else{
            self.ex_mat = ex_mat
        }
        
        if (perm.isEmpty) {
            self.perm = mesh["perm"] as! [Double]
            
        }
        


        // build forward solver
        let fwd = Forward(mesh: mesh, el_pos: el_pos)
        self.fwd = fwd

        // solving mesh structure
        self.mesh = mesh
        self.pts = mesh["node"]! as! [[Double]]
        self.tri = mesh["element"]! as! [[Double]]

        // shape of the mesh
        self.no_num = self.pts.count
        self.n_dim = self.pts[0].count
        self.el_num = self.tri.count
        self.n_vertices = self.tri[0].count
        self.el_pos = el_pos
        self.parser = parser

        // user may specify a scalar for uniform permittivity
        if (perm.count == 1){
            self.perm = [Double](repeating: perm[0], count: self.el_num)
        }
        else{
            self.perm = perm
        }
        
        // solving configurations
        
        self.step = step
        
        // solving Jacobian using uniform sigma distribution
        let res = fwd.solve_eit(ex_mat : ex_mat, step : step, perm : self.perm, parser : self.parser)
        self.J = res["jac"] as! [[Double]]
        self.v0 = res["v"] as! [Double]
        self.B = res["b_matrix"] as! [[Double]]
        self.v0_sign = self.v0.map({$0>=0 ? 1.0 : -1.0})
        // Jacobian normalization: divide each row of J (J[i]) by abs(v0[i])
//        if (jac_normalized){ self.J = self.J / np.abs(self.v0[:, nil]) }

        // mapping matrix
        self.H = self.B

        // initialize other parameters
        self.params = [String: String]()
        self.xg = []
        self.yg = []
        self.mask = []
        self.jac_normalized = jac_normalized
        // self.setup()  // user must setup manually
    }

    public func solve(v1: [Double], v0: [Double], normalize: Bool = false, log_scale: Bool = false) -> [Double]{
        /*
        dynamic imaging (conductivities imaging)

        Parameters
        ----------
        v1: NDArray
            current frame
        v0: NDArray
            referenced frame, d = H(v1 - v0)
        normalize: Bool, optional
            true for conducting normalization
        CURRENTLY DISABLED log_scale: Bool, optional
            remap reconstructions in log scale

        Returns
        -------
        ds: NDArray
            complex-valued NDArray, changes of conductivities
        */
        var dv : [Double] = []
        if normalize{
            dv = self.normalize(v1: v1, v0: v0)
        }
        else{
            dv = Surge.sub(v1,v0)
        }
        let ds = Surge.mul(Matrix(self.H), Vector(dv))  // s = -Hv
        // negation is handled below
        // if log_scale {
        //     ds = Surge.exp(lhs:Matrix(ds)) - 1.0
        // }
        //Josh: flipping here
        var final : [Double] = []
        for el in ds{
            final.append(-el)
        }
        return final
    }

    public func normalize(v1: [Double], v0: [Double]) -> [Double]{
        /*
        Normalize current frame using the amplitude of the reference frame.
        Boundary measurements v are complex-valued, we can use the real part of v,
        np.real(v), or the absolute values of v, np.abs(v).
        The use of self.v0_sign is compatible in both scenarios, self.v0_sign
        is from Forward solve and is not equal to sign(v0) in abs mode.

        Parameters
        ----------
        v1: NDArray
            current frame, can be a Nx192 matrix where N is the number of frames
        v0: NDArray
            referenced frame, which is a row vector
        */
        var dv : [Double]
        var v0_sign : Double = 1
        dv = Surge.sub(v1,v0)
        for n in 0..<dv.count{
            if v0[n] < 0{
                v0_sign = -1
            }
            else if v0[n] > 0{
                v0_sign = 1
            }
            dv[n] = dv[n] / v0[n] * v0_sign
        }
        return dv
    }
}
