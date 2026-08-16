import 'package:flutter/material.dart';
import '../models/server.dart';

class ServerTile extends StatelessWidget {
  final VpnServer server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerTile({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.blue, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Text(server.flagEmoji, style: const TextStyle(fontSize: 28)),
        title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(server.country),
        trailing: server.pingMs != null
            ? Text('${server.pingMs} ms', style: TextStyle(color: _pingColor(server.pingMs!)))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Color _pingColor(int ping) {
    if (ping < 80) return Colors.green;
    if (ping < 150) return Colors.orange;
    return Colors.red;
  }
}
