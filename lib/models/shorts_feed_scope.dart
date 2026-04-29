enum ShortsFeedScope { personal, global }

extension ShortsFeedScopeX on ShortsFeedScope {
  String get apiValue => switch (this) {
    ShortsFeedScope.personal => 'personal',
    ShortsFeedScope.global => 'global',
  };

  bool get isPersonal => this == ShortsFeedScope.personal;
}
