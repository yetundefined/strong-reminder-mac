import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high

let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960),
                              xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(calibratedRed: 0.89, green: 0.19, blue: 0.20, alpha: 1),
           ending: NSColor(calibratedRed: 0.49, green: 0.025, blue: 0.10, alpha: 1))!
    .draw(in: background, angle: 125)

let ring = NSBezierPath(ovalIn: NSRect(x: 232, y: 222, width: 560, height: 560))
ring.lineWidth = 58
NSColor.white.setStroke()
ring.stroke()

let hands = NSBezierPath()
hands.lineWidth = 52
hands.lineCapStyle = .round
hands.lineJoinStyle = .round
hands.move(to: NSPoint(x: 512, y: 505))
hands.line(to: NSPoint(x: 512, y: 660))
hands.move(to: NSPoint(x: 512, y: 505))
hands.line(to: NSPoint(x: 635, y: 430))
hands.stroke()

let center = NSBezierPath(ovalIn: NSRect(x: 483, y: 476, width: 58, height: 58))
NSColor.white.setFill()
center.fill()

let leftBell = NSBezierPath()
leftBell.move(to: NSPoint(x: 198, y: 714))
leftBell.curve(to: NSPoint(x: 350, y: 856), controlPoint1: NSPoint(x: 220, y: 790),
               controlPoint2: NSPoint(x: 281, y: 838))
leftBell.line(to: NSPoint(x: 402, y: 824))
leftBell.curve(to: NSPoint(x: 235, y: 655), controlPoint1: NSPoint(x: 320, y: 793),
                 controlPoint2: NSPoint(x: 266, y: 724))
leftBell.close()
leftBell.fill()

let rightBell = NSBezierPath()
rightBell.move(to: NSPoint(x: 826, y: 714))
rightBell.curve(to: NSPoint(x: 674, y: 856), controlPoint1: NSPoint(x: 804, y: 790),
                controlPoint2: NSPoint(x: 743, y: 838))
rightBell.line(to: NSPoint(x: 622, y: 824))
rightBell.curve(to: NSPoint(x: 789, y: 655), controlPoint1: NSPoint(x: 704, y: 793),
                  controlPoint2: NSPoint(x: 758, y: 724))
rightBell.close()
rightBell.fill()

NSGraphicsContext.restoreGraphicsState()
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
