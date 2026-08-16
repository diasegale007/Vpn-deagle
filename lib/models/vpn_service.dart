import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../models/server.dart';
import 'api_service.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

/// Обёртка над плагином wireguard_flutter.
/// На Android использует VpnService, на iOS — NetworkExtension
/// (для iOS дополнительно нужно подключить Network Extension target в Xcode,
/// см. README).
class VpnConnectionService extends ChangeNotifier {
  final _wireguard = WireGuardFlutter.instance;

  VpnStatus status = VpnStatus.disconnected;
  VpnServer? currentServer;
  String? errorMessage;

  /// Запрашивает у бэкенда персональный конфиг для сервера [serverId]
  /// (требует активную подписку — 403 от бэкенда, если её нет),
  /// затем поднимает туннель.
  Future<void> connectToServer({
    required String serverId,
    required String authToken,
  }) async {
    try {
      status = VpnStatus.connecting;
      notifyListeners();

      final server = await ApiService.requestConnectionConfig(
        serverId: serverId,
        token: authToken,
      );

      await _connect(server);
    } catch (e) {
      status = VpnStatus.error;
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> _connect(VpnServer server) async {
    try {
      await _wireguard.initialize(interfaceName: 'wg0');

      await _wireguard.startVpn(
        serverAddress: server.endpoint,
        wgQuickConfig: server.toWireGuardConfig(),
        providerBundleIdentifier: 'com.example.vpnapp.VPNExtension',
      );

      currentServer = server;
      status = VpnStatus.connected;
      errorMessage = null;
    } catch (e) {
      status = VpnStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      status = VpnStatus.disconnecting;
      notifyListeners();

      await _wireguard.stopVpn();

      currentServer = null;
      status = VpnStatus.disconnected;
    } catch (e) {
      status = VpnStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Слушает изменения статуса на уровне ОС (например, если система
  /// сама разорвала VPN-туннель).
  void listenToNativeStatus() {
    _wireguard.vpnStageSnapshot.listen((stage) {
      switch (stage) {
        case VpnStage.connected:
          status = VpnStatus.connected;
          break;
        case VpnStage.disconnected:
          status = VpnStatus.disconnected;
          currentServer = null;
          break;
        case VpnStage.connecting:
          status = VpnStatus.connecting;
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }
}
