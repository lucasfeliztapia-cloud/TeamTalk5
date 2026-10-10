#include "TeamTalkC.h"
#include <string.h>

enum {
    TTKitDefaultMSecPerPacket = 40,
    TTKitDefaultOpusSampleRate = 48000,
    TTKitDefaultOpusChannels = 1,
    TTKitDefaultOpusComplexity = 10,
    TTKitDefaultOpusBitrate = 32000,
    TTKitDefaultSpeexBandmode = 1,
    TTKitDefaultSpeexQuality = 4,
    TTKitDefaultSpeexVBRBandmode = 1,
    TTKitDefaultSpeexVBRQuality = 4,
    TTKitDefaultSpeexVBRMaxBitrate = 0
};

AudioCodec TTKitMakeAudioCodec(Codec codec) {
    AudioCodec audioCodec = {0};

    switch (codec) {
    case OPUS_CODEC: {
        OpusCodec opusCodec = TTKitMakeOpusCodec();
        TTKitSetOpusCodec(&audioCodec, &opusCodec);
        break;
    }
    case SPEEX_CODEC: {
        SpeexCodec speexCodec = TTKitMakeSpeexCodec();
        TTKitSetSpeexCodec(&audioCodec, &speexCodec);
        break;
    }
    case SPEEX_VBR_CODEC: {
        SpeexVBRCodec speexVBRCodec = TTKitMakeSpeexVBRCodec();
        TTKitSetSpeexVBRCodec(&audioCodec, &speexVBRCodec);
        break;
    }
    case NO_CODEC:
    default:
        audioCodec.nCodec = NO_CODEC;
        break;
    }

    return audioCodec;
}

OpusCodec TTKitMakeOpusCodec(void) {
    OpusCodec opusCodec = {
        TTKitDefaultOpusSampleRate,
        TTKitDefaultOpusChannels,
        OPUS_APPLICATION_VOIP,
        TTKitDefaultOpusComplexity,
        TRUE,
        FALSE,
        TTKitDefaultOpusBitrate,
        TRUE,
        FALSE,
        TTKitDefaultMSecPerPacket,
        0
    };
    return opusCodec;
}

SpeexCodec TTKitMakeSpeexCodec(void) {
    SpeexCodec speexCodec = {
        TTKitDefaultSpeexBandmode,
        TTKitDefaultSpeexQuality,
        TTKitDefaultMSecPerPacket,
        FALSE
    };
    return speexCodec;
}

SpeexVBRCodec TTKitMakeSpeexVBRCodec(void) {
    SpeexVBRCodec speexVBRCodec = {
        TTKitDefaultSpeexVBRBandmode,
        TTKitDefaultSpeexVBRQuality,
        0,
        TTKitDefaultSpeexVBRMaxBitrate,
        TRUE,
        TTKitDefaultMSecPerPacket,
        FALSE
    };
    return speexVBRCodec;
}

OpusCodec TTKitGetOpusCodec(const AudioCodec* audioCodec) {
    return audioCodec->opus;
}

SpeexCodec TTKitGetSpeexCodec(const AudioCodec* audioCodec) {
    return audioCodec->speex;
}

SpeexVBRCodec TTKitGetSpeexVBRCodec(const AudioCodec* audioCodec) {
    return audioCodec->speex_vbr;
}

void TTKitSetOpusCodec(AudioCodec* audioCodec, const OpusCodec* opusCodec) {
    audioCodec->nCodec = OPUS_CODEC;
    audioCodec->opus = *opusCodec;
}

void TTKitSetSpeexCodec(AudioCodec* audioCodec, const SpeexCodec* speexCodec) {
    audioCodec->nCodec = SPEEX_CODEC;
    audioCodec->speex = *speexCodec;
}

void TTKitSetSpeexVBRCodec(AudioCodec* audioCodec, const SpeexVBRCodec* speexVBRCodec) {
    audioCodec->nCodec = SPEEX_VBR_CODEC;
    audioCodec->speex_vbr = *speexVBRCodec;
}

VideoCodec TTKitMakeWebMVP8VideoCodec(INT32 targetBitrate) {
    VideoCodec videoCodec = {0};
    videoCodec.nCodec = WEBM_VP8_CODEC;
    videoCodec.webm_vp8.nRcTargetBitrate = targetBitrate;
    videoCodec.webm_vp8.nEncodeDeadline = WEBM_VPX_DL_REALTIME;
    return videoCodec;
}

VideoCodec TTKitMakeNoVideoCodec(void) {
    VideoCodec videoCodec = {0};
    videoCodec.nCodec = NO_CODEC;
    return videoCodec;
}

Channel TTKitMessageChannel(const TTMessage* message) {
    return message->channel;
}

User TTKitMessageUser(const TTMessage* message) {
    return message->user;
}

ServerProperties TTKitMessageServerProperties(const TTMessage* message) {
    return message->serverproperties;
}

UserAccount TTKitMessageUserAccount(const TTMessage* message) {
    return message->useraccount;
}

ClientErrorMsg TTKitMessageClientError(const TTMessage* message) {
    return message->clienterrormsg;
}

TextMessage TTKitMessageTextMessage(const TTMessage* message) {
    return message->textmessage;
}

RemoteFile TTKitMessageRemoteFile(const TTMessage* message) {
    return message->remotefile;
}

FileTransfer TTKitMessageFileTransfer(const TTMessage* message) {
    return message->filetransfer;
}

MediaFileInfo TTKitMessageMediaFileInfo(const TTMessage* message) {
    return message->mediafileinfo;
}

BannedUser TTKitMessageBannedUser(const TTMessage* message) {
    return message->banneduser;
}

const TTCHAR* TTKitGetBannedUserString(TTKitBannedUserStringProperty property, const BannedUser* bannedUser) {
    switch (property) {
    case TTKitBannedUserStringIPAddress:
        return bannedUser->szIPAddress;
    case TTKitBannedUserStringChannelPath:
        return bannedUser->szChannelPath;
    case TTKitBannedUserStringBanTime:
        return bannedUser->szBanTime;
    case TTKitBannedUserStringNickname:
        return bannedUser->szNickname;
    case TTKitBannedUserStringUsername:
        return bannedUser->szUsername;
    case TTKitBannedUserStringOwner:
        return bannedUser->szOwner;
    }
    return "";
}

StreamTypes TTKitGetTransmitTypes(const Channel* channel, INT32 userID) {
    for (int i = 0; i < TT_TRANSMITUSERS_MAX; ++i) {
        INT32 listed = channel->transmitUsers[i][TT_TRANSMITUSERS_USERID_INDEX];
        if (listed == 0) {
            break;
        }
        if (listed == userID) {
            return (StreamTypes)channel->transmitUsers[i][TT_TRANSMITUSERS_STREAMTYPE_INDEX];
        }
    }
    return STREAMTYPE_NONE;
}

void TTKitSetTransmitTypes(Channel* channel, INT32 userID, StreamTypes streamTypes) {
    /* the list ends at the first user ID 0 */
    int count = 0;
    int index = -1;
    while (count < TT_TRANSMITUSERS_MAX && channel->transmitUsers[count][TT_TRANSMITUSERS_USERID_INDEX] != 0) {
        if (channel->transmitUsers[count][TT_TRANSMITUSERS_USERID_INDEX] == userID) {
            index = count;
        }
        ++count;
    }

    if (streamTypes == STREAMTYPE_NONE) {
        if (index < 0) {
            return;
        }
        for (int i = index; i + 1 < count; ++i) {
            channel->transmitUsers[i][TT_TRANSMITUSERS_USERID_INDEX] = channel->transmitUsers[i + 1][TT_TRANSMITUSERS_USERID_INDEX];
            channel->transmitUsers[i][TT_TRANSMITUSERS_STREAMTYPE_INDEX] = channel->transmitUsers[i + 1][TT_TRANSMITUSERS_STREAMTYPE_INDEX];
        }
        channel->transmitUsers[count - 1][TT_TRANSMITUSERS_USERID_INDEX] = 0;
        channel->transmitUsers[count - 1][TT_TRANSMITUSERS_STREAMTYPE_INDEX] = STREAMTYPE_NONE;
        return;
    }

    if (index < 0) {
        if (count >= TT_TRANSMITUSERS_MAX) {
            return;
        }
        index = count;
        if (count + 1 < TT_TRANSMITUSERS_MAX) {
            channel->transmitUsers[count + 1][TT_TRANSMITUSERS_USERID_INDEX] = 0;
            channel->transmitUsers[count + 1][TT_TRANSMITUSERS_STREAMTYPE_INDEX] = STREAMTYPE_NONE;
        }
    }
    channel->transmitUsers[index][TT_TRANSMITUSERS_USERID_INDEX] = userID;
    channel->transmitUsers[index][TT_TRANSMITUSERS_STREAMTYPE_INDEX] = (INT32)streamTypes;
}

TTBOOL TTKitMessageActiveFlag(const TTMessage* message) {
    return message->bActive;
}

const TTCHAR* TTKitGetUserString(TTKitUserStringProperty property, const User* user) {
    switch (property) {
    case TTKitUserStringNickname:
        return user->szNickname;
    case TTKitUserStringUsername:
        return user->szUsername;
    case TTKitUserStringStatusMessage:
        return user->szStatusMsg;
    case TTKitUserStringIPAddress:
        return user->szIPAddress;
    case TTKitUserStringClientName:
        return user->szClientName;
    }
    return "";
}

const TTCHAR* TTKitGetChannelString(TTKitChannelStringProperty property, const Channel* channel) {
    switch (property) {
    case TTKitChannelStringName:
        return channel->szName;
    case TTKitChannelStringPassword:
        return channel->szPassword;
    case TTKitChannelStringTopic:
        return channel->szTopic;
    case TTKitChannelStringOperatorPassword:
        return channel->szOpPassword;
    }
    return "";
}

const TTCHAR* TTKitGetTextMessageString(const TextMessage* message) {
    return message->szMessage;
}

const TTCHAR* TTKitGetServerPropertiesString(TTKitServerStringProperty property, const ServerProperties* serverProperties) {
    switch (property) {
    case TTKitServerStringName:
        return serverProperties->szServerName;
    case TTKitServerStringAccessToken:
        return serverProperties->szAccessToken;
    }
    return "";
}

const TTCHAR* TTKitGetClientErrorMessageString(const ClientErrorMsg* clientError) {
    return clientError->szErrorMsg;
}

const TTCHAR* TTKitGetUserAccountString(TTKitUserAccountStringProperty property, const UserAccount* userAccount) {
    switch (property) {
    case TTKitUserAccountStringInitialChannel:
        return userAccount->szInitChannel;
    case TTKitUserAccountStringUsername:
        return userAccount->szUsername;
    case TTKitUserAccountStringNote:
        return userAccount->szNote;
    case TTKitUserAccountStringPassword:
        return userAccount->szPassword;
    case TTKitUserAccountStringLastModified:
        return userAccount->szLastModified;
    case TTKitUserAccountStringLastLogin:
        return userAccount->szLastLoginTime;
    }
    return "";
}

const TTCHAR* TTKitGetRemoteFileString(TTKitRemoteFileStringProperty property, const RemoteFile* remoteFile) {
    switch (property) {
    case TTKitRemoteFileStringFileName:
        return remoteFile->szFileName;
    case TTKitRemoteFileStringUsername:
        return remoteFile->szUsername;
    case TTKitRemoteFileStringUploadTime:
        return remoteFile->szUploadTime;
    }
    return "";
}

const TTCHAR* TTKitGetFileTransferString(TTKitFileTransferStringProperty property, const FileTransfer* fileTransfer) {
    switch (property) {
    case TTKitFileTransferStringLocalFilePath:
        return fileTransfer->szLocalFilePath;
    case TTKitFileTransferStringRemoteFileName:
        return fileTransfer->szRemoteFileName;
    }
    return "";
}

void TTKitSetChannelString(TTKitChannelStringProperty property, Channel* channel, const TTCHAR* string) {
    switch (property) {
    case TTKitChannelStringName:
        strncpy(channel->szName, string, TT_STRLEN);
        channel->szName[TT_STRLEN - 1] = '\0';
        break;
    case TTKitChannelStringPassword:
        strncpy(channel->szPassword, string, TT_STRLEN);
        channel->szPassword[TT_STRLEN - 1] = '\0';
        break;
    case TTKitChannelStringTopic:
        strncpy(channel->szTopic, string, TT_STRLEN);
        channel->szTopic[TT_STRLEN - 1] = '\0';
        break;
    case TTKitChannelStringOperatorPassword:
        strncpy(channel->szOpPassword, string, TT_STRLEN);
        channel->szOpPassword[TT_STRLEN - 1] = '\0';
        break;
    }
}

void TTKitSetUserAccountString(TTKitUserAccountStringProperty property, UserAccount* userAccount, const TTCHAR* string) {
    TTCHAR* field = 0;
    switch (property) {
    case TTKitUserAccountStringInitialChannel:
        field = userAccount->szInitChannel;
        break;
    case TTKitUserAccountStringUsername:
        field = userAccount->szUsername;
        break;
    case TTKitUserAccountStringNote:
        field = userAccount->szNote;
        break;
    case TTKitUserAccountStringPassword:
        field = userAccount->szPassword;
        break;
    case TTKitUserAccountStringLastModified:
    case TTKitUserAccountStringLastLogin:
        // written by the server
        break;
    }
    if (field) {
        strncpy(field, string, TT_STRLEN);
        field[TT_STRLEN - 1] = 0;
    }
}

void TTKitSetTextMessageString(TextMessage* message, const TTCHAR* string) {
    strncpy(message->szMessage, string, TT_STRLEN);
    message->szMessage[TT_STRLEN - 1] = '\0';
}

void TTKitSetEncryptionString(TTKitEncryptionStringProperty property, EncryptionContext* encryption, const TTCHAR* string) {
    switch (property) {
    case TTKitEncryptionCAFile:
        strncpy(encryption->szCAFile, string, TT_STRLEN);
        encryption->szCAFile[TT_STRLEN - 1] = '\0';
        break;
    case TTKitEncryptionCertificateFile:
        strncpy(encryption->szCertificateFile, string, TT_STRLEN);
        encryption->szCertificateFile[TT_STRLEN - 1] = '\0';
        break;
    case TTKitEncryptionPrivateKeyFile:
        strncpy(encryption->szPrivateKeyFile, string, TT_STRLEN);
        encryption->szPrivateKeyFile[TT_STRLEN - 1] = '\0';
        break;
    }
}
