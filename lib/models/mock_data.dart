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

  /// Display helpers for UI
  String get displayAvatar => avatarUrl != null ? '' : '🚶';
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
  final int id;
  final String walker;
  final String date;
  final String time;
  final String duration;
  final String location;
  final String status;
  final String image;

  const Booking({
    required this.id,
    required this.walker,
    required this.date,
    required this.time,
    required this.duration,
    required this.location,
    required this.status,
    required this.image,
  });
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

  static const bookings = [
    Booking(
      id: 1,
      walker: 'Sarah Johnson',
      date: 'Mar 8, 2026',
      time: '2:00 PM',
      duration: '30 min',
      location: 'Central Park',
      status: 'upcoming',
      image: '\u{1F469}',
    ),
    Booking(
      id: 2,
      walker: 'Mike Chen',
      date: 'Mar 10, 2026',
      time: '4:30 PM',
      duration: '45 min',
      location: 'Riverside Trail',
      status: 'upcoming',
      image: '\u{1F468}',
    ),
  ];

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
