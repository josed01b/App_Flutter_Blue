import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'dart:async';

class BluetoothContoller {
  final connectBlue = FlutterReactiveBle();
  final idDispositivo = '9C:19:C2:41:7A:16'; // tomado de nRF Connect
  late StreamSubscription cnx;
  late QualifiedCharacteristic qrx; // para tomar los datos que envia el Arduino
  RxString estado = 'Desconectado'.obs;
  RxString datoM = ''.obs;

  void conectar() async {
    estado.value = 'Conectando ...';
    cnx = connectBlue.connectToDevice(id: idDispositivo).listen((state) {
      connectionTimeout: const Duration(seconds: 2);
      if (state.connectionState == DeviceConnectionState.connected) {
        estado.value = 'Conectado';

        qrx = QualifiedCharacteristic(
            characteristicId: Uuid.parse("string"),
            serviceId: Uuid.parse(""),
            deviceId: idDispositivo);

        connectBlue.subscribeToCharacteristic(qrx).listen((info) {
          List<int> data = info
              .map((byte) => int.parse(byte.toRadixString(16), radix: 16))
              .toList();
          datoM.value = String.fromCharCodes(data);
        });
      }

    }, onError: (Object error) {
      print('Error al conectar: $error');
    });
  }
}
