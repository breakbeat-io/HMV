//
//  CiderUrlBuilder.swift
//  Cider
//
//  Created by Scott Hoyt on 8/1/17.
//  Copyright © 2017 Scott Hoyt. All rights reserved.
//

import Foundation

protocol UrlBuilder {
    func searchRequest(term: String, limit: Int?, types: [MediaType]?) -> URLRequest
    func fetchRequest(mediaType: MediaType, id: String, include: [Include]?) -> URLRequest
}

public enum Storefront: String, Codable {
    case unitedStates = "us"
}

public enum CiderUrlBuilderError: Error {
    case noUserToken
}

struct CiderUrlBuilder: UrlBuilder {

    // MARK: Inputs

    let storefront: Storefront
    let developerToken: String
    var userToken: String?
    private var cachePolicy = URLRequest.CachePolicy.returnCacheDataElseLoad
    private var timeout: TimeInterval = 5

    // MARK: Init

    init(storefront: Storefront, developerToken: String) {
        self.storefront = storefront
        self.developerToken = developerToken
    }

    // MARK: Constants

    private struct AppleMusicApi {
        // Base
        static let baseURLScheme = "https"
        static let baseURLString = "api.music.apple.com"
        static let baseURLApiVersion = "/v1"

        // Search
        static let searchPath = "v1/catalog/{storefront}/search"
        static let searchTerm = "term"
        static let searchLimit = "limit"
        static let searchTypes = "types"

        // Fetch
        // TODO: Construct this from the media type
        static let artistPath = "v1/catalog/{storefront}/artists/{id}"
        static let albumsPath = "v1/catalog/{storefront}/albums/{id}"
        static let songsPath = "v1/catalog/{storefront}/songs/{id}"
        static let playlistsPath = "v1/catalog/{storefront}/playlists/{id}"
        static let musicVideosPath = "v1/catalog/{storefront}/music-videos/{id}"
    }

    private var baseApiUrl: URL {
        var components = URLComponents()

        components.scheme = AppleMusicApi.baseURLScheme
        components.host = AppleMusicApi.baseURLString

        return components.url!
    }

    // MARK: Construct urls

    private func seachUrl(term: String, limit: Int? = nil, types: [MediaType]? = nil) -> URL {

        // Construct url path

        var components = URLComponents()

        components.path = addStorefront(urlString: AppleMusicApi.searchPath)

        // Construct query items

        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: AppleMusicApi.searchTerm, value: term.replaceSpacesWithPluses()))

        if let limit = limit {
            queryItems.append(URLQueryItem(name: AppleMusicApi.searchLimit, value: String(limit)))
        }

        if let types = types {
            let typesString = types.map { $0.rawValue }.joined(separator: ",")
            queryItems.append(URLQueryItem(name: AppleMusicApi.searchTypes, value: typesString))
        }

        components.queryItems = queryItems

        // Construct final url

        return components.url(relativeTo: baseApiUrl)!
    }

    private func fetchURL(mediaType: MediaType, id: String, include: [Include]? = nil) -> URL {
        var components = URLComponents()
        var fetchPath: String

        switch mediaType {
        case .artists: fetchPath = AppleMusicApi.artistPath
        case .albums: fetchPath = AppleMusicApi.albumsPath
        case .songs: fetchPath = AppleMusicApi.songsPath
        case .playlists: fetchPath = AppleMusicApi.playlistsPath
        case .musicVideos: fetchPath = AppleMusicApi.musicVideosPath
        }

        // Include
        if let include = include {
            let query = URLQueryItem(name: "include", value: include.map { $0.rawValue }.joined(separator: ","))
            components.queryItems = [query]
        }

        components.path = addStorefront(urlString: fetchPath).replacingOccurrences(of: "{id}", with: id)

        return components.url(relativeTo: baseApiUrl)!.absoluteURL
    }

    private func addStorefront(urlString: String) -> String {
        return urlString.replacingOccurrences(of: "{storefront}", with: storefront.rawValue)
    }

    // MARK: Construct requests

    func searchRequest(term: String, limit: Int? = nil, types: [MediaType]? = nil) -> URLRequest {
        let url = seachUrl(term: term, limit: limit, types: types)
        return constructRequest(url: url)
    }

    func fetchRequest(mediaType: MediaType, id: String, include: [Include]? = nil) -> URLRequest {
        let url = fetchURL(mediaType: mediaType, id: id, include: include)
        return constructRequest(url: url)
    }

    private func constructRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
        request = addAuth(request: request)

        return request
    }

    // MARK: Add authentication

    private func addAuth(request: URLRequest) -> URLRequest {
        var request = request

        let authHeader = "Bearer \(developerToken)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        return request
    }

    func addUserToken(request: URLRequest) throws -> URLRequest {
        guard let userToken = userToken else {
            throw CiderUrlBuilderError.noUserToken
        }

        var request = request
        request.setValue(userToken, forHTTPHeaderField: "Music-User-Token")

        return request
    }
}

// MARK: - Helpers

private extension String {
    func replaceSpacesWithPluses() -> String {
        return self.replacingOccurrences(of: " ", with: "+")
    }
}