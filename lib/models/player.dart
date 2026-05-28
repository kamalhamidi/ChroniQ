class Player {
  final String name;
  final String flag;
  final String username;

  const Player({
    required this.name,
    required this.flag,
    required this.username,
  });

  Player copyWith({String? name, String? flag, String? username}) {
    return Player(
      name: name ?? this.name,
      flag: flag ?? this.flag,
      username: username ?? this.username,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'flag': flag,
        'username': username,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        name: json['name'] as String,
        flag: json['flag'] as String,
        username: json['username'] as String,
      );

  @override
  String toString() => 'Player($name, $flag, @$username)';
}
