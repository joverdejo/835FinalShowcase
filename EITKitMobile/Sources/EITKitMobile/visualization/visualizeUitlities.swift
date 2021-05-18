//
//  visualizeUitlities.swift
//  EITViz
//
//  Created by Joshua Verdejo on 2/14/21.
//

import Foundation
import UIKit

extension Array where Element: UIColor {
    func intermediate(percentage: CGFloat) -> UIColor {
        let percentage = Swift.max(Swift.min(percentage, 100), 0) / 100
        switch percentage {
        case 0: return first ?? .clear
        case 1: return last ?? .clear
        default:
            let approxIndex = percentage / (1 / CGFloat(count - 1))
            let firstIndex = Int(approxIndex.rounded(.down))
            let secondIndex = Int(approxIndex.rounded(.up))
            let fallbackIndex = Int(approxIndex.rounded())

            let firstColor = self[firstIndex]
            let secondColor = self[secondIndex]
            let fallbackColor = self[fallbackIndex]

            var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            guard firstColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) else { return fallbackColor }
            guard secondColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return fallbackColor }

            let intermediatePercentage = approxIndex - CGFloat(firstIndex)
            return UIColor(red: CGFloat(r1 + (r2 - r1) * intermediatePercentage),
                           green: CGFloat(g1 + (g2 - g1) * intermediatePercentage),
                           blue: CGFloat(b1 + (b2 - b1) * intermediatePercentage),
                           alpha: CGFloat(a1 + (a2 - a1) * intermediatePercentage))
        }
    }
}

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}

//var colors = [UIColor(hex: "#3e0a51ff")!,UIColor(hex: "#422b70ff")!,UIColor(hex: "#405187ff")!,UIColor(hex: "#3f708bff")!,UIColor(hex: "#478f8cff")!,UIColor(hex: "#56ac83ff")!,UIColor(hex: "#7cc66cff")!,UIColor(hex: "#b9db54ff")!, UIColor(hex: "#f9e755ff")!]


var colors = [UIColor(hex: "#00004Eff")!,UIColor(hex: "#0500F0ff")!,UIColor(hex: "#0088FEff")!,UIColor(hex: "#23FEFEff")!,UIColor(hex: "#F9FEFDff")!,UIColor(hex: "#FEFE2Cff")!,UIColor(hex: "#FE9F00ff")!,UIColor(hex: "#FE1201ff")!, UIColor(hex: "#540100ff")!]


func eidorsColors(x: CGFloat){
    var _ = [UIColor(red: 150/255, green: 150/255, blue: 150/255, alpha: 1),UIColor(red:0, green: 88/255, blue: 159/255, alpha: 1),UIColor(red: 0, green: 99/255, blue: 180/255, alpha: 1),UIColor(red: 0, green: 121/255, blue: 255/255, alpha: 1),UIColor(red: 0, green: 190/255, blue: 255/255, alpha: 1),UIColor(red: 0, green: 243/255, blue: 255/255, alpha: 1),UIColor(red: 198/255, green: 251/255, blue: 255/255, alpha: 1)]
    
}


public func transform(x:Double, a:Double,b:Double,c:Double,d:Double) -> CGFloat{
    return (CGFloat((x-a)*((d-c)/(b-a)) + c)).isNaN ? CGFloat(c) : CGFloat((x-a)*((d-c)/(b-a)) + c)
}

func transformSnap(x:CGFloat, minc:CGFloat, maxc:CGFloat) -> CGFloat{
    //Assumes negative value for minc, and positive for maxc
    let threshold = CGFloat(0.7)
    return(x > threshold*maxc || x < threshold*(minc)) ? CGFloat(1.0) : CGFloat(0.0)
}

func generateColorbar(ds:[Double],pts:[[Double]],tri:[[Int]], w: Double, padding: Double, minc:Double, maxc:Double) -> (CAGradientLayer,UILabel,UILabel,UILabel){
    //For setting up colorbar
    //from https://medium.com/better-programming/swift-gradient-in-4-lines-of-code-6f81809da741
    let colorbar = CAGradientLayer()
    colorbar.frame = CGRect(x: padding, y: w+w/2.5, width: w-2*padding, height: w/10)
    colorbar.colors = colors.map({$0.cgColor})
    colorbar.startPoint = CGPoint(x: 0, y: 1)
    colorbar.endPoint = CGPoint(x: 1, y: 1)

    

    //For setting up labels on colorbar
    //from https://stackoverflow.com/questions/3209803/how-to-programmatically-add-text-to-a-uiview
    let lowBound = UILabel(frame: CGRect(x: padding, y: w+w/2.5, width: (w-padding)/2, height: w/10))
    lowBound.textColor = colors[colors.count-1]
    lowBound.text = String(Double(round(100*minc)/100))
    lowBound.font = UIFont(name:"HelveticaNeue-Bold", size: CGFloat(w/15))
    
    let highBound = UILabel(frame: CGRect(x: (w-padding)/2, y: w+w/2.5, width: (w-padding)/2, height: w/10))
    highBound.textAlignment = .right
    highBound.textColor = colors[0]
    highBound.text = String(Double(round(100*maxc)/100))
    highBound.font = UIFont(name:"HelveticaNeue-Bold", size: CGFloat(w/15))
    
    let conductivityLabel = UILabel(frame: CGRect(x: padding, y: w+w/2, width: w-2*padding, height: w/10))
    conductivityLabel.textAlignment = .center
    conductivityLabel.textColor = UIColor.black
    conductivityLabel.text = "Conductivity"
    conductivityLabel.font = UIFont(name:"HelveticaNeue-Bold", size: CGFloat(w/15))
    
    return (colorbar, lowBound, highBound, conductivityLabel)
}
