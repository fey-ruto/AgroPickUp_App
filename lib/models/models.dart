import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { farmer, admin, driver }

enum RequestStatus {
  submitted,
  accepted,
  scheduled,
  pickedUp,
  completed,
  cancelled,
}

enum NotificationType {
  requestAccepted,
  requestScheduled,
  requestCompleted,
  requestCancelled,
  general,
}

class AppUser {
  final String id;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final String? farmName;
  final String? region;
  final String? fcmToken;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.farmName,
    this.region,
    this.fcmToken,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.farmer,
      ),
      farmName: data['farmName'],
      region: data['region'],
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'farmName': farmName,
      'region': region,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class CollectionPoint {
  final String id;
  final String name;
  final String address;
  final String region;
  final double latitude;
  final double longitude;
  final String? facilities;
  final String? contactPhone;
  final String? operatingHours;
  final bool isActive;
  final DateTime createdAt;

  CollectionPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.region,
    required this.latitude,
    required this.longitude,
    this.facilities,
    this.contactPhone,
    this.operatingHours,
    required this.isActive,
    required this.createdAt,
  });

  factory CollectionPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CollectionPoint(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      region: data['region'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      facilities: data['facilities'],
      contactPhone: data['contactPhone'],
      operatingHours: data['operatingHours'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'region': region,
      'latitude': latitude,
      'longitude': longitude,
      'facilities': facilities,
      'contactPhone': contactPhone,
      'operatingHours': operatingHours,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class PickupRequest {
  final String id;
  final String farmerId;
  final String farmerName;
  final String? farmerPhone;
  final String collectionPointId;
  final String collectionPointName;
  final String? adminContactPhone;
  final String? assignedDriverId;
  final String produceType;
  final double quantity;
  final RequestStatus status;
  final DateTime requestedDate;
  final DateTime? scheduledDate;
  final String? photoUrl;
  final String? notes;
  final String? adminNotes;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  PickupRequest({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    this.farmerPhone,
    required this.collectionPointId,
    required this.collectionPointName,
    this.adminContactPhone,
    this.assignedDriverId,
    required this.produceType,
    required this.quantity,
    required this.status,
    required this.requestedDate,
    this.scheduledDate,
    this.photoUrl,
    this.notes,
    this.adminNotes,
    required this.isSynced,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PickupRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PickupRequest(
      id: doc.id,
      farmerId: data['farmerId'] ?? '',
      farmerName: data['farmerName'] ?? '',
      farmerPhone: data['farmerPhone'],
      collectionPointId: data['collectionPointId'] ?? '',
      collectionPointName: data['collectionPointName'] ?? '',
      adminContactPhone: data['adminContactPhone'],
      assignedDriverId: data['assignedDriverId'],
      produceType: data['produceType'] ?? '',
      quantity: (data['quantity'] ?? 0.0).toDouble(),
      status: RequestStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RequestStatus.submitted,
      ),
      requestedDate:
          (data['requestedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate(),
      photoUrl: data['photoUrl'],
      notes: data['notes'],
      adminNotes: data['adminNotes'],
      isSynced: data['isSynced'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PickupRequest.fromMap(Map<String, dynamic> data) {
    return PickupRequest(
      id: data['id'] ?? '',
      farmerId: data['farmerId'] ?? '',
      farmerName: data['farmerName'] ?? '',
      farmerPhone: data['farmerPhone'],
      collectionPointId: data['collectionPointId'] ?? '',
      collectionPointName: data['collectionPointName'] ?? '',
      adminContactPhone: data['adminContactPhone'],
      assignedDriverId: data['assignedDriverId'],
      produceType: data['produceType'] ?? '',
      quantity: (data['quantity'] ?? 0.0).toDouble(),
      status: RequestStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RequestStatus.submitted,
      ),
      requestedDate: DateTime.parse(data['requestedDate']),
      scheduledDate: data['scheduledDate'] != null
          ? DateTime.parse(data['scheduledDate'])
          : null,
      photoUrl: data['photoUrl'],
      notes: data['notes'],
      adminNotes: data['adminNotes'],
      isSynced: data['isSynced'] == 1,
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'farmerPhone': farmerPhone,
      'collectionPointId': collectionPointId,
      'collectionPointName': collectionPointName,
      'adminContactPhone': adminContactPhone,
      'assignedDriverId': assignedDriverId,
      'produceType': produceType,
      'quantity': quantity,
      'status': status.name,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'scheduledDate':
          scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'photoUrl': photoUrl,
      'notes': notes,
      'adminNotes': adminNotes,
      'isSynced': true,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'farmerPhone': farmerPhone,
      'collectionPointId': collectionPointId,
      'collectionPointName': collectionPointName,
      'adminContactPhone': adminContactPhone,
      'assignedDriverId': assignedDriverId,
      'produceType': produceType,
      'quantity': quantity,
      'status': status.name,
      'requestedDate': requestedDate.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'photoUrl': photoUrl,
      'notes': notes,
      'adminNotes': adminNotes,
      'isSynced': isSynced ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PickupRequest copyWith({
    RequestStatus? status,
    String? adminNotes,
    String? assignedDriverId,
    DateTime? scheduledDate,
    String? adminContactPhone,
    bool? isSynced,
  }) {
    return PickupRequest(
      id: id,
      farmerId: farmerId,
      farmerName: farmerName,
      farmerPhone: farmerPhone,
      collectionPointId: collectionPointId,
      collectionPointName: collectionPointName,
      adminContactPhone: adminContactPhone ?? this.adminContactPhone,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      produceType: produceType,
      quantity: quantity,
      status: status ?? this.status,
      requestedDate: requestedDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      photoUrl: photoUrl,
      notes: notes,
      adminNotes: adminNotes ?? this.adminNotes,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final String? requestId;
  final DateTime sentAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.requestId,
    required this.sentAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => NotificationType.general,
      ),
      isRead: data['isRead'] ?? false,
      requestId: data['requestId'],
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.name,
      'isRead': isRead,
      'requestId': requestId,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }
}
