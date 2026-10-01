enum UserRole {
  worker,
  supervisor;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.worker;
    switch (role.toLowerCase().trim()) {
      case 'supervisor':
        return UserRole.supervisor;
      case 'worker':
      default:
        return UserRole.worker;
    }
  }

  String toRoleString() {
    switch (this) {
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.worker:
        return 'worker';
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String workerId;
  final int cachedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.workerId,
    this.cachedAt = 0,
  });

  bool get isWorker => role == UserRole.worker;
  bool get isSupervisor => role == UserRole.supervisor;

  factory AppUser.fromJson(Map<String, dynamic> json, {String? uid}) {
    return AppUser(
      uid: uid ?? (json['uid']?.toString() ?? ''),
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? 'User',
      role: UserRole.fromString(json['role']?.toString()),
      workerId: json['workerId']?.toString() ?? '',
      cachedAt: json['cachedAt'] is int
          ? json['cachedAt'] as int
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.toRoleString(),
      'workerId': workerId,
      'cachedAt': cachedAt,
    };
  }

  factory AppUser.fromSqlite(Map<String, dynamic> map) {
    return AppUser(
      uid: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      role: UserRole.fromString(map['role']?.toString()),
      workerId: map['worker_id']?.toString() ?? '',
      cachedAt: (map['cached_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': uid,
      'email': email,
      'name': name,
      'role': role.toRoleString(),
      'worker_id': workerId,
      'cached_at': cachedAt,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    UserRole? role,
    String? workerId,
    int? cachedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      workerId: workerId ?? this.workerId,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}
