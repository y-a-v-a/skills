// Renders a procedural background with a Metal compute kernel to PNG (macOS).
//
// build:  swiftc -O bgrender.swift -o $W/bgrender && cp common.metal $W/
// usage:  bgrender <kernel.metal> <out.png> <widthPx> <heightPx> <scale> [seed] [a0 a1 a2 a3 b0 b1 b2 b3 c0 c1 c2 c3]
//
// The kernel file is appended to common.metal (next to the binary, or $BG_COMMON) and defines
//     float4 shade(float2 p, constant U &u, texture2d<float> t1)
// p is the sample position in points (pixels / scale), u.view = (width pt, height pt, scale, seed),
// u.a / u.b / u.c are the twelve free parameters from the command line. Return straight (unpremultiplied)
// sRGB colour + alpha. Each pixel averages 4 rotated-grid samples.
//
// env:  BG_TEX=img.png   bind a PNG (premultiplied RGBA8) as t1, e.g. a motif layer to wrap onto an object
//       BG_DITHER=0      no triangular dither (smaller PNGs for textured backgrounds; keep it for smooth gradients)
import CoreGraphics
import Foundation
import ImageIO
import Metal
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 6 else {
    FileHandle.standardError.write(Data("usage: bgrender <kernel.metal> <out.png> <widthPx> <heightPx> <scale> [seed] [a0 a1 a2 a3 b0 b1 b2 b3 c0 c1 c2 c3]\n".utf8))
    exit(2)
}
let here = (Bundle.main.executableURL ?? URL(fileURLWithPath: args[0])).resolvingSymlinksInPath().deletingLastPathComponent()
let commonPath = ProcessInfo.processInfo.environment["BG_COMMON"] ?? here.appendingPathComponent("common.metal").path
func readText(_ path: String) -> String {
    guard let s = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("cannot read \(path)\n".utf8)); exit(1)
    }
    return s
}
let common = readText(commonPath)
let kernelSrc = readText(args[1])
let out = URL(fileURLWithPath: args[2])
let W = Int(args[3])!, H = Int(args[4])!
let scale = Float(args[5])!
let seed = args.count > 6 ? Float(args[6])! : 1
var extra = [Float](repeating: 0, count: 12)
for i in 0..<12 where args.count > 7 + i { extra[i] = Float(args[7 + i])! }

let device = MTLCreateSystemDefaultDevice()!
let lib: MTLLibrary
do { lib = try device.makeLibrary(source: common + "\n" + kernelSrc, options: nil) } catch {
    FileHandle.standardError.write(Data("compile failed: \(error)\n".utf8)); exit(1)
}
let pso = try! device.makeComputePipelineState(function: lib.makeFunction(name: "bg")!)
let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: W, height: H, mipmapped: false)
td.usage = [.shaderWrite, .shaderRead]
// Managed + a blit sync works on every Mac (Intel rejects shared textures, even on integrated GPUs).
td.storageMode = .managed
let tex = device.makeTexture(descriptor: td)!
var uni: [Float] = [Float(W) / scale, Float(H) / scale, scale, seed] + extra
let q = device.makeCommandQueue()!
let cb = q.makeCommandBuffer()!
let enc = cb.makeComputeCommandEncoder()!
enc.setComputePipelineState(pso)
enc.setTexture(tex, index: 0)
// Optional input image (premultiplied RGBA8) at texture(1), e.g. a mould layer to wrap onto something.
func loadTexture(_ path: String) -> MTLTexture {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let im = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = im.width, h = im.height
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(im, in: CGRect(x: 0, y: 0, width: w, height: h))
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
    let t = device.makeTexture(descriptor: d)!
    t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: ctx.data!, bytesPerRow: w * 4)
    return t
}
let input: MTLTexture
if let path = ProcessInfo.processInfo.environment["BG_TEX"] { input = loadTexture(path) } else {
    input = device.makeTexture(descriptor: MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false))!
}
enc.setTexture(input, index: 1)
enc.setBytes(&uni, length: uni.count * 4, index: 0)
let tg = MTLSize(width: 16, height: 16, depth: 1)
enc.dispatchThreadgroups(MTLSize(width: (W + 15) / 16, height: (H + 15) / 16, depth: 1), threadsPerThreadgroup: tg)
enc.endEncoding()
if let blit = cb.makeBlitCommandEncoder() { blit.synchronize(resource: tex); blit.endEncoding() }
let t0 = Date()
cb.commit(); cb.waitUntilCompleted()
if let e = cb.error { FileHandle.standardError.write(Data("gpu error: \(e)\n".utf8)); exit(1) }

// Float -> 8 bit with triangular dither so smooth gradients don't band. Kernel outputs straight (unpremultiplied) RGBA.
var f = [Float](repeating: 0, count: W * H * 4)
tex.getBytes(&f, bytesPerRow: W * 16, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
var bytes = [UInt8](repeating: 0, count: W * H * 4)
let dither = ProcessInfo.processInfo.environment["BG_DITHER"] != "0"
var rng: UInt64 = 0x9E3779B97F4A7C15
@inline(__always) func rnd() -> Float { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return Float(rng >> 40) / Float(1 << 24) }
for i in 0..<(W * H) {
    let a = min(max(f[i * 4 + 3], 0), 1)
    let a8 = (a * 255).rounded()
    for c in 0..<3 {
        // Premultiplied: never let the dither push colour above alpha (or into fully transparent pixels).
        let v = min(max(f[i * 4 + c], 0), 1) * a * 255 + (dither && a8 > 0 ? (rnd() + rnd() - 1) : 0)
        bytes[i * 4 + c] = UInt8(min(max(v.rounded(), 0), a8))
    }
    bytes[i * 4 + 3] = UInt8(a8)
}
let provider = CGDataProvider(data: Data(bytes) as CFData)!
let img = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("cannot write \(out.path) (does the folder exist?)\n".utf8)); exit(1)
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("cannot write \(out.path) (does the folder exist?)\n".utf8)); exit(1)
}
print(String(format: "wrote %@ %dx%d gpu %.0f ms", out.lastPathComponent, W, H, Date().timeIntervalSince(t0) * 1000))
