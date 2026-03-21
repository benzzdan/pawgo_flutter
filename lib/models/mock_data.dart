class Walker {
  final int id;
  final String name;
  final String avatar;
  final double rating;
  final int reviews;
  final int price;
  final String distance;
  final bool verified;
  final bool backgroundCheck;
  final String responseTime;
  final int walks;
  final List<String> specialties;
  final String availability;
  final String availableColor;
  final String bio;
  final List<String> certifications;

  const Walker({
    required this.id,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.distance,
    required this.verified,
    required this.backgroundCheck,
    required this.responseTime,
    required this.walks,
    required this.specialties,
    required this.availability,
    required this.availableColor,
    this.bio = '',
    this.certifications = const [],
  });
}

class Dog {
  final int id;
  final String name;
  final String breed;
  final String age;
  final String weight;
  final String image;

  const Dog({
    required this.id,
    required this.name,
    required this.breed,
    required this.age,
    required this.weight,
    required this.image,
  });
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
  static const walkers = [
    Walker(
      id: 1,
      name: 'Sarah Johnson',
      avatar: '\u{1F469}',
      rating: 4.9,
      reviews: 127,
      price: 25,
      distance: '0.3 mi',
      verified: true,
      backgroundCheck: true,
      responseTime: '~5 min',
      walks: 450,
      specialties: ['Small Dogs', 'Puppies'],
      availability: 'Available Now',
      availableColor: 'green',
      bio:
          'Passionate dog lover with 5+ years of experience. I treat every pup like my own and provide lots of love, exercise, and attention!',
      certifications: [
        'Pet First Aid Certified',
        'Dog Training Certificate',
        'Insured & Bonded',
      ],
    ),
    Walker(
      id: 2,
      name: 'Mike Chen',
      avatar: '\u{1F468}',
      rating: 4.8,
      reviews: 98,
      price: 22,
      distance: '0.5 mi',
      verified: true,
      backgroundCheck: true,
      responseTime: '~10 min',
      walks: 320,
      specialties: ['Large Dogs', 'Active'],
      availability: 'Available Today',
      availableColor: 'blue',
    ),
    Walker(
      id: 3,
      name: 'Emily Rodriguez',
      avatar: '\u{1F469}\u{200D}\u{1F9B1}',
      rating: 5.0,
      reviews: 156,
      price: 30,
      distance: '0.7 mi',
      verified: true,
      backgroundCheck: true,
      responseTime: '~3 min',
      walks: 580,
      specialties: ['All Breeds', 'Training'],
      availability: 'Available Now',
      availableColor: 'green',
    ),
    Walker(
      id: 4,
      name: 'James Wilson',
      avatar: '\u{1F9D4}',
      rating: 4.7,
      reviews: 89,
      price: 20,
      distance: '1.2 mi',
      verified: true,
      backgroundCheck: true,
      responseTime: '~15 min',
      walks: 250,
      specialties: ['Senior Dogs', 'Gentle'],
      availability: 'Available Tomorrow',
      availableColor: 'gray',
    ),
  ];

  static const dogs = [
    Dog(
      id: 1,
      name: 'Max',
      breed: 'Golden Retriever',
      age: '3 years',
      weight: '65 lbs',
      image: '\u{1F415}',
    ),
    Dog(
      id: 2,
      name: 'Bella',
      breed: 'French Bulldog',
      age: '2 years',
      weight: '28 lbs',
      image: '\u{1F436}',
    ),
  ];

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
