import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_model.freezed.dart';
part 'item_model.g.dart';

@freezed
class ItemModel with _$ItemModel {
  const factory ItemModel({
    required String id,
    required ItemType type,
    required ItemCategory category,
    required String title,
    required String description,
    @Default([]) List<String> images,
    @Default([]) List<String> blurredImages,
    required GeoPoint location,
    required String locationName,
    required String district,
    @Default(5000.0) double radius,
    required String geohash,
    required String userId,
    required String userName,
    String? userPhone,
    @Default(ItemStatus.active) ItemStatus status,
    @Default(UrgencyLevel.medium) UrgencyLevel urgency,
    @Default(0) int matchCount,
    @Default(0) int viewCount,
    @Default(0) int reportCount,
    Map<String, dynamic>? features,
    List<double>? embedding,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime expiresAt,
  }) = _ItemModel;

  factory ItemModel.fromJson(Map<String, dynamic> json) =>
      _$ItemModelFromJson(json);

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel.fromJson({
      'id': doc.id,
      ...data,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
      'expiresAt': (data['expiresAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

  static Map<String, dynamic> toFirestore(ItemModel item) {
    final json = item.toJson();
    json['createdAt'] = Timestamp.fromDate(item.createdAt);
    json['updatedAt'] = Timestamp.fromDate(item.updatedAt);
    json['expiresAt'] = Timestamp.fromDate(item.expiresAt);
    json.remove('id');
    return json;
  }
}

enum ItemType {
  @JsonValue('lost')
  lost,
  @JsonValue('found')
  found,
}

enum ItemCategory {
  @JsonValue('nic')
  nic,
  @JsonValue('passport')
  passport,
  @JsonValue('phone')
  phone,
  @JsonValue('wallet')
  wallet,
  @JsonValue('bag')
  bag,
  @JsonValue('keys')
  keys,
  @JsonValue('documents')
  documents,
  @JsonValue('other')
  other,
}

enum ItemStatus {
  @JsonValue('active')
  active,
  @JsonValue('claimed')
  claimed,
  @JsonValue('verified')
  verified,
  @JsonValue('closed')
  closed,
  @JsonValue('expired')
  expired,
}

enum UrgencyLevel {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('emergency')
  emergency,
}

// Helper Extensions
extension ItemTypeX on ItemType {
  String get displayName {
    switch (this) {
      case ItemType.lost:
        return 'Lost';
      case ItemType.found:
        return 'Found';
    }
  }

  String get icon {
    switch (this) {
      case ItemType.lost:
        return '🔍';
      case ItemType.found:
        return '✨';
    }
  }
}

extension ItemCategoryX on ItemCategory {
  String get displayName {
    switch (this) {
      case ItemCategory.nic:
        return 'NIC';
      case ItemCategory.passport:
        return 'Passport';
      case ItemCategory.phone:
        return 'Phone';
      case ItemCategory.wallet:
        return 'Wallet';
      case ItemCategory.bag:
        return 'Bag';
      case ItemCategory.keys:
        return 'Keys';
      case ItemCategory.documents:
        return 'Documents';
      case ItemCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ItemCategory.nic:
        return '🪪';
      case ItemCategory.passport:
        return '🛂';
      case ItemCategory.phone:
        return '📱';
      case ItemCategory.wallet:
        return '👛';
      case ItemCategory.bag:
        return '🎒';
      case ItemCategory.keys:
        return '🔑';
      case ItemCategory.documents:
        return '📄';
      case ItemCategory.other:
        return '📦';
    }
  }
}
