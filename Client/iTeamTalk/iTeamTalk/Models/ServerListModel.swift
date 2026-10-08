/*
 * Copyright (c) 2005-2018, BearWare.dk
 *
 * Contact Information:
 *
 * Bjoern D. Rasmussen
 * Kirketoften 5
 * DK-8260 Viby J
 * Denmark
 * Email: contact@bearware.dk
 * Phone: +45 20 20 54 59
 * Web: http://www.bearware.dk
 *
 * This source code is part of the TeamTalk SDK owned by
 * BearWare.dk. Use of this file, or its compiled unit, requires a
 * TeamTalk SDK License Key issued by BearWare.dk.
 *
 * The TeamTalk SDK License Agreement along with its Terms and
 * Conditions are outlined in the file License.txt included with the
 * TeamTalk SDK distribution.
 *
 */

import SwiftUI
import UIKit

enum ServerType {
    case LOCAL,
    OFFICIAL,
    PUBLIC,
    UNOFFICIAL
}

// Properties of a TeamTalk server to connect to
class Server: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool {
        true
    }

    var name = ""
    var ipaddr = ""
    var tcpport = AppInfo.DEFAULT_TCPPORT
    var udpport = AppInfo.DEFAULT_UDPPORT
    var joincode = ""
    var nickname = ""
    var username = ""
    var password = ""
    var channel = ""
    var chanpasswd = ""
    var servertype: ServerType = .LOCAL
    var encrypted = false
    var cacertdata = ""
    var certdata = ""
    var certprivkeydata = ""
    var certverifypeer = false

    // stats from public server list
    var stats_usercount = 0
    var stats_country = ""
    var stats_servername = ""
    var stats_motd = ""

    override init() {

    }

    required init?(coder dec: NSCoder) {
        name = Server.decodeString(dec, forKey: "name")
        ipaddr = Server.decodeString(dec, forKey: "ipaddr")
        tcpport = dec.decodeInteger(forKey: "tcpport")
        udpport = dec.decodeInteger(forKey: "udpport")
        username = Server.decodeString(dec, forKey: "username")
        password = Server.decodeString(dec, forKey: "password")
        nickname = Server.decodeString(dec, forKey: "nickname")
        channel = Server.decodeString(dec, forKey: "channel")
        chanpasswd = Server.decodeString(dec, forKey: "chanpasswd")
        encrypted = dec.decodeBool(forKey: "encrypted")
        cacertdata = Server.decodeString(dec, forKey: "cacertdata")
        certdata = Server.decodeString(dec, forKey: "certdata")
        certprivkeydata = Server.decodeString(dec, forKey: "certprivkeydata")
        certverifypeer = dec.decodeBool(forKey: "certverifypeer")
    }

    func encode(with enc: NSCoder) {
        enc.encode(name, forKey: "name")
        enc.encode(ipaddr, forKey: "ipaddr")
        enc.encode(tcpport, forKey: "tcpport")
        enc.encode(udpport, forKey: "udpport")
        enc.encode(username, forKey: "username")
        enc.encode(password, forKey: "password")
        enc.encode(nickname, forKey: "nickname")
        enc.encode(channel, forKey: "channel")
        enc.encode(chanpasswd, forKey: "chanpasswd")
        enc.encode(encrypted, forKey: "encrypted")
        enc.encode(cacertdata, forKey: "cacertdata")
        enc.encode(certdata, forKey: "certdata")
        enc.encode(certprivkeydata, forKey: "certprivkeydata")
        enc.encode(certverifypeer, forKey: "certverifypeer")
    }

    private static func decodeString(_ decoder: NSCoder, forKey key: String) -> String {
        if let value = decoder.decodeObject(of: NSString.self, forKey: key) {
            return value as String
        }
        return ""
    }
}

func loadLocalServers() -> [Server] {
    var servers = [Server]()
    let defaults = UserDefaults.standard
    if let stored = defaults.array(forKey: "ServerList") {
        for e in stored {
            let data = e as! Data
            if let server = try? NSKeyedUnarchiver.unarchivedObject(ofClass: Server.self, from: data) {
                servers.append(server)
            }
        }
    }
    return servers
}

func saveLocalServers(_ servers: [Server]) {
    let defaults = UserDefaults.standard
    var s_array = [Data]()
    for s in servers {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: s, requiringSecureCoding: true) {
            s_array.append(data)
        }
    }
    defaults.set(s_array, forKey: "ServerList")
    defaults.synchronize()
}

// MARK: - Last server, for "Connect on Startup"

let PREF_LASTSERVER = "LastServer"
let PREF_LASTSERVER_CHANNEL = "LastServerChannel"
let PREF_LASTSERVER_CHANPASSWD = "LastServerChannelPassword"

func saveLastServer(_ server: Server) {
    if let data = try? NSKeyedArchiver.archivedData(withRootObject: server, requiringSecureCoding: true) {
        UserDefaults.standard.set(data, forKey: PREF_LASTSERVER)
    }
}

/// The last server that was logged in to, set to join the last channel joined
func loadLastServer() -> Server? {
    let defaults = UserDefaults.standard
    guard let data = defaults.data(forKey: PREF_LASTSERVER),
          let server = try? NSKeyedUnarchiver.unarchivedObject(ofClass: Server.self, from: data) else {
        return nil
    }
    server.channel = defaults.string(forKey: PREF_LASTSERVER_CHANNEL) ?? ""
    server.chanpasswd = defaults.string(forKey: PREF_LASTSERVER_CHANPASSWD) ?? ""
    return server
}

// MARK: - Sharing a server

/// A .tt file with the address of the server and nothing else: the user name
/// and password stay on this device.
func writeServerFile(_ server: Server) -> URL? {
    func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <teamtalk version="5.0">
            <host>
                <name>\(escape(server.name))</name>
                <address>\(escape(server.ipaddr))</address>
                <tcpport>\(server.tcpport)</tcpport>
                <udpport>\(server.udpport)</udpport>
                <encrypted>\(server.encrypted ? "true" : "false")</encrypted>
            </host>
        </teamtalk>

        """

    var fileName = server.name.isEmpty ? server.ipaddr : server.name
    fileName = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName + ".tt")
    do {
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    } catch {
        return nil
    }
}

/// The same address as a tt:// link
func serverLink(_ server: Server) -> String {
    "\(AppInfo.TTLINK_PREFIX)\(server.ipaddr)?tcpport=\(server.tcpport)&udpport=\(server.udpport)&encrypted=\(server.encrypted ? "1" : "0")"
}

// MARK: - Navigation destination

enum ServerListDestination: Hashable {
    case preferences(PreferencesModel)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.preferences(let a), .preferences(let b)): return a === b
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .preferences(let m): hasher.combine(0); hasher.combine(ObjectIdentifier(m))
        }
    }
}

// MARK: - Server List Model

final class ServerListModel: ObservableObject {
    @Published var servers: [Server] = []
    @Published var navigationPath: [ServerListDestination] = []
    @Published var activeMainTabModel: MainTabModel?
    @Published var serverDetailModel: ServerDetailModel?
    @Published var serverPendingDeletion: Server?

    // Join code alert
    @Published var showJoinCodeAlert = false
    @Published var joinCodeInput = ""

    // Error alert
    @Published var errorMessage: String?

    // Search, favorites and sharing
    @Published var searchText = ""
    @Published var favorites = Set(UserDefaults.standard.stringArray(forKey: "FavoriteServers") ?? [])
    @Published var sharedFile: SharedFile?

    var nextappupdate = Date()

    // once per launch, not every time the list comes back after disconnecting
    private static var didConnectOnStartup = false

    init() {}

    // MARK: - Search and favorites

    private func favoriteKey(_ server: Server) -> String {
        "\(server.ipaddr):\(server.tcpport)"
    }

    func isFavorite(_ server: Server) -> Bool {
        favorites.contains(favoriteKey(server))
    }

    func toggleFavorite(_ server: Server) {
        let key = favoriteKey(server)
        if favorites.contains(key) {
            favorites.remove(key)
        } else {
            favorites.insert(key)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "FavoriteServers")
    }

    /// The servers that match the search, favorites first
    var visibleServers: [Server] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matching = query.isEmpty ? servers : servers.filter {
            $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil ||
                $0.ipaddr.range(of: query, options: .caseInsensitive) != nil
        }
        return matching.filter { isFavorite($0) } + matching.filter { !isFavorite($0) }
    }

    func shareServer(_ server: Server) {
        if let url = writeServerFile(server) {
            sharedFile = SharedFile(url: url)
        }
    }

    func copyLink(of server: Server) {
        UIPasteboard.general.string = serverLink(server)
        announceForAccessibility(String(localized: "Link copied", comment: "serverlist"))
    }

    // MARK: - On-appear lifecycle

    func onAppear() {
        servers = loadLocalServers()

        if !ServerListModel.didConnectOnStartup {
            ServerListModel.didConnectOnStartup = true
            if UserDefaults.standard.bool(forKey: PREF_CONNECT_LASTSERVER), let server = loadLastServer() {
                connect(to: server)
            }
        }

        let defaults = UserDefaults.standard
        let downloadOfficial = defaults.object(forKey: PREF_DISPLAY_OFFICIALSERVERS) == nil || defaults.bool(forKey: PREF_DISPLAY_OFFICIALSERVERS)
        let downloadPublic = defaults.object(forKey: PREF_DISPLAY_PUBLICSERVERS) == nil || defaults.bool(forKey: PREF_DISPLAY_PUBLICSERVERS)
        let downloadUnofficial = defaults.object(forKey: PREF_DISPLAY_UNOFFICIALSERVERS) != nil && defaults.bool(forKey: PREF_DISPLAY_UNOFFICIALSERVERS)

        if downloadOfficial || downloadPublic || downloadUnofficial {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.downloadServerList()
            }
        }

        if (nextappupdate as NSDate).earlierDate(Date()) == nextappupdate {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.checkAppUpdate()
            }
        }
    }

    // MARK: - Navigation actions

    func openPreferences() {
        navigationPath.append(.preferences(PreferencesModel()))
    }

    func addServer() {
        showServerDetail(for: Server())
    }

    func showServerDetail(for server: Server) {
        serverDetailModel = ServerDetailModel(server: server)
    }

    func connect(to server: Server) {
        navigationPath.removeAll()
        activeMainTabModel = MainTabModel(server: server)
    }

    func closeActiveServer() {
        activeMainTabModel = nil
    }

    func deleteServer(_ server: Server) {
        servers.removeAll { $0 === server }
        saveServerList()
    }

    func upsertServer(_ server: Server) {
        if let idx = servers.firstIndex(where: { $0.name == server.name }) {
            servers[idx] = server
        } else {
            servers.append(server)
        }
        saveServerList()
    }

    func saveServerList() {
        saveLocalServers(servers.filter { $0.servertype == .LOCAL })
    }

    // MARK: - Join code

    func submitJoinCode() {
        guard !joinCodeInput.isEmpty else { return }
        downloadServer(joincode: joinCodeInput)
        joinCodeInput = ""
    }

    // MARK: - URL handling

    func openUrl(_ url: URL) {
        var server = Server()

        if url.isFileURL {
            let serverparser = ServerParser()
            if let parser = XMLParser(contentsOf: url) {
                parser.delegate = serverparser
                parser.parse()
            }
            for s in serverparser.servers {
                server = s
            }
        } else if url.absoluteString.starts(with: AppInfo.TTLINK_PREFIX) {
            server = parseTeamTalkURL(url)
        }

        if !server.ipaddr.isEmpty {
            navigationPath.removeAll()
            connect(to: server)
        }
    }

    private func parseTeamTalkURL(_ url: URL) -> Server {
        let server = Server()
        do {
            let url_str = url.absoluteString
            let ns_str = url_str as NSString
            let url_range = NSMakeRange(0, url_str.count)

            func extract(_ pattern: String) throws -> String? {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: url_str, options: .reportCompletion, range: url_range)
                guard let m = matches.first else { return nil }
                return ns_str.substring(with: m.range(at: 1))
            }

            if let host = try extract(AppInfo.TTLINK_PREFIX + "([^\\??!/]*)/?\\??") {
                server.ipaddr = host
            }
            if let s = try extract("[&|\\?]tcpport=(\\d+)"), let port = Int(s) {
                server.tcpport = port
            }
            if let s = try extract("[&|\\?]udpport=(\\d+)"), let port = Int(s) {
                server.udpport = port
            }
            if let s = try extract("[&|\\?]encrypted=([^&]*)") {
                server.encrypted = s == "true" || s == "1"
            }
            if let s = try extract("[&|\\?]username=([^&]*)") {
                server.username = s.removingPercentEncoding ?? s
            }
            if let s = try extract("[&|\\?]password=([^&]*)") {
                server.password = s.removingPercentEncoding ?? s
            }
            if let s = try extract("[&|\\?]nickname=([^&]*)") {
                server.nickname = s.removingPercentEncoding ?? s
            }
            if let s = try extract("[&|\\?]channel=([^&]*)") {
                server.channel = s.removingPercentEncoding ?? s
            }
            if let s = try extract("[&|\\?]chanpasswd=([^&]*)") {
                server.chanpasswd = s.removingPercentEncoding ?? s
            }
        } catch {}
        return server
    }

    // MARK: - Network operations

    func checkAppUpdate() {
        guard let url = URL(string: AppInfo.getUpdateURL()) else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                print("Failed to check app update \(url.absoluteString)")
                return
            }
            let parser = XMLParser(data: data)
            let updateparser = AppUpdateParser()
            parser.delegate = updateparser
            parser.parse()
            if !updateparser.registerUrl.isEmpty {
                AppInfo.BEARWARE_REGISTRATION_WEBSITE = updateparser.registerUrl
            }
        }
        task.resume()
        nextappupdate = nextappupdate.addingTimeInterval(60 * 60 * 24)
    }

    func downloadServerList() {
        let defaults = UserDefaults.standard
        let official = defaults.object(forKey: PREF_DISPLAY_OFFICIALSERVERS) == nil || defaults.bool(forKey: PREF_DISPLAY_OFFICIALSERVERS)
        let unofficial = defaults.object(forKey: PREF_DISPLAY_UNOFFICIALSERVERS) != nil && defaults.bool(forKey: PREF_DISPLAY_UNOFFICIALSERVERS)

        guard let url = URL(string: AppInfo.getServersURL(officialservers: official, unofficialservers: unofficial)) else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                print("Failed to download server list \(url.absoluteString)")
                return
            }
            DispatchQueue.main.async {
                self.insertServerList(data: data)
            }
        }
        task.resume()
    }

    func insertServerList(data: Data) {
        let parser = XMLParser(data: data)
        let serverparser = ServerParser()
        parser.delegate = serverparser
        parser.parse()
        for s in serverparser.servers {
            servers.append(s)
        }
    }

    func downloadServer(joincode: String) {
        guard let url = URL(string: AppInfo.getBearWareJoinCode(joincode: joincode)) else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                print("Failed to download server from joincode")
                return
            }
            DispatchQueue.main.async {
                let parser = XMLParser(data: data)
                let serverparser = ServerParser()
                parser.delegate = serverparser
                parser.parse()

                if !serverparser.currentServer.ipaddr.isEmpty {
                    self.connect(to: serverparser.currentServer)
                } else {
                    self.errorMessage = String(localized: "No server found", comment: "serverlist")
                }
            }
        }
        task.resume()
    }
}

// MARK: - XML Parsers

class AppUpdateParser: NSObject, XMLParserDelegate {

    var elementStack = [String]()
    var update = ""
    var registerUrl = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String]) {
        elementStack.append(elementName)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let path = getXMLPath(elementStack: elementStack)
        switch path {
        case "/teamtalk/update/name":
            update = string
        case "/teamtalk/bearware/register-url":
            registerUrl = string
        default:
            print("Unknown path " + path)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?) {
        self.elementStack.removeLast()
    }
}

class ServerParser: NSObject, XMLParserDelegate {

    var currentServer = Server()
    var elementStack = [String]()
    var servers = [Server]()

    func parser(_ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String]) {
        elementStack.append(elementName)
        if elementName == "host" {
            currentServer = Server()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let currentElement = elementStack.last else { return }

        switch currentElement {
        case "teamtalk": break
        case "host": break
        case "id": break
        case "name":
            currentServer.name = string
        case "address":
            currentServer.ipaddr = string
        case "tcpport":
            if let port = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                currentServer.tcpport = port
            }
        case "udpport":
            if let port = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                currentServer.udpport = port
            }
        case "encrypted":
            currentServer.encrypted = string == "true"
        case "joincode":
            currentServer.joincode = string
        case "listing":
            if string == "official" {
                currentServer.servertype = .OFFICIAL
            } else if string == "public" {
                currentServer.servertype = .PUBLIC
            } else if string == "private" {
                currentServer.servertype = .UNOFFICIAL
            }
        case "auth": break
        case "join": break
        case "username":
            currentServer.username = string
        case "password":
            if elementStack.firstIndex(of: "auth") != nil {
                currentServer.password = string
            } else if elementStack.firstIndex(of: "join") != nil {
                currentServer.chanpasswd = string
            }
        case "nickname":
            currentServer.nickname = string
        case "channel":
            currentServer.channel = string
        case "stats": break
        case "user-count":
            currentServer.stats_usercount = Int(string) ?? 0
        case "country":
            currentServer.stats_country = string
        case "servername":
            currentServer.stats_servername += string
        case "motd":
            currentServer.stats_motd += string
        case "active":
            break
        case "trusted-certificate": break
        case "certificate-authority-pem":
            currentServer.cacertdata += string
        case "client-certificate-pem":
            currentServer.certdata += string
        case "client-private-key-pem":
            currentServer.certprivkeydata += string
        case "verify-peer":
            currentServer.certverifypeer = string == "true"
        default:
            print("Unknown tag " + currentElement)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?) {
        self.elementStack.removeLast()
        if elementName == "host" {
            servers.append(currentServer)
        }
    }
}
