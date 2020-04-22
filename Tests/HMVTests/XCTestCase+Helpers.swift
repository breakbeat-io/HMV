//
//  XCTestCase+Helpers.swift
//  HMVTests
//

import XCTest

enum TestingError: Error {
    case cannotLoadFixture
}

extension XCTestCase {
    func fixture<T: Decodable>(_ type: T.Type, name: String, fileType: String = "json") throws -> T {
        let data = try fixtureData(name: name, fileType: fileType)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func fixtureData(name: String, fileType: String = "json") throws -> Data {
        let url = try urlForFixture(name: name, ofType: fileType)
        return try Data(contentsOf: url)
    }

    private func urlForFixture(name: String, ofType fileType: String) throws -> URL {
        #if os(macOS) || os(iOS)
            if let url = Bundle(for: AlbumTests.self).url(forResource: name, withExtension: fileType) { // Xcode
                return url
            }
        #endif

        let workingDirectory = URL(fileURLWithPath: "\(#file)", isDirectory: false).deletingLastPathComponent().path
        let fixturesPath = workingDirectory + "/Fixtures"
        let fixturePath = fixturesPath + "/\(name).\(fileType)"
        if FileManager.default.fileExists(atPath: fixturePath) {
            return URL(fileURLWithPath: fixturePath)
        } else {
            throw TestingError.cannotLoadFixture
        }
    }

    func expect<T: Error & Equatable>(error expectedError: T, op: () throws -> Void) {
        do {
            try op()
        } catch {
            if let error = error as? T {
                XCTAssertEqual(error, expectedError)
            } else {
                XCTFail("Expected error \(expectedError) and received \(error)")
            }
        }
    }
}
