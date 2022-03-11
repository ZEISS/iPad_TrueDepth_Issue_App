//
//  SensorUtils.swift
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//

import Foundation

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
func ^^ (radix: Float, power: Float) -> Float {
    return Float(pow(Double(radix), Double(power)))
}

class SensorUtils {

    public static func stringOfSimd4(_ data: simd_float4) -> String {
        var content = ""
        content += "("
        content += "\(data.x), "
        content += "\(data.y), "
        content += "\(data.z), "
        content += "\(data.w)"
        content += ")"
        return content
    }

    public static func stringOfSimd3(_ data: simd_float3) -> String {
        var content = ""
        content += "("
        content += "\(data.x), "
        content += "\(data.y), "
        content += "\(data.z)"
        content += ")"
        return content
    }

    public static func norm(_ simd: SIMD4<Float>) -> Float {
        return sqrtf(simd.x ^^ 2 + simd.y ^^ 2 + simd.z ^^ 2)
    }
}
