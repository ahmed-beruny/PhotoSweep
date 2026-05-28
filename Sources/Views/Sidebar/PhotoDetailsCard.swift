import SwiftUI

struct PhotoDetailsCard: View {
    let exif: AppState.ExifData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            Text("PHOTO DETAILS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.0)
            
            // Camera info row
            if let make = exif.make ?? exif.model {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentPrimary)
                        .frame(width: 18)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(make)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let model = exif.model, model != make {
                            Text(model)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            
            // Lens row
            if let lens = exif.lens {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 18)
                    Text(lens)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(.bottom, 2)
            }
            
            // Date taken row
            if let date = exif.dateTaken {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 18)
                    Text(date)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.bottom, 4)
            }
            
            // Exposure settings grid
            let specs: [(String, String, String)] = [
                ("f-stop",    "camera.aperture",         exif.aperture    ?? "—"),
                ("Shutter",   "timer",                   exif.shutterSpeed ?? "—"),
                ("ISO",       "circle.dotted",           exif.iso         ?? "—"),
                ("Focal",     "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", exif.focalLength ?? "—"),
                ("WB",        "sun.max",                 exif.whiteBalance ?? "—"),
                ("Flash",     "bolt",                    exif.flash       ?? "—"),
            ].filter { $0.2 != "—" }
            
            if !specs.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(specs, id: \.0) { spec in
                        ExifSpecBox(label: spec.0, icon: spec.1, value: spec.2)
                    }
                }
            }
            
            // Exposure mode (full width if present)
            if let mode = exif.exposureMode {
                HStack(spacing: 6) {
                    Image(systemName: "dial.low")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Exposure Mode")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(mode)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(18)
        .background(Color.bgSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// A compact EXIF spec tile
private struct ExifSpecBox: View {
    let label: String
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentPrimary.opacity(0.8))
                .frame(width: 14)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .kerning(0.5)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
