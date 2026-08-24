//
//  RouteQRCompression.swift
//  TraceWay
//

import Compression
import Foundation

enum RouteQRCompression {
    static func compressLZFSE(_ data: Data) throws -> Data {
        try compress(data, algorithm: COMPRESSION_LZFSE)
    }

    static func decompressLZFSE(_ data: Data) throws -> Data {
        try decompress(data, algorithm: COMPRESSION_LZFSE)
    }

    private static func compress(_ source: Data, algorithm: compression_algorithm) throws -> Data {
        guard !source.isEmpty else { return Data() }

        let destinationCapacity = source.count + source.count / 2 + 64
        var destination = Data(count: destinationCapacity)

        let written: Int = try source.withUnsafeBytes { sourceBuffer in
            guard let sourcePointer = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                throw RouteQREncodingError.compressionFailed
            }
            return try destination.withUnsafeMutableBytes { destinationBuffer in
                guard let destinationPointer = destinationBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    throw RouteQREncodingError.compressionFailed
                }
                let count = compression_encode_buffer(
                    destinationPointer,
                    destinationCapacity,
                    sourcePointer,
                    source.count,
                    nil,
                    algorithm
                )
                guard count > 0 else {
                    throw RouteQREncodingError.compressionFailed
                }
                return count
            }
        }

        destination.count = written
        return destination
    }

    private static func decompress(_ source: Data, algorithm: compression_algorithm) throws -> Data {
        guard !source.isEmpty else { return Data() }

        // Decompressed JSON can be several× larger than compressed bytes (compact deltas compress extremely well).
        // Start from a generous multiple and grow until success or hard cap.
        var capacity = max(source.count * 32, 256 * 1024)
        let hardCap = 16 * 1024 * 1024

        while capacity <= hardCap {
            var destination = Data(count: capacity)
            let written: Int = source.withUnsafeBytes { sourceBuffer in
                guard let sourcePointer = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return destination.withUnsafeMutableBytes { destinationBuffer -> Int in
                    guard let destinationPointer = destinationBuffer.bindMemory(to: UInt8.self).baseAddress else {
                        return 0
                    }
                    return compression_decode_buffer(
                        destinationPointer,
                        capacity,
                        sourcePointer,
                        source.count,
                        nil,
                        algorithm
                    )
                }
            }

            if written > 0 {
                destination.count = written
                return destination
            }
            capacity *= 2
        }

        throw RouteQRDecodingError.decompressionFailed
    }
}
