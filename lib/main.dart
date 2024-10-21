import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Semillero',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Campo Magnetico'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final cnxBlu = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _escaneo;
  StreamSubscription<ConnectionStateUpdate>? _conexion;
  StreamSubscription<List<int>>? _notifica;

  var _encontrado = false;
  var _datos = '';

  @override
  initState() {
    super.initState();
    _requestPermissions();
      _escaneo = cnxBlu.scanForDevices(withServices: [Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214')]).listen(_onScanUpdate);
  }

  Future<void> _requestPermissions() async {
    // Verificar permisos de ubicación y Bluetooth
    final locationPermission = await Permission.location.request();
    final bluetoothScanPermission = await Permission.bluetoothScan.request();
    final bluetoothConnectPermission = await Permission.bluetoothConnect.request();

    if (locationPermission.isGranted && bluetoothScanPermission.isGranted && bluetoothConnectPermission.isGranted) {
      // Proceder al escaneo solo si se otorgan todos los permisos
      _escaneo = cnxBlu.scanForDevices(
        withServices: [Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214')],
      ).listen(_onScanUpdate);
    } else {
      print('No se otorgaron todos los permisos necesarios.');
    }
    if (!locationPermission.isGranted || !bluetoothScanPermission.isGranted || !bluetoothConnectPermission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permisos de ubicación y Bluetooth son necesarios para usar la aplicación.')),
      );
    }

  }

  void _onScanUpdate(DiscoveredDevice d) {
    print('Dispositivo encontrado: ${d.name}, ${d.id}');
    if (d.name == 'LED-Portenta-01' && !_encontrado) {
      _encontrado = true;
      _conexion = cnxBlu.connectToDevice(id: d.id).listen((update) {
        if (update.connectionState == DeviceConnectionState.connected) {
          _onConnected(d.id);
        }
      });
    }
  }


  void _onConnected(String deviceId) {

    final characteristic = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214'),
        characteristicId: Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214'));
    print('Conectado al Arduino');
    _notifica= cnxBlu.subscribeToCharacteristic(characteristic).listen((bytes) {
      print('Recibido: $bytes');
      setState(() {
        if (bytes.length >= 2) {
          _datos = (bytes[0] | (bytes[1] << 8)).toString();
        } else {
          _datos = bytes[0].toString();
        }
      });
    }, onError: (error) {
      print('Error al recibir datos: $error');
    },
      onDone: () {
        // Manejo de la desconexión aquí
        print('Desconectado del dispositivo');
        setState(() {
          _encontrado = false; // Resetea la variable
          _datos = ''; // Limpia los datos
        });
        // Vuelve a escanear por dispositivos después de la desconexión
        _escaneo = cnxBlu.scanForDevices(
          withServices: [Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214')],
        ).listen(_onScanUpdate);
      },
    );
  }

  @override
  void dispose() {
    _notifica?.cancel();
    _conexion?.cancel();
    _escaneo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
          child: _datos.isEmpty
              ? const CircularProgressIndicator()
              : Text(
              _datos,
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium)),
          );
  }
}
