import Foundation
import TeamTalkC

public enum TeamTalkVideoCodec {
    public static func makeWebMVP8Codec(targetBitrate: Int32) -> VideoCodec {
        TTKitMakeWebMVP8VideoCodec(targetBitrate)
    }

    public static func makeNoCodec() -> VideoCodec {
        TTKitMakeNoVideoCodec()
    }
}
