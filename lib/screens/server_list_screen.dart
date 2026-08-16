import 'package:flutter/material.dart';
import '../models/server.dart';
import '../services/api_service.dart';
import '../widgets/server_tile.dart';

class ServerListScreen extends StatefulWidget {
  final VpnServer? selectedServer;
  final ValueChanged<VpnServer> onServerSelected;

  const ServerListScreen({
    super.key,
    required this.selectedServer,
    required this.onServerSelected,
  });

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  late Future<List<VpnServer>> _serversFuture;

  @override
  void initState() {
    super.initState();
    _serversFuture = ApiService.fetchServers();
  }

  Future<void> _refresh() async {
    setState(() {
      _serversFuture = ApiService.fetchServers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор сервера')),
      body: FutureBuilder<List<VpnServer>>(
        future: _serversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Ошибка загрузки: ${snapshot.error}'),
                  TextButton(onPressed: _refresh, child: const Text('Повторить')),
                ],
              ),
            );
          }

          final servers = snapshot.data ?? [];
          if (servers.isEmpty) {
            return const Center(child: Text('Нет доступных серверов'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                return ServerTile(
                  server: server,
                  isSelected: widget.selectedServer?.id == server.id,
                  onTap: () {
                    widget.onServerSelected(server);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
