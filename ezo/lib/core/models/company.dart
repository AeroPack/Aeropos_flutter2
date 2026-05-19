class Company {
  final int id;
  final String uuid;
  final int? tenantId;
  final String businessName;
  final String? businessAddress;
  final String? taxId;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final String? role;
  final bool? isOwner;
  final bool? isCurrent;

  Company({
    required this.id,
    required this.uuid,
    this.tenantId,
    required this.businessName,
    this.businessAddress,
    this.taxId,
    this.phone,
    this.email,
    this.logoUrl,
    this.role,
    this.isOwner,
    this.isCurrent,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] ?? 0,
      uuid: json['uuid'] ?? '',
      tenantId: json['tenantId'] ?? json['tenant_id'],
      businessName: json['businessName'] ?? json['business_name'] ?? '',
      businessAddress: json['businessAddress'] ?? json['business_address'],
      taxId: json['taxId'] ?? json['tax_id'],
      phone: json['phone'],
      email: json['email'],
      logoUrl: json['logoUrl'] ?? json['logo_url'],
      role: json['role'],
      isOwner: json['isOwner'] ?? json['is_owner'],
      isCurrent: json['isCurrent'] ?? json['is_current'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'tenantId': tenantId,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'taxId': taxId,
      'phone': phone,
      'email': email,
      'logoUrl': logoUrl,
      'role': role,
      'isOwner': isOwner,
      'isCurrent': isCurrent,
    };
  }

  Company copyWith({
    int? id,
    String? uuid,
    int? tenantId,
    String? businessName,
    String? businessAddress,
    String? taxId,
    String? phone,
    String? email,
    String? logoUrl,
    String? role,
    bool? isOwner,
    bool? isCurrent,
  }) {
    return Company(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      tenantId: tenantId ?? this.tenantId,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      taxId: taxId ?? this.taxId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      role: role ?? this.role,
      isOwner: isOwner ?? this.isOwner,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}