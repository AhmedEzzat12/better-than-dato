import AppKit
import SwiftUI

/// Renders the demo video frame by frame and pipes it to ffmpeg.
/// Usage (from the repo root): swift run DemoVideo [output.mp4]    — or scripts/make-demo-video.sh
/// Set DEMO_STILLS=<dir> to also save a PNG every 1.5 s for review.
@main
enum DemoVideo {
    static let fps = 30.0

    @MainActor
    static func main() throws {
        let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/demo.mp4"
        let stills = ProcessInfo.processInfo.environment["DEMO_STILLS"]
        let story = DemoStory()
        let width = Int(canvas.width), height = Int(canvas.height)
        let frameCount = Int((Timeline.duration * fps).rounded())

        let ffmpeg = Process()
        ffmpeg.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        ffmpeg.arguments = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "\(width)x\(height)", "-r", "\(Int(fps))", "-i", "-",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-preset", "medium", "-movflags", "+faststart",
            output,
        ]
        let pipe = Pipe()
        ffmpeg.standardInput = pipe
        try ffmpeg.run()

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<frameCount {
            let t = Double(index) / fps
            let renderer = ImageRenderer(content: DemoFrame(t: t, story: story))
            renderer.proposedSize = ProposedViewSize(canvas)
            renderer.scale = 1
            guard let image = renderer.cgImage else { fatalError("Frame \(index) failed to render") }

            pixels.withUnsafeMutableBytes { buffer in
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            pipe.fileHandleForWriting.write(Data(pixels))

            if let stills, index % Int(fps * 1.5) == 0 {
                let url = URL(fileURLWithPath: stills).appendingPathComponent(String(format: "t%05.1f.png", t))
                try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
            }
            if index % Int(fps * 4) == 0 { print("rendered \(Int(t))s / \(Int(Timeline.duration))s") }
        }
        try pipe.fileHandleForWriting.close()
        ffmpeg.waitUntilExit()
        guard ffmpeg.terminationStatus == 0 else { fatalError("ffmpeg failed") }
        print("Wrote \(output)")
    }
}
