import Foundation
import TeamTalkC

public enum TeamTalkUserStringProperty {
    case nickname
    case username
    case statusMessage
    case ipAddress
    case clientName

    var cValue: TTKitUserStringProperty {
        switch self {
        case .nickname:
            return TTKitUserStringNickname
        case .username:
            return TTKitUserStringUsername
        case .statusMessage:
            return TTKitUserStringStatusMessage
        case .ipAddress:
            return TTKitUserStringIPAddress
        case .clientName:
            return TTKitUserStringClientName
        }
    }
}

public enum TeamTalkChannelStringProperty {
    case name
    case password
    case topic
    case operatorPassword

    var cValue: TTKitChannelStringProperty {
        switch self {
        case .name:
            return TTKitChannelStringName
        case .password:
            return TTKitChannelStringPassword
        case .topic:
            return TTKitChannelStringTopic
        case .operatorPassword:
            return TTKitChannelStringOperatorPassword
        }
    }
}

public enum TeamTalkServerStringProperty {
    case name
    case accessToken

    var cValue: TTKitServerStringProperty {
        switch self {
        case .name:
            return TTKitServerStringName
        case .accessToken:
            return TTKitServerStringAccessToken
        }
    }
}

public enum TeamTalkUserAccountStringProperty {
    case initialChannel
    case username
    case note
    case password
    /// Written by the server, read-only
    case lastModified
    case lastLogin

    var cValue: TTKitUserAccountStringProperty {
        switch self {
        case .initialChannel:
            return TTKitUserAccountStringInitialChannel
        case .username:
            return TTKitUserAccountStringUsername
        case .note:
            return TTKitUserAccountStringNote
        case .password:
            return TTKitUserAccountStringPassword
        case .lastModified:
            return TTKitUserAccountStringLastModified
        case .lastLogin:
            return TTKitUserAccountStringLastLogin
        }
    }
}

public enum TeamTalkEncryptionStringProperty {
    case caFile
    case certificateFile
    case privateKeyFile

    var cValue: TTKitEncryptionStringProperty {
        switch self {
        case .caFile:
            return TTKitEncryptionCAFile
        case .certificateFile:
            return TTKitEncryptionCertificateFile
        case .privateKeyFile:
            return TTKitEncryptionPrivateKeyFile
        }
    }
}

public enum TeamTalkRemoteFileStringProperty {
    case fileName
    case username
    case uploadTime

    var cValue: TTKitRemoteFileStringProperty {
        switch self {
        case .fileName:
            return TTKitRemoteFileStringFileName
        case .username:
            return TTKitRemoteFileStringUsername
        case .uploadTime:
            return TTKitRemoteFileStringUploadTime
        }
    }
}

public enum TeamTalkFileTransferStringProperty {
    case localFilePath
    case remoteFileName

    var cValue: TTKitFileTransferStringProperty {
        switch self {
        case .localFilePath:
            return TTKitFileTransferStringLocalFilePath
        case .remoteFileName:
            return TTKitFileTransferStringRemoteFileName
        }
    }
}

public enum TeamTalkBannedUserStringProperty {
    case ipAddress
    case channelPath
    case banTime
    case nickname
    case username
    case owner

    var cValue: TTKitBannedUserStringProperty {
        switch self {
        case .ipAddress:
            return TTKitBannedUserStringIPAddress
        case .channelPath:
            return TTKitBannedUserStringChannelPath
        case .banTime:
            return TTKitBannedUserStringBanTime
        case .nickname:
            return TTKitBannedUserStringNickname
        case .username:
            return TTKitBannedUserStringUsername
        case .owner:
            return TTKitBannedUserStringOwner
        }
    }
}

/// The transmitUsers of a channel: in a classroom channel the users allowed
/// to transmit, in any other channel the users blocked from transmitting.
public enum TeamTalkTransmitUsers {
    /// Stands for every user of a classroom channel
    public static let freeForAll = Int32(TT_TRANSMITUSERS_FREEFORALL)

    public static func streamTypes(for userID: Int32, in channel: Channel) -> UInt32 {
        var channel = channel
        return TTKitGetTransmitTypes(&channel, userID)
    }

    public static func set(_ streamTypes: UInt32, for userID: Int32, in channel: inout Channel) {
        TTKitSetTransmitTypes(&channel, userID, streamTypes)
    }
}

public enum TeamTalkMessagePayload {
    public static func channel(from message: TTMessage) -> Channel {
        var message = message
        return TTKitMessageChannel(&message)
    }

    public static func user(from message: TTMessage) -> User {
        var message = message
        return TTKitMessageUser(&message)
    }

    public static func serverProperties(from message: TTMessage) -> ServerProperties {
        var message = message
        return TTKitMessageServerProperties(&message)
    }

    public static func userAccount(from message: TTMessage) -> UserAccount {
        var message = message
        return TTKitMessageUserAccount(&message)
    }

    public static func clientError(from message: TTMessage) -> ClientErrorMsg {
        var message = message
        return TTKitMessageClientError(&message)
    }

    public static func textMessage(from message: TTMessage) -> TextMessage {
        var message = message
        return TTKitMessageTextMessage(&message)
    }

    public static func remoteFile(from message: TTMessage) -> RemoteFile {
        var message = message
        return TTKitMessageRemoteFile(&message)
    }

    public static func fileTransfer(from message: TTMessage) -> FileTransfer {
        var message = message
        return TTKitMessageFileTransfer(&message)
    }

    public static func bannedUser(from message: TTMessage) -> BannedUser {
        var message = message
        return TTKitMessageBannedUser(&message)
    }

    public static func mediaFileInfo(from message: TTMessage) -> MediaFileInfo {
        var message = message
        return TTKitMessageMediaFileInfo(&message)
    }

    public static func isActive(_ message: TTMessage) -> Bool {
        var message = message
        return TTKitMessageActiveFlag(&message) != 0
    }

    public static func hasUserPayload(_ message: TTMessage) -> Bool {
        message.ttType == __USER
    }
}

public enum TeamTalkString {
    public static func user(_ property: TeamTalkUserStringProperty, from user: User) -> String {
        var user = user
        return String(cString: TTKitGetUserString(property.cValue, &user))
    }

    public static func channel(_ property: TeamTalkChannelStringProperty, from channel: Channel) -> String {
        var channel = channel
        return String(cString: TTKitGetChannelString(property.cValue, &channel))
    }

    public static func textMessage(_ message: TextMessage) -> String {
        var message = message
        return String(cString: TTKitGetTextMessageString(&message))
    }

    public static func serverProperties(_ property: TeamTalkServerStringProperty, from serverProperties: ServerProperties) -> String {
        var serverProperties = serverProperties
        return String(cString: TTKitGetServerPropertiesString(property.cValue, &serverProperties))
    }

    public static func clientError(_ clientError: ClientErrorMsg) -> String {
        var clientError = clientError
        return String(cString: TTKitGetClientErrorMessageString(&clientError))
    }

    public static func userAccount(_ property: TeamTalkUserAccountStringProperty, from userAccount: UserAccount) -> String {
        var userAccount = userAccount
        return String(cString: TTKitGetUserAccountString(property.cValue, &userAccount))
    }

    public static func bannedUser(_ property: TeamTalkBannedUserStringProperty, from bannedUser: BannedUser) -> String {
        var bannedUser = bannedUser
        return String(cString: TTKitGetBannedUserString(property.cValue, &bannedUser))
    }

    public static func remoteFile(_ property: TeamTalkRemoteFileStringProperty, from remoteFile: RemoteFile) -> String {
        var remoteFile = remoteFile
        return String(cString: TTKitGetRemoteFileString(property.cValue, &remoteFile))
    }

    public static func fileTransfer(_ property: TeamTalkFileTransferStringProperty, from fileTransfer: FileTransfer) -> String {
        var fileTransfer = fileTransfer
        return String(cString: TTKitGetFileTransferString(property.cValue, &fileTransfer))
    }

    public static func setChannel(_ property: TeamTalkChannelStringProperty, on channel: inout Channel, to string: String) {
        TTKitSetChannelString(property.cValue, &channel, string)
    }

    public static func setTextMessage(_ message: inout TextMessage, to string: String) {
        TTKitSetTextMessageString(&message, string)
    }

    public static func setUserAccount(_ property: TeamTalkUserAccountStringProperty, on userAccount: inout UserAccount, to string: String) {
        TTKitSetUserAccountString(property.cValue, &userAccount, string)
    }

    public static func setEncryption(_ property: TeamTalkEncryptionStringProperty, on encryption: inout EncryptionContext, to string: String) {
        TTKitSetEncryptionString(property.cValue, &encryption, string)
    }
}

public enum TeamTalkTextMessageFactory {
    public static func messages(from message: TextMessage, content: String) -> [TextMessage] {
        var result = [TextMessage]()
        var newMessage = message

        if content.lengthOfBytes(using: .utf8) <= TT_STRLEN - 1 {
            TeamTalkString.setTextMessage(&newMessage, to: content)
            newMessage.bMore = 0
            result.append(newMessage)
            return result
        }

        newMessage.bMore = 1
        var currentLength = content.count
        while content.prefix(currentLength).lengthOfBytes(using: .utf8) > TT_STRLEN - 1 {
            currentLength /= 2
        }

        var half = Int(TT_STRLEN) / 2
        while half > 0 {
            let utf8Length = content.prefix(currentLength + half).lengthOfBytes(using: .utf8)
            if utf8Length <= TT_STRLEN - 1 {
                currentLength += half
            }
            if utf8Length == TT_STRLEN - 1 {
                break
            }
            half /= 2
        }

        TeamTalkString.setTextMessage(&newMessage, to: String(content.prefix(currentLength)))
        result.append(newMessage)

        let remainingCount = content.count - currentLength
        result.append(contentsOf: messages(from: newMessage, content: String(content.suffix(remainingCount))))
        return result
    }
}
