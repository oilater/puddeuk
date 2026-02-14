import Foundation

extension FileManager {
    func getSoundsDirectory() throws -> URL {
        let libraryURL = urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsURL = libraryURL.appendingPathComponent("Sounds")

        if !fileExists(atPath: soundsURL.path) {
            try createDirectory(at: soundsURL, withIntermediateDirectories: true)
        }

        return soundsURL
    }
}
