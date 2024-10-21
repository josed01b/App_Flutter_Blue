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
      title: 'Medidor Magnetico',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.tealAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'CAMPO MAGNETICO'),
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
    _permisosBluetooth();
      _escaneo = cnxBlu.scanForDevices(withServices: [Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214')]).listen(_conectar);
  }

  Future<void> _permisosBluetooth() async {
    // Verificar permisos de ubicación y Bluetooth
    final permisoUbicacion = await Permission.location.request();
    final permisoBuscar = await Permission.bluetoothScan.request();
    final permisoConectar = await Permission.bluetoothConnect.request();

    if (permisoUbicacion.isGranted && permisoBuscar.isGranted && permisoConectar.isGranted) {
      // Proceder al escaneo solo si se otorgan todos los permisos
      _escaneo = cnxBlu.scanForDevices(
        withServices: [Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214')],
      ).listen(_conectar);
    } else {
      print('No se otorgaron todos los permisos necesarios.');
    }
    if (!permisoUbicacion.isGranted || !permisoBuscar.isGranted || !permisoConectar.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permisos de ubicación y Bluetooth son necesarios para usar la aplicación.')),
      );
    }

  }

  void _conectar(DiscoveredDevice dispt) {
    print('Arduino encontrado: ${dispt.name}, ${dispt.id}');
    if (dispt.name == 'LED-Portenta-01' && !_encontrado) {
      _encontrado = true;
      _conexion = cnxBlu.connectToDevice(id: dispt.id).listen((update) {
        if (update.connectionState == DeviceConnectionState.connected) {
          _accionConectado(dispt.id);
        }
      });
    }
  }


  void _accionConectado(String disptId) {

    final characteristic = QualifiedCharacteristic(
        deviceId: disptId,
        serviceId: Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214'),
        characteristicId: Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214'));
    print('Se conectado al Arduino');
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
      print('Error al recibir los datos: $error');
    },
      onDone: () {
        // Manejo de la desconexión aquí
        print('Desconectado del Arduino');
        setState(() {
          _encontrado = false; // Resetea la variable
          _datos = ''; // Limpia los datos
        });
        // Vuelve a escanear por dispositivos después de la desconexión
        _escaneo = cnxBlu.scanForDevices(
          withServices: [Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214')],
        ).listen(_conectar);
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
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("DATOS"),
                _datos.isEmpty
                  ? const CircularProgressIndicator()
                  : Text(
                    _datos,
                    style: Theme
                    .of(context)
                    .textTheme
                    .headlineMedium),
            ])),
          );
  }
}
