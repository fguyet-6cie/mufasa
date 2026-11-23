// Fonds de carte IGN.
/// Un fond de carte IGN (Géoplateforme, service WMTS gratuit sans clé).
class FondIgn {
  final String nom;
  final String couche;
  final String format;
  final int zoomMax;
  const FondIgn(this.nom, this.couche, this.format, this.zoomMax);

  String get extension => format == 'image/png' ? 'png' : 'jpg';

  String urlTuile(int z, int x, int y) => url
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$x')
      .replaceAll('{y}', '$y');

  String get url => 'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile'
      '&VERSION=1.0.0&LAYER=$couche&STYLE=normal&TILEMATRIXSET=PM'
      '&FORMAT=$format&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}';
}

const fondsIgn = [
  FondIgn('Plan IGN', 'GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2', 'image/png', 19),
  FondIgn('Photos aériennes', 'ORTHOIMAGERY.ORTHOPHOTOS', 'image/jpeg', 19),
];
