//
//  BinnyMark.swift
//  DeclutteringWidget
//

import SwiftUI

/// A still version of Binny for the widget, drawn on the same 64 x 72 grid as the app's `BinnyView`.
struct BinnyMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 64, size.height / 72)
            let offset = CGSize(width: (size.width - 64 * scale) / 2, height: (size.height - 72 * scale) / 2)
            func place(_ path: Path) -> Path {
                path.applying(CGAffineTransform(scaleX: scale, y: scale)).applying(CGAffineTransform(translationX: offset.width, y: offset.height))
            }
            func photo(_ rect: CGRect, angle: Double, color: Color) {
                var path = Path(roundedRect: CGRect(origin: .zero, size: rect.size), cornerRadius: 3)
                path = path.applying(CGAffineTransform(translationX: -rect.width / 2, y: -rect.height / 2))
                    .applying(CGAffineTransform(rotationAngle: angle))
                    .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))
                context.fill(place(path), with: .color(color))
            }

            let cream = Color(BoothTheme.binBody)
            let face = Color(BoothTheme.binFace)
            let blush = Color(red: 0xF2 / 255, green: 0xCF / 255, blue: 0xC6 / 255)
            let cheek = Color(red: 0xF4 / 255, green: 0xA5 / 255, blue: 0xA8 / 255).opacity(0.8)

            photo(CGRect(x: 10, y: 1, width: 22, height: 20), angle: -0.22, color: Color(red: 0xF4 / 255, green: 0xA5 / 255, blue: 0x8A / 255))
            photo(CGRect(x: 30, y: 3, width: 22, height: 20), angle: 0.2, color: Color(red: 0xB9 / 255, green: 0xA5 / 255, blue: 0xF0 / 255))

            var body = Path()
            body.move(to: CGPoint(x: 10, y: 24))
            body.addLine(to: CGPoint(x: 54, y: 24))
            body.addLine(to: CGPoint(x: 50, y: 62))
            body.addQuadCurve(to: CGPoint(x: 46, y: 67), control: CGPoint(x: 49.5, y: 67))
            body.addLine(to: CGPoint(x: 18, y: 67))
            body.addQuadCurve(to: CGPoint(x: 14, y: 62), control: CGPoint(x: 14.5, y: 67))
            body.closeSubpath()
            context.fill(place(body), with: .color(cream))

            for x in [22.0, 32.0, 42.0] {
                var ridge = Path()
                ridge.move(to: CGPoint(x: x, y: 31))
                ridge.addLine(to: CGPoint(x: x - (x - 32) * 0.1, y: 60))
                context.stroke(place(ridge), with: .color(blush), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
            }

            context.fill(place(Path(roundedRect: CGRect(x: 24, y: 9, width: 16, height: 8), cornerRadius: 4)), with: .color(cream))
            context.fill(place(Path(roundedRect: CGRect(x: 6, y: 16, width: 52, height: 9), cornerRadius: 4.5)), with: .color(cream))

            for center in [CGPoint(x: 25, y: 43), CGPoint(x: 39, y: 43)] {
                context.fill(place(Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 3, width: 5, height: 6))), with: .color(face))
            }
            var smile = Path()
            smile.addArc(center: CGPoint(x: 32, y: 47), radius: 5, startAngle: .radians(.pi * 0.15), endAngle: .radians(.pi * 0.85), clockwise: false)
            context.stroke(place(smile), with: .color(face), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
            for x in [16.0, 42.0] {
                context.fill(place(Path(ellipseIn: CGRect(x: x, y: 47, width: 6, height: 4))), with: .color(cheek))
            }
        }
        .aspectRatio(64.0 / 72.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
