import SwiftUI

struct ChatBubbleShape: Shape {
    let isFromUser: Bool
    private let radius: CGFloat = 18
    private let tailRadius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)

        if isFromUser {
            path.move(to: CGPoint(x: minX + radius, y: minY))
            path.addLine(to: CGPoint(x: maxX - radius, y: minY))
            path.addArc(center: CGPoint(x: maxX - radius, y: minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: maxX, y: maxY - tailRadius))
            path.addArc(center: CGPoint(x: maxX - tailRadius, y: maxY - tailRadius), radius: tailRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: minX + radius, y: maxY))
            path.addArc(center: CGPoint(x: minX + radius, y: maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: minX, y: minY + radius))
            path.addArc(center: CGPoint(x: minX + radius, y: minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.move(to: CGPoint(x: minX + tailRadius, y: maxY - tailRadius))
            path.addArc(center: CGPoint(x: minX + tailRadius, y: maxY - tailRadius), radius: tailRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: minX, y: minY + radius))
            path.addArc(center: CGPoint(x: minX + radius, y: minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: maxX - radius, y: minY))
            path.addArc(center: CGPoint(x: maxX - radius, y: minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: maxX, y: maxY - radius))
            path.addArc(center: CGPoint(x: maxX - radius, y: maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: minX + tailRadius, y: maxY))
        }
        path.closeSubpath()
        return path
    }
}
