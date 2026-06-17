import Foundation
import Network

class WebServerManager: ObservableObject {
    static let shared = WebServerManager()
    
    @Published var isRunning = false
    @Published var serverAddresses: [String] = []
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var photoManager: PhotoLibraryManager?
    private var currentPort: UInt16 = 8080
    
    private init() {}
    
    func startServer(photoManager: PhotoLibraryManager) {
        self.photoManager = photoManager
        
        var port = currentPort
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true
                
                listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
                
                listener?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        DispatchQueue.main.async {
                            self?.currentPort = port
                            self?.isRunning = true
                            self?.updateServerAddresses()
                        }
                    case .failed(let error):
                        print("Server failed on port \(port): \(error)")
                        DispatchQueue.main.async {
                            self?.isRunning = false
                        }
                    default:
                        break
                    }
                }
                
                listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleConnection(connection)
                }
                
                listener?.start(queue: .global(qos: .userInitiated))
                break
                
            } catch {
                print("Failed to start server on port \(port): \(error)")
                port += 1
                attempts += 1
                
                if attempts >= maxAttempts {
                    print("Unable to start server after \(maxAttempts) attempts")
                }
            }
        }
    }
    
    func stopServer() {
        listener?.cancel()
        DispatchQueue.main.async {
            self.connections.forEach { $0.cancel() }
            self.connections.removeAll()
            self.isRunning = false
            self.serverAddresses.removeAll()
        }
    }
    
    private func updateServerAddresses() {
        var addresses: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        guard let firstAddr = ifaddr else { return }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name.starts(with: "en") || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    let address = String(cString: hostname)
                    addresses.append("http://\(address):\(currentPort)")
                }
            }
        }
        
        freeifaddrs(ifaddr)
        
        DispatchQueue.main.async {
            self.serverAddresses = addresses
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        DispatchQueue.main.async {
            self.connections.append(connection)
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                DispatchQueue.main.async {
                    self?.connections.removeAll { $0 === connection }
                }
            default:
                break
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
        
        receiveRequest(connection)
    }
    
    private func receiveRequest(_ connection: NWConnection, buffer: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            var newBuffer = buffer
            if let data = data, !data.isEmpty {
                newBuffer.append(data)
            }
            
            // Check if we have received the full HTTP request (headers + body)
            if let (headersLength, contentLength) = self.parseContentLength(from: newBuffer) {
                let totalExpectedLength = headersLength + contentLength
                if newBuffer.count >= totalExpectedLength {
                    self.handleHTTPRequest(data: newBuffer, connection: connection)
                    return
                }
            } else {
                // If there's no Content-Length header, we check if we have received the end of headers (\r\n\r\n)
                if let bodyStartRange = newBuffer.range(of: "\r\n\r\n".data(using: .utf8)!) {
                    let headersData = newBuffer[..<bodyStartRange.lowerBound]
                    if let headersString = String(data: headersData, encoding: .utf8) {
                        let lines = headersString.components(separatedBy: "\r\n")
                        if let firstLine = lines.first {
                            let components = firstLine.components(separatedBy: " ")
                            let method = components.first ?? "GET"
                            if method != "POST" && method != "PUT" {
                                // For non-POST/PUT requests, we don't expect a body, so we can process it immediately
                                self.handleHTTPRequest(data: newBuffer, connection: connection)
                                return
                            }
                        }
                    }
                }
            }
            
            if isComplete {
                if !newBuffer.isEmpty {
                    self.handleHTTPRequest(data: newBuffer, connection: connection)
                } else {
                    connection.cancel()
                }
            } else if error == nil {
                self.receiveRequest(connection, buffer: newBuffer)
            }
        }
    }
    
    private func parseContentLength(from data: Data) -> (headersLength: Int, contentLength: Int)? {
        guard let separatorRange = data.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            return nil
        }
        let headersData = data[..<separatorRange.lowerBound]
        guard let headersString = String(data: headersData, encoding: .utf8) else {
            return nil
        }
        
        let lines = headersString.components(separatedBy: "\r\n")
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0].caseInsensitiveCompare("Content-Length") == .orderedSame {
                if let contentLength = Int(parts[1]) {
                    let headersLength = separatorRange.upperBound
                    return (headersLength, contentLength)
                }
            }
        }
        return nil
    }
    
    private func handleHTTPRequest(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else { return }
        
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let components = requestLine.components(separatedBy: " ")
        
        guard components.count >= 2 else { return }
        let method = components[0]
        let path = components[1]
        
        print("Request: \(method) \(path)")
        
        var rangeHeader: String?
        for line in lines {
            if line.lowercased().hasPrefix("range:") {
                rangeHeader = line
                break
            }
        }
        
        if path == "/" || path == "/index.html" {
            sendWebInterface(connection: connection)
        } else if path == "/api/photos" {
            handleGetPhotos(connection: connection)
        } else if path.starts(with: "/api/photo/") {
            let identifier = String(path.dropFirst("/api/photo/".count))
            handleGetPhoto(identifier: identifier, rangeHeader: rangeHeader, connection: connection)
        } else if path.starts(with: "/api/thumbnail/") {
            let identifier = String(path.dropFirst("/api/thumbnail/".count))
            handleGetThumbnail(identifier: identifier, connection: connection)
        } else if path.starts(with: "/api/metadata/") {
            let identifier = String(path.dropFirst("/api/metadata/".count))
            handleGetMetadata(identifier: identifier, connection: connection)
        } else if path == "/api/delete" && method == "POST" {
            handleDeletePhotos(data: data, connection: connection)
        } else {
            send404(connection: connection)
        }
    }
    
    private func handleGetPhotos(connection: NWConnection) {
        guard let photoManager = photoManager else {
            send500(connection: connection, message: "Photo manager not initialized")
            return
        }
        
        Task {
            await photoManager.loadPhotos()
            let assets = photoManager.getAllAssets()
            var photoList: [[String: Any]] = []
            
            for asset in assets {
                let metadata = photoManager.getAssetMetadata(asset: asset)
                photoList.append(metadata)
            }
            
            sendJSONResponse(connection: connection, data: ["photos": photoList])
        }
    }
    
    private func handleGetPhoto(identifier: String, rangeHeader: String?, connection: NWConnection) {
        print("[handleGetPhoto] Requested: \(identifier)")
        guard let photoManager = photoManager else {
            print("[handleGetPhoto] Error: photoManager not initialized")
            send500(connection: connection, message: "Photo manager not initialized")
            return
        }
        
        guard let asset = photoManager.getAsset(by: identifier) else {
            print("[handleGetPhoto] Error: Asset not found for identifier: \(identifier)")
            send404(connection: connection)
            return
        }
        
        print("[handleGetPhoto] Found asset mediaType: \(asset.mediaType == .image ? "image" : "video")")
        
        if asset.mediaType == .image {
            photoManager.getImageData(asset: asset) { data, mimeType, _ in
                print("[handleGetPhoto] getImageData finished. size: \(data?.count ?? -1), mimeType: \(mimeType)")
                if let data = data {
                    let headers = """
                    HTTP/1.1 200 OK\r
                    Content-Type: \(mimeType)\r
                    Content-Length: \(data.count)\r
                    Access-Control-Allow-Origin: *\r
                    \r
                    
                    """
                    
                    if let headerData = headers.data(using: .utf8) {
                        var responseData = Data()
                        responseData.append(headerData)
                        responseData.append(data)
                        print("[handleGetPhoto] Sending image data: \(responseData.count) bytes")
                        connection.send(content: responseData, completion: .contentProcessed { error in
                            if let error = error {
                                print("[handleGetPhoto] send error: \(error)")
                            } else {
                                print("[handleGetPhoto] send success")
                            }
                            connection.cancel()
                        })
                    }
                } else {
                    print("[handleGetPhoto] Error: getImageData returned nil data")
                    self.send500(connection: connection, message: "Failed to load image")
                }
            }
        } else if asset.mediaType == .video {
            photoManager.getVideoData(asset: asset) { url in
                print("[handleGetPhoto] getVideoData url: \(url?.absoluteString ?? "nil")")
                if let url = url, let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                    var responseData = Data()
                    let headers: String
                    
                    if let rangeStr = rangeHeader, let range = self.parseRangeHeader(rangeStr, totalLength: data.count) {
                        let chunk = Data(data[range.start...range.end])
                        print("[handleGetPhoto] Sending video range \(range.start)-\(range.end)/\(data.count) (\(chunk.count) bytes)")
                        headers = """
                        HTTP/1.1 206 Partial Content\r
                        Content-Type: video/mp4\r
                        Content-Range: bytes \(range.start)-\(range.end)/\(data.count)\r
                        Content-Length: \(chunk.count)\r
                        Access-Control-Allow-Origin: *\r
                        \r
                        
                        """
                        if let headerData = headers.data(using: .utf8) {
                            responseData.append(headerData)
                            responseData.append(chunk)
                        }
                    } else {
                        print("[handleGetPhoto] Sending full video data: \(data.count) bytes")
                        headers = """
                        HTTP/1.1 200 OK\r
                        Content-Type: video/mp4\r
                        Content-Length: \(data.count)\r
                        Access-Control-Allow-Origin: *\r
                        \r
                        
                        """
                        if let headerData = headers.data(using: .utf8) {
                            responseData.append(headerData)
                            responseData.append(data)
                        }
                    }
                    
                    if !responseData.isEmpty {
                        connection.send(content: responseData, completion: .contentProcessed { error in
                            if let error = error {
                                print("[handleGetPhoto] video send error: \(error)")
                            } else {
                                print("[handleGetPhoto] video send success")
                            }
                            connection.cancel()
                        })
                    }
                } else {
                    print("[handleGetPhoto] Error: failed to load video file")
                    self.send500(connection: connection, message: "Failed to load video")
                }
            }
        }
    }
    
    private func handleGetThumbnail(identifier: String, connection: NWConnection) {
        guard let photoManager = photoManager else {
            send500(connection: connection, message: "Photo manager not initialized")
            return
        }
        
        guard let asset = photoManager.getAsset(by: identifier) else {
            send404(connection: connection)
            return
        }
        
        photoManager.getThumbnail(asset: asset, size: CGSize(width: 600, height: 600)) { image in
            if let image = image, let data = image.jpegData(compressionQuality: 0.85) {
                let headers = """
                HTTP/1.1 200 OK\r
                Content-Type: image/jpeg\r
                Content-Length: \(data.count)\r
                Access-Control-Allow-Origin: *\r
                Cache-Control: max-age=3600\r
                \r
                
                """
                
                if let headerData = headers.data(using: .utf8) {
                    var responseData = Data()
                    responseData.append(headerData)
                    responseData.append(data)
                    connection.send(content: responseData, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            } else {
                self.send500(connection: connection, message: "Failed to generate thumbnail")
            }
        }
    }
    
    private func handleGetMetadata(identifier: String, connection: NWConnection) {
        guard let photoManager = photoManager else {
            send500(connection: connection, message: "Photo manager not initialized")
            return
        }
        
        guard let asset = photoManager.getAsset(by: identifier) else {
            send404(connection: connection)
            return
        }
        
        let metadata = photoManager.getAssetMetadata(asset: asset)
        
        if asset.mediaType == .image {
            photoManager.getImageData(asset: asset) { _, _, exifMetadata in
                var fullMetadata = metadata
                if let exif = exifMetadata {
                    let cleanedExif = self.cleanMetadataForJSON(exif)
                    fullMetadata["exif"] = cleanedExif
                }
                self.sendJSONResponse(connection: connection, data: fullMetadata)
            }
        } else {
            sendJSONResponse(connection: connection, data: metadata)
        }
    }
    
    private func cleanMetadataForJSON(_ metadata: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        
        for (key, value) in metadata {
            if let stringValue = value as? String {
                cleaned[key] = stringValue
            } else if let numberValue = value as? NSNumber {
                cleaned[key] = numberValue
            } else if let boolValue = value as? Bool {
                cleaned[key] = boolValue
            } else if let arrayValue = value as? [Any] {
                cleaned[key] = arrayValue.compactMap { item -> Any? in
                    if item is String || item is NSNumber || item is Bool {
                        return item
                    } else if let dict = item as? [String: Any] {
                        return cleanMetadataForJSON(dict)
                    }
                    return nil
                }
            } else if let dictValue = value as? [String: Any] {
                cleaned[key] = cleanMetadataForJSON(dictValue)
            }
        }
        
        return cleaned
    }
    
    private func handleDeletePhotos(data: Data, connection: NWConnection) {
        guard let photoManager = photoManager else {
            send500(connection: connection, message: "Photo manager not initialized")
            return
        }
        
        let bodyStart = data.range(of: "\r\n\r\n".data(using: .utf8)!)
        guard let bodyStart = bodyStart else {
            send500(connection: connection, message: "Invalid request body")
            return
        }
        
        let bodyData = data[bodyStart.upperBound...]
        
        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let identifiers = json["identifiers"] as? [String] else {
            send500(connection: connection, message: "Invalid JSON")
            return
        }
        
        photoManager.deleteAssets(identifiers: identifiers) { success, error in
            if success {
                self.sendJSONResponse(connection: connection, data: ["success": true])
            } else {
                self.send500(connection: connection, message: error?.localizedDescription ?? "Delete failed")
            }
        }
    }
    
    private func sendWebInterface(connection: NWConnection) {
        let html = getWebInterfaceHTML()
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        \r
        
        """
        
        if let headerData = headers.data(using: .utf8),
           let htmlData = html.data(using: .utf8) {
            var responseData = Data()
            responseData.append(headerData)
            responseData.append(htmlData)
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
    
    private func sendJSONResponse(connection: NWConnection, data: Any) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
            send500(connection: connection, message: "Failed to serialize JSON")
            return
        }
        
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(jsonData.count)\r
        Access-Control-Allow-Origin: *\r
        \r
        
        """
        
        if let headerData = headers.data(using: .utf8) {
            var responseData = Data()
            responseData.append(headerData)
            responseData.append(jsonData)
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
    
    private func send404(connection: NWConnection) {
        let response = """
        HTTP/1.1 404 Not Found\r
        Content-Type: text/plain\r
        Content-Length: 9\r
        \r
        Not Found
        """
        
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
    
    private func send500(connection: NWConnection, message: String) {
        let response = """
        HTTP/1.1 500 Internal Server Error\r
        Content-Type: text/plain\r
        Content-Length: \(message.utf8.count)\r
        \r
        \(message)
        """
        
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
    
    private func parseRangeHeader(_ header: String, totalLength: Int) -> (start: Int, end: Int)? {
        guard let eqIndex = header.firstIndex(of: "=") else { return nil }
        let rangePart = header[header.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)
        let parts = rangePart.components(separatedBy: "-")
        guard parts.count >= 2 else { return nil }
        
        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        let endStr = parts[1].trimmingCharacters(in: .whitespaces)
        
        var start = 0
        var end = totalLength - 1
        
        if startStr.isEmpty && !endStr.isEmpty {
            if let suffixLength = Int(endStr) {
                start = max(0, totalLength - suffixLength)
                end = totalLength - 1
            }
        } else {
            if !startStr.isEmpty {
                start = Int(startStr) ?? 0
            }
            if !endStr.isEmpty {
                end = Int(endStr) ?? (totalLength - 1)
            }
        }
        
        if start < 0 { start = 0 }
        if end >= totalLength { end = totalLength - 1 }
        if start > end { return nil }
        
        return (start, end)
    }
}
