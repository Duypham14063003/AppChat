enum CallStatus { idle, outgoing, incoming, active, ended, busy }

class CallModel {
  final String? callId;
  final String? conversationId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final bool isVideo;
  final CallStatus status;
  final int? agoraUid;
  final String? agoraToken;
  final String? agoraAppId;
  final String? channelName;
  final int? remoteUid; // Agora UID của người kia

  CallModel({
    this.callId,
    this.conversationId,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.isVideo = false,
    this.status = CallStatus.idle,
    this.agoraUid,
    this.agoraToken,
    this.agoraAppId,
    this.channelName,
    this.remoteUid,
  });

  CallModel copyWith({
    String? callId,
    String? conversationId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    bool? isVideo,
    CallStatus? status,
    int? agoraUid,
    String? agoraToken,
    String? agoraAppId,
    String? channelName,
    int? remoteUid,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      conversationId: conversationId ?? this.conversationId,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      isVideo: isVideo ?? this.isVideo,
      status: status ?? this.status,
      agoraUid: agoraUid ?? this.agoraUid,
      agoraToken: agoraToken ?? this.agoraToken,
      agoraAppId: agoraAppId ?? this.agoraAppId,
      channelName: channelName ?? this.channelName,
      remoteUid: remoteUid ?? this.remoteUid,
    );
  }
}
