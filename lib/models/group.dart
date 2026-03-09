class Group {
  final String id;
  final String name;
  final List<String> memberContactIds; // IDs de los contactos miembros del grupo

  Group({required this.id, required this.name, required this.memberContactIds});
}