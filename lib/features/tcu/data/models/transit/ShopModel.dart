

class ShopModel {
  final int id;
  final String libelle;
  final String descr;
  final String picture;


  ShopModel({
    required this.id,
    required this.libelle,
    required this.descr,
    required this.picture,

  });

  factory   ShopModel .fromJson(Map<String, dynamic> map) {
    return   ShopModel (
        id: map['id'],
        libelle: map['libelle'],
        descr: map['descr'],
        picture: map['picture']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libelle': libelle,
      'descr': descr,
      'picture': picture,
    };
  }

  static List<  ShopModel > fromJsonList(List<dynamic> list) {
    return list.map((item) =>  ShopModel.fromJson(item)).toList();
  }
}
