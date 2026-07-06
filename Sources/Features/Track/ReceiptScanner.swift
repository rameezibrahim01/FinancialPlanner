import SwiftUI
import VisionKit
import Vision
import UIKit

/// A full-screen document-camera scanner for receipts. Returns the first scanned
/// page as an image (or nil on cancel/failure). Everything downstream runs
/// on-device — no network.
struct ReceiptCameraScanner: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let image = scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil
            controller.dismiss(animated: true) { self.completion(image) }
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { self.completion(nil) }
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true) { self.completion(nil) }
        }
    }
}

/// On-device OCR (Vision) + light parsing to pull a total and a merchant name
/// off a scanned receipt.
enum ReceiptParser {
    struct Result {
        var amount: Double?
        var merchant: String?
    }

    /// Recognizes text on the image and extracts a best-guess total + merchant.
    static func scan(_ image: UIImage) async -> Result {
        guard let cg = image.cgImage else { return Result() }
        let lines: [String] = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                try? handler.perform([request])
                let obs = request.results as? [VNRecognizedTextObservation] ?? []
                cont.resume(returning: obs.compactMap { $0.topCandidates(1).first?.string })
            }
        }
        return parse(lines)
    }

    // MARK: Parsing

    /// Total keywords in priority order — earlier wins.
    private static let totalKeys = ["grand total", "amount due", "total due", "total", "balance", "amount paid"]

    static func parse(_ lines: [String]) -> Result {
        let lower = lines.map { $0.lowercased() }

        var amount: Double?
        search: for key in totalKeys {
            for (i, line) in lower.enumerated() where line.contains(key) {
                if key == "total" && line.contains("subtotal") { continue }   // skip subtotal
                if let n = numbers(in: lines[i]).max() { amount = n; break search }
                if i + 1 < lines.count, let n = numbers(in: lines[i + 1]).max() {
                    amount = n; break search   // amount often on the next line
                }
            }
        }
        // Fallback: the largest currency-looking number on the receipt.
        if amount == nil {
            amount = lines.flatMap { numbers(in: $0) }.max()
        }

        // Merchant: the first mostly-alphabetic line near the top with no numbers.
        let merchant = lines.prefix(6).first { line in
            let letters = line.filter(\.isLetter).count
            return letters >= 3 && numbers(in: line).isEmpty
                && !line.lowercased().contains("receipt") && !line.lowercased().contains("invoice")
        }?.trimmingCharacters(in: .whitespaces)

        return Result(amount: amount, merchant: merchant)
    }

    /// Currency-looking numbers on a line (assumes comma thousands, dot decimal).
    static func numbers(in line: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: "[0-9][0-9.,]*") else { return [] }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m -> Double? in
            let raw = ns.substring(with: m.range).replacingOccurrences(of: ",", with: "")
            // Reject tokens with more than one dot (e.g. dates like 12.05.2026).
            guard raw.filter({ $0 == "." }).count <= 1 else { return nil }
            guard let v = Double(raw), v > 0 else { return nil }
            return v
        }
    }
}
