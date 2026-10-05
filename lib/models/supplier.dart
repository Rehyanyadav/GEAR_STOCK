class Supplier {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String city;
  final int activeOrders;
  final double outstandingDues;
  final List<String> categories;
  final int leadTimeDays;
  final double rating;

  Supplier({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.city,
    required this.activeOrders,
    required this.outstandingDues,
    required this.categories,
    required this.leadTimeDays,
    this.rating = 4.8,
  });
}
