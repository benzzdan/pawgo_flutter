import 'dart:ui' show Color;

class Walker {
  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final double rating;
  final int totalWalks;
  final double hourlyRateMxn;
  final bool backgroundChecked;
  final bool isEnabled;
  final String? bio;
  final int experienceYears;
  final DateTime? createdAt;

  /// Distance in kilometers from the search origin. Only populated by
  /// `Walker.fromRpc` (the nearby_walkers RPC returns this). NULL when
  /// the walker has no service_area on the backend, or when the walker
  /// was fetched without an origin point. The find screen uses this to
  /// honor the "Only show walkers in this range" toggle.
  final double? distanceKm;

  const Walker({
    required this.id,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.rating = 0,
    this.totalWalks = 0,
    this.hourlyRateMxn = 0,
    this.backgroundChecked = false,
    this.isEnabled = false,
    this.bio,
    this.experienceYears = 0,
    this.createdAt,
    this.distanceKm,
  });

  factory Walker.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return Walker(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: user?['full_name'] as String? ?? 'Unknown Walker',
      avatarUrl: user?['avatar_url'] as String?,
      rating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      totalWalks: json['total_walks'] as int? ?? 0,
      hourlyRateMxn: (json['hourly_rate_mxn'] as num?)?.toDouble() ?? 0,
      backgroundChecked: json['background_checked'] as bool? ?? false,
      isEnabled: json['is_enabled'] as bool? ?? false,
      bio: json['bio'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Parse from the nearby_walkers RPC result (flat row, no nested `users`,
  /// and including a computed `distance_km` field per migration 042).
  factory Walker.fromRpc(Map<String, dynamic> json) {
    return Walker(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['full_name'] as String? ?? 'Unknown Walker',
      avatarUrl: json['avatar_url'] as String?,
      rating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      totalWalks: json['total_walks'] as int? ?? 0,
      hourlyRateMxn: (json['hourly_rate_mxn'] as num?)?.toDouble() ?? 0,
      backgroundChecked: json['background_checked'] as bool? ?? false,
      isEnabled: json['is_enabled'] as bool? ?? false,
      bio: json['bio'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  /// Display helpers for UI
  String get displayAvatar => avatarUrl != null ? '' : '\u{1F6B6}';
  String get displayPrice => '\$${hourlyRateMxn.toStringAsFixed(0)}';
  String get displayExperience =>
      experienceYears > 0 ? '$experienceYears+ yrs' : 'New';
  String get displayRating => rating.toStringAsFixed(1);
}

class Dog {
  final String id;
  final String ownerId;
  final String name;
  final String? breed;
  final int? ageYears;
  final double? weightKg;
  final String? notes;
  final String? photoUrl;
  final DateTime? createdAt;

  const Dog({
    required this.id,
    required this.ownerId,
    required this.name,
    this.breed,
    this.ageYears,
    this.weightKg,
    this.notes,
    this.photoUrl,
    this.createdAt,
  });

  factory Dog.fromJson(Map<String, dynamic> json) {
    return Dog(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      breed: json['breed'] as String?,
      ageYears: json['age_years'] as int?,
      weightKg: json['weight_kg'] != null
          ? (json['weight_kg'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'owner_id': ownerId,
      'name': name,
      if (breed != null) 'breed': breed,
      if (ageYears != null) 'age_years': ageYears,
      if (weightKg != null) 'weight_kg': weightKg,
      if (notes != null) 'notes': notes,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  /// Display helpers for UI
  String get displayAge =>
      ageYears != null ? '$ageYears yr${ageYears == 1 ? '' : 's'}' : 'Unknown';
  String get displayWeight =>
      weightKg != null ? '${weightKg!.toStringAsFixed(1)} kg' : 'Unknown';
  String get displayBreed => breed ?? 'Mixed';
}

class Booking {
  final String id;
  final String ownerId;
  final String walkerId;
  final String dogId;
  final String status;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationMinutes;
  final double totalPriceMxn;
  final double commissionMxn;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final String walkerName;
  final String? walkerAvatarUrl;
  final String dogName;

  const Booking({
    required this.id,
    required this.ownerId,
    required this.walkerId,
    required this.dogId,
    required this.status,
    required this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.durationMinutes,
    this.totalPriceMxn = 0,
    this.commissionMxn = 0,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.walkerName = 'Unknown Walker',
    this.walkerAvatarUrl,
    this.dogName = '',
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final walker = json['walkers'] as Map<String, dynamic>?;
    final walkerUser = walker?['users'] as Map<String, dynamic>?;
    final dog = json['dogs'] as Map<String, dynamic>?;
    return Booking(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      walkerId: json['walker_id'] as String,
      dogId: json['dog_id'] as String,
      status: json['status'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      totalPriceMxn:
          (json['total_price_mxn'] as num?)?.toDouble() ?? 0,
      commissionMxn:
          (json['commission_mxn'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      walkerName: walkerUser?['full_name'] as String? ?? 'Unknown Walker',
      walkerAvatarUrl: walkerUser?['avatar_url'] as String?,
      dogName: dog?['name'] as String? ?? '',
    );
  }

  /// Whether the booking is in the future / active.
  bool get isUpcoming =>
      status == 'pending' ||
      status == 'pending_walker_acceptance' ||
      status == 'confirmed' ||
      status == 'walker_en_route' ||
      status == 'walk_started';

  /// Whether the booking is completed.
  bool get isPast => status == 'walk_completed';

  /// Whether the booking is cancelled.
  bool get isCancelled => status == 'cancelled';

  /// Human-readable status label.
  String get displayStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'pending_walker_acceptance':
        return 'Awaiting Walker';
      case 'confirmed':
        return 'Confirmed';
      case 'walker_en_route':
        return 'Walker En Route';
      case 'walk_started':
        return 'In Progress';
      case 'walk_completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'disputed':
        return 'Disputed';
      default:
        return status;
    }
  }

  /// Status badge color.
  Color get statusColor {
    switch (status) {
      case 'confirmed':
      case 'walk_completed':
        return const Color(0xFF16A34A); // green
      case 'walk_started':
      case 'walker_en_route':
        return const Color(0xFF2563EB); // blue
      case 'cancelled':
      case 'disputed':
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFFF59E0B); // amber for pending
    }
  }

  /// Status badge background color.
  Color get statusBgColor {
    switch (status) {
      case 'confirmed':
      case 'walk_completed':
        return const Color(0xFFF0FDF4); // green-50
      case 'walk_started':
      case 'walker_en_route':
        return const Color(0xFFEFF6FF); // blue-50
      case 'cancelled':
      case 'disputed':
        return const Color(0xFFFEF2F2); // red-50
      default:
        return const Color(0xFFFFFBEB); // amber-50
    }
  }

  /// Formatted price string.
  String get displayPrice => '\$${totalPriceMxn.toStringAsFixed(0)} MXN';

  /// Returns a copy with updated fields.
  Booking copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return Booking(
      id: id,
      ownerId: ownerId,
      walkerId: walkerId,
      dogId: dogId,
      status: status ?? this.status,
      scheduledAt: scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationMinutes: durationMinutes,
      totalPriceMxn: totalPriceMxn,
      commissionMxn: commissionMxn,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      walkerName: walkerName,
      walkerAvatarUrl: walkerAvatarUrl,
      dogName: dogName,
    );
  }
}

class Payment {
  final String id;
  final String bookingId;
  final double amountMxn;
  final String status;
  final String? paymentMethod;
  final String? externalId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields from bookings
  final String? dogName;
  final String? ownerName;
  final DateTime? scheduledAt;
  final double? commissionMxn;

  const Payment({
    required this.id,
    required this.bookingId,
    this.amountMxn = 0,
    this.status = 'pending',
    this.paymentMethod,
    this.externalId,
    this.createdAt,
    this.updatedAt,
    this.dogName,
    this.ownerName,
    this.scheduledAt,
    this.commissionMxn,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final booking = json['bookings'] as Map<String, dynamic>?;
    final dog = booking?['dogs'] as Map<String, dynamic>?;
    final owner = booking?['users'] as Map<String, dynamic>?;
    return Payment(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      amountMxn: (json['amount_mxn'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String?,
      externalId: json['external_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      dogName: dog?['name'] as String?,
      ownerName: owner?['full_name'] as String?,
      scheduledAt: booking?['scheduled_at'] != null
          ? DateTime.parse(booking!['scheduled_at'] as String)
          : null,
      commissionMxn:
          (booking?['commission_mxn'] as num?)?.toDouble(),
    );
  }

  bool get isCompleted => status == 'completed';

  /// Walker earnings = amount - commission
  double get walkerEarnings =>
      commissionMxn != null ? amountMxn - commissionMxn! : amountMxn;

  String get displayAmount => '\$${amountMxn.toStringAsFixed(0)} MXN';
  String get displayEarnings => '\$${walkerEarnings.toStringAsFixed(0)} MXN';
  String get displayStatus {
    switch (status) {
      case 'completed':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }
}

class WalkLocation {
  final int id;
  final String bookingId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;

  const WalkLocation({
    required this.id,
    required this.bookingId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.recordedAt,
  });

  factory WalkLocation.fromJson(Map<String, dynamic> json) {
    return WalkLocation(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      bookingId: json['booking_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}

class ChatMessage {
  final int id;
  final String sender;
  final String text;
  final String time;
  final String avatar;
  final bool hasImage;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    required this.avatar,
    this.hasImage = false,
  });
}

class Review {
  final int id;
  final String author;
  final String avatar;
  final int rating;
  final String date;
  final String text;
  final bool verified;

  const Review({
    required this.id,
    required this.author,
    required this.avatar,
    required this.rating,
    required this.date,
    required this.text,
    required this.verified,
  });
}

class SavedAddress {
  final int id;
  final String label;
  final String address;
  final bool isDefault;
  final String icon;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.isDefault,
    required this.icon,
  });
}

class MockData {
  static const dogs = <Dog>[];

  static const bookings = <Booking>[];

  static const chatMessages = [
    ChatMessage(
      id: 1,
      sender: 'walker',
      text: 'Hi! Just started the walk with Max \u{1F415}',
      time: '2:15 PM',
      avatar: '\u{1F469}',
    ),
    ChatMessage(
      id: 2,
      sender: 'walker',
      text: "He's super excited today!",
      time: '2:15 PM',
      avatar: '\u{1F469}',
    ),
    ChatMessage(
      id: 3,
      sender: 'user',
      text: 'Great! Thank you Sarah \u{1F60A}',
      time: '2:16 PM',
      avatar: '\u{1F464}',
    ),
    ChatMessage(
      id: 4,
      sender: 'walker',
      text: 'Stopped at the park for some playtime',
      time: '2:24 PM',
      avatar: '\u{1F469}',
      hasImage: true,
    ),
    ChatMessage(
      id: 5,
      sender: 'walker',
      text: 'He made a new friend! \u{1F436}',
      time: '2:25 PM',
      avatar: '\u{1F469}',
    ),
    ChatMessage(
      id: 6,
      sender: 'user',
      text: "Aww that's wonderful! Is he behaving well?",
      time: '2:26 PM',
      avatar: '\u{1F464}',
    ),
    ChatMessage(
      id: 7,
      sender: 'walker',
      text: 'Absolutely! Very well-behaved as always \u{2B50}',
      time: '2:27 PM',
      avatar: '\u{1F469}',
    ),
    ChatMessage(
      id: 8,
      sender: 'walker',
      text: 'Heading back now. Should be home in about 10 minutes!',
      time: '2:30 PM',
      avatar: '\u{1F469}',
    ),
  ];

  static const reviews = [
    Review(
      id: 1,
      author: 'Michael T.',
      avatar: '\u{1F468}\u{200D}\u{1F4BC}',
      rating: 5,
      date: '2 days ago',
      text:
          'Sarah is amazing! My dog Max absolutely loves her. She sends regular updates and photos during walks. Highly recommend!',
      verified: true,
    ),
    Review(
      id: 2,
      author: 'Jennifer L.',
      avatar: '\u{1F469}\u{200D}\u{1F4BB}',
      rating: 5,
      date: '1 week ago',
      text:
          'Very professional and caring. Always on time and follows instructions perfectly. My anxious rescue dog trusts her completely.',
      verified: true,
    ),
    Review(
      id: 3,
      author: 'David K.',
      avatar: '\u{1F468}\u{200D}\u{1F52C}',
      rating: 4,
      date: '2 weeks ago',
      text:
          'Great walker! Sometimes runs a few minutes late but always communicates. My puppy gets great exercise and comes home happy.',
      verified: true,
    ),
  ];

  static const savedAddresses = [
    SavedAddress(
      id: 1,
      label: 'Home',
      address: '123 Park Avenue, New York, NY 10016',
      isDefault: true,
      icon: 'home',
    ),
    SavedAddress(
      id: 2,
      label: 'Work',
      address: '456 Business Plaza, New York, NY 10018',
      isDefault: false,
      icon: 'work',
    ),
  ];
}
