class BluetoothInfo {
  final String name;
  final String macAdress;

  BluetoothInfo({required this.name, required this.macAdress});

  String get macAddress => macAdress;
}
