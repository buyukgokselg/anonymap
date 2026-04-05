/// Public Mapbox token (`pk.`). Override:
/// `flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk...`
/// Manifest / Info.plist ile aynı değer; Dart tarafında da set edilmeli (harita SDK bunu bekliyor).
const String kMapboxPublicAccessToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue:
      'pk.eyJ1IjoiYnV5dWtnb2tzZWwiLCJhIjoiY21uaHp1d3N1MDNsdzJycXI3Y2p4MWpkbSJ9.aKmOTTaINVOykU-chxv1ew',
);
