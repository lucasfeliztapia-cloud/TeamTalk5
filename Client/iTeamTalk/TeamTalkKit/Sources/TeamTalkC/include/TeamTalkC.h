#include "../../../../../../Library/TeamTalk_DLL/TeamTalk.h"

typedef enum {
    TTKitUserStringNickname,
    TTKitUserStringUsername,
    TTKitUserStringStatusMessage,
    TTKitUserStringIPAddress,
    TTKitUserStringClientName
} TTKitUserStringProperty;

typedef enum {
    TTKitChannelStringName,
    TTKitChannelStringPassword,
    TTKitChannelStringTopic,
    TTKitChannelStringOperatorPassword
} TTKitChannelStringProperty;

typedef enum {
    TTKitServerStringName,
    TTKitServerStringAccessToken
} TTKitServerStringProperty;

typedef enum {
    TTKitUserAccountStringInitialChannel,
    TTKitUserAccountStringUsername,
    TTKitUserAccountStringNote
} TTKitUserAccountStringProperty;

typedef enum {
    TTKitEncryptionCAFile,
    TTKitEncryptionCertificateFile,
    TTKitEncryptionPrivateKeyFile
} TTKitEncryptionStringProperty;

typedef enum {
    TTKitRemoteFileStringFileName,
    TTKitRemoteFileStringUsername,
    TTKitRemoteFileStringUploadTime
} TTKitRemoteFileStringProperty;

typedef enum {
    TTKitFileTransferStringLocalFilePath,
    TTKitFileTransferStringRemoteFileName
} TTKitFileTransferStringProperty;

typedef enum {
    TTKitBannedUserStringIPAddress,
    TTKitBannedUserStringChannelPath,
    TTKitBannedUserStringBanTime,
    TTKitBannedUserStringNickname,
    TTKitBannedUserStringUsername,
    TTKitBannedUserStringOwner
} TTKitBannedUserStringProperty;

AudioCodec TTKitMakeAudioCodec(Codec codec);
OpusCodec TTKitMakeOpusCodec(void);
SpeexCodec TTKitMakeSpeexCodec(void);
SpeexVBRCodec TTKitMakeSpeexVBRCodec(void);

OpusCodec TTKitGetOpusCodec(const AudioCodec* audioCodec);
SpeexCodec TTKitGetSpeexCodec(const AudioCodec* audioCodec);
SpeexVBRCodec TTKitGetSpeexVBRCodec(const AudioCodec* audioCodec);

void TTKitSetOpusCodec(AudioCodec* audioCodec, const OpusCodec* opusCodec);
void TTKitSetSpeexCodec(AudioCodec* audioCodec, const SpeexCodec* speexCodec);
void TTKitSetSpeexVBRCodec(AudioCodec* audioCodec, const SpeexVBRCodec* speexVBRCodec);

VideoCodec TTKitMakeWebMVP8VideoCodec(INT32 targetBitrate);
VideoCodec TTKitMakeNoVideoCodec(void);

Channel TTKitMessageChannel(const TTMessage* message);
User TTKitMessageUser(const TTMessage* message);
ServerProperties TTKitMessageServerProperties(const TTMessage* message);
UserAccount TTKitMessageUserAccount(const TTMessage* message);
ClientErrorMsg TTKitMessageClientError(const TTMessage* message);
TextMessage TTKitMessageTextMessage(const TTMessage* message);
RemoteFile TTKitMessageRemoteFile(const TTMessage* message);
FileTransfer TTKitMessageFileTransfer(const TTMessage* message);
MediaFileInfo TTKitMessageMediaFileInfo(const TTMessage* message);
BannedUser TTKitMessageBannedUser(const TTMessage* message);
TTBOOL TTKitMessageActiveFlag(const TTMessage* message);

const TTCHAR* TTKitGetUserString(TTKitUserStringProperty property, const User* user);
const TTCHAR* TTKitGetChannelString(TTKitChannelStringProperty property, const Channel* channel);
const TTCHAR* TTKitGetTextMessageString(const TextMessage* message);
const TTCHAR* TTKitGetServerPropertiesString(TTKitServerStringProperty property, const ServerProperties* serverProperties);
const TTCHAR* TTKitGetClientErrorMessageString(const ClientErrorMsg* clientError);
const TTCHAR* TTKitGetUserAccountString(TTKitUserAccountStringProperty property, const UserAccount* userAccount);
const TTCHAR* TTKitGetRemoteFileString(TTKitRemoteFileStringProperty property, const RemoteFile* remoteFile);
const TTCHAR* TTKitGetFileTransferString(TTKitFileTransferStringProperty property, const FileTransfer* fileTransfer);
const TTCHAR* TTKitGetBannedUserString(TTKitBannedUserStringProperty property, const BannedUser* bannedUser);

/* The stream types listed for a user in the transmitUsers of a channel, or none. */
StreamTypes TTKitGetTransmitTypes(const Channel* channel, INT32 userID);
/* Lists a user with those stream types, or takes the user off the list if none. */
void TTKitSetTransmitTypes(Channel* channel, INT32 userID, StreamTypes streamTypes);

void TTKitSetChannelString(TTKitChannelStringProperty property, Channel* channel, const TTCHAR* string);
void TTKitSetTextMessageString(TextMessage* message, const TTCHAR* string);
void TTKitSetEncryptionString(TTKitEncryptionStringProperty property, EncryptionContext* encryption, const TTCHAR* string);
