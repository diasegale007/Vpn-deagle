import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server.dart';
import '../services/auth_service.dart';
import '../services/vpn_service.dart';
import 'auth/login_screen.dart';
import 'server_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VpnServer? _selectedServer;

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnConnectionService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginScreen(authService: auth)),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          _StatusCircle(status: vpn.status),
          const SizedBox(height: 24),
          Text(_statusText(vpn.status), style: Theme.of(context).textTheme.titleMedium),
          if (vpn.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                vpn.errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 40),
          _ServerSelector(
            server: _selectedServer,
            onTap: () async {
              final result = await Navigator.push<VpnServer>(
                context,
                MaterialPageRoute(
                  builder: (_) => ServerListScreen(
                    selectedServer: _selectedServer,
                    onServerSelected: (s) => Navigator.pop(context, s),
                  ),
                ),
              );
              if (result != null) {
                setState(() => _selectedServer = result);
              }
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedServer == null
                    ? null
                    : () {
                        if (vpn.status == VpnStatus.connected) {
                          vpn.disconnect();
                        } else if (vpn.status == VpnStatus.disconnected ||
                            vpn.status == VpnStatus.error) {
                          if (auth.token == null) return;
                          vpn.connectToServer(
                            serverId: _selectedServer!.id,
                            authToken: auth.token!,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: vpn.status == VpnStatus.connected ? Colors.red : Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  vpn.status == VpnStatus.connected ? 'Отключиться' : 'Подключиться',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        return 'Подключено';
      case VpnStatus.connecting:
        return 'Подключение...';
      case VpnStatus.disconnecting:
        return 'Отключение...';
      case VpnStatus.error:
        return 'Ошибка подключения';
      case VpnStatus.disconnected:
        return 'Не подключено';
    }
  }
}

class _StatusCircle extends StatelessWidget {
  final VpnStatus status;
  const _StatusCircle({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VpnStatus.connected => Colors.green,
      VpnStatus.connecting || VpnStatus.disconnecting => Colors.orange,
      VpnStatus.error => Colors.red,
      VpnStatus.disconnected => Colors.grey,
    };
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(Icons.shield, size: 56, color: color),
    );
  }
}

class _ServerSelector extends StatelessWidget {
  final VpnServer? server;
  final VoidCallback onTap;
  const _ServerSelector({required this.server, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(server?.flagEmoji ?? '🌐', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                server?.name ?? 'Выбрать сервер',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
