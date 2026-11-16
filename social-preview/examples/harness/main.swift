// Renders a hand-placed (or simulated, then edited) set of colonies with the app's own shader, on transparency.
// usage: comp <spec.json>
import CoreGraphics
import Foundation
import ImageIO
import MouldCore
import MouldRender
import UniformTypeIdentifiers

struct ColonySpec: Decodable {
    var x: Double; var y: Double; var r: Double
    var spore: Double?; var mat: Double?; var sp: UInt32?; var stretch: Double?; var angle: Double?; var ns: Double?
}
struct SimSpec: Decodable { var seed: UInt64; var at: Double; var w: Double?; var h: Double?; var dx: Double?; var dy: Double?; var drop: [Int]? }
struct Spec: Decodable {
    var width: Double; var height: Double; var scale: Double?; var theme: String?; var opacity: Double?
    var sim: SimSpec?; var colonies: [ColonySpec]?; var out: String; var list: Bool?
}

let spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let theme = Theme(name: spec.theme ?? "orange") ?? .orange
var colonies: [ColonyState] = []
var template: ColonyState?
if let s = spec.sim {
    let sim = MouldSimulation(width: s.w ?? spec.width, height: s.h ?? spec.height, seed: s.seed, theme: theme)
    let live = sim.colonies(at: s.at * 60)
    template = live.first
    for (i, var c) in live.enumerated() where !(s.drop ?? []).contains(i) {
        c.x += s.dx ?? 0; c.y += s.dy ?? 0
        colonies.append(c)
    }
}
if template == nil {
    template = MouldSimulation(width: 1000, height: 1000, seed: 1, theme: .orange).colonies(at: 3600).first
}
for (i, c) in (spec.colonies ?? []).enumerated() {
    var t = template!
    t.x = c.x; t.y = c.y; t.radius = c.r
    t.species = Species(rawValue: c.sp ?? 0) ?? .penicilliumDigitatum
    // Margin defaults per species: digitatum wide, italicum narrow.
    let margin: Double = [22, 9, 12, 7][Int(t.species.rawValue)]
    t.sporeRadius = c.spore ?? max(0, c.r - margin)
    t.maturity = c.mat ?? 1
    t.stretch = c.stretch ?? 1.1
    t.angle = c.angle ?? Double(i) * 0.7
    t.noiseSeed = c.ns ?? Double((i * 7919) % 1000) / 1000
    colonies.append(t)
}
if spec.list == true {
    for (i, c) in colonies.enumerated() {
        print(String(format: "%2d sp%d x %6.1f y %6.1f r %6.1f spore %6.1f mat %.2f st %.2f ang %.2f ns %.3f", i, c.species.rawValue, c.x, c.y, c.radius, c.sporeRadius, c.maturity, c.stretch, c.angle, c.noiseSeed))
    }
}
let renderer = try MouldRenderer()
let frame = MouldFrame(colonies: Array(colonies.prefix(MouldSimulation.maxColonies)), widthPoints: spec.width, heightPoints: spec.height,
                       scale: spec.scale ?? 2, theme: theme, opacity: spec.opacity ?? 0.92)
let img = try renderer.renderImage(frame)
try Snapshot.writePNG(img, to: URL(fileURLWithPath: spec.out))
print("wrote \(spec.out) \(img.width)x\(img.height), \(colonies.count) colonies")
