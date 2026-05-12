enum BugColor {
  red,
  blue,
  yellow,
  purple,
  orange;

  static const active = <BugColor>[red, blue, yellow, orange, purple];

  String get label => name[0].toUpperCase() + name.substring(1);
}
