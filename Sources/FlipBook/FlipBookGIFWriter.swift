//
//  FlipBookGIFWriter.swift
//  
//
//  Created by Brad Gayman on 1/25/20.
//

import AVFoundation
import ImageIO
#if !os(macOS)
import MobileCoreServices
#else
import CoreServices
#endif

// MARK: - FlipBookGIFWriter -

/// Class that converts an array of images to animated gif
public final class FlipBookGIFWriter: NSObject {
    
    // MARK: - Types -
    
    /// Errors that `FlipBookGIFWriter` can throw
    public enum FlipBookGIFWriterError: Error {
        
        /// Could not create gif destination for supplied file `URL`
        case couldNotCreateDestination
        
        /// Failed to finalize writing for gif
        case failedToFinalizeDestination
    }
    
    // MARK: - Public Properties -

    /// The file `URL` that the gif is written to
    public let fileOutputURL: URL
    
    // MARK: - Private Properties -
    
    /// Queue on which gif writing takes place
    private static let queue = DispatchQueue(label: "com.FlipBook.gif.writer.queue", attributes: .concurrent)
    
    // MARK: - Init / Deinit -
    
    /// Creates an instance of `FlipBookGIFWriter`
    /// - Parameter fileOutputURL: The file `URL` that the gif is written to
    public init?(fileOutputURL: URL?) {
        guard let fileOutputURL = fileOutputURL else {
            return nil
        }
        self.fileOutputURL = fileOutputURL
    }
    
    // MARK: - Public Methods -
    
    /// Function that takes an array of images and composes an animated gif with them
    /// - Parameters:
    ///   - images: images that comprise the gif
    ///   - delay: time in seconds gif should wait before moving to next frame. **Default** 0.02
    ///   - loop: number of times gif should animate. Value of 0 will cause gif to repeat indefinately **Default** 0
    ///   - progress: closure called when progress is made while creating gif. Called from background thread.
    ///   - completion: closure called after gif has been composed. Called from background thread.
    public func makeGIF(_ images: [Image], delay: CGFloat = 0.02, loop: Int = 0, progress: ((CGFloat) -> Void)?, completion: @escaping (Result<URL, Error>) -> Void) {
        var images: [Image?] = images
        let count = images.count
        Self.queue.async { [weak self] in
            guard let self = self else { return }
            let gifSettings = [
                kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: loop, kCGImagePropertyGIFHasGlobalColorMap as String: false]
            ]
            let imageSettings = [
                kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: delay]
            ]
            guard let destination = CGImageDestinationCreateWithURL(self.fileOutputURL as CFURL, kUTTypeGIF, count, nil) else {
                completion(.failure(FlipBookGIFWriterError.couldNotCreateDestination))
                return
            }
            let urls = images.indices.compactMap { self.makeFileOutputURL(fileName: "img\($0).jpg") }
            zip(images, urls).forEach {
                let data = $0.0?.jpegRep
                try? data?.write(to: $0.1)
            }
            CGImageDestinationSetProperties(destination, gifSettings as CFDictionary)
            for index in urls.indices {
                autoreleasepool {
                    let url = urls[index]
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                        print("source is nil")
                        return
                    }
                    CGImageDestinationAddImageFromSource(destination, source, index, imageSettings as CFDictionary)
                    images[index] = nil
                    progress?(CGFloat(index + 1) / CGFloat(count))
                }
            }
            
            if CGImageDestinationFinalize(destination) == false {
                completion(.failure(FlipBookGIFWriterError.couldNotCreateDestination))
            } else {
                completion(.success(self.fileOutputURL))
            }
        }
    }
    
    /// Function that returns the default file url for the generated video
    private func makeFileOutputURL(fileName: String = "FlipBook.gif") -> URL? {
        do {
            var cachesDirectory: URL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            cachesDirectory.appendPathComponent(fileName)
            if FileManager.default.fileExists(atPath: cachesDirectory.path) {
                try FileManager.default.removeItem(atPath: cachesDirectory.path)
            }
            return cachesDirectory
        } catch {
            print(error)
            return nil
        }
    }
}
