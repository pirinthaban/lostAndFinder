import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String phone,
    required String displayName,
    String? photoURL,
    @Default(UserRole.citizen) UserRole role,
    @Default(0) int reputation,
    @Default(0) int itemsPosted,
    @Default(0) int itemsReturned,
    @Default(0.0) double successRate,
    GeoPoint? location,
    String? district,
    @Default(false) bool verifiedPolice,
    required DateTime createdAt,
    required DateTime lastActive,
    String? fcmToken,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({
      'id': doc.id,
      ...data,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'lastActive': (data['lastActive'] as Timestamp).toDate().toIso8601String(),
    });
  }

  static Map<String, dynamic> toFirestore(UserModel user) {
    final json = user.toJson();
    json['createdAt'] = Timestamp.fromDate(user.createdAt);
    json['lastActive'] = Timestamp.fromDate(user.lastActive);
    json.remove('id');
    return json;
  }
}

enum UserRole {
  @JsonValue('citizen')
  citizen,
  @JsonValue('police')
  police,
  @JsonValue('university_admin')
  universityAdmin,
  @JsonValue('admin')
  admin,
}
