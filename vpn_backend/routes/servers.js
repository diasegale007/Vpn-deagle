const express = require('express');
const { execSync } = require('child_process');
const { NodeSSH } = require('node-ssh');
const { authMiddleware } = require('./authMiddleware');
const db = require('../db/db');
const serverPool = require('../servers.json'); // список серверов с SSH-доступом (без ключей клиентов)

const router = express.Router();

/**
 * GET /api/servers
 * Публичный список серверов (без ключей) — просто для отображения в UI.
 */
router.get('/', (req, res) => {
  const publicList = serverPool.map(({ sshHost, sshUser, sshKeyPath, ...pub }) => pub);
  res.json(publicList);
});

/**
 * POST /api/servers/:id/connect
 * Требует авторизации + активной подписки.
 * Генерирует персональную пару ключей (если её ещё нет для этого сервера),
 * добавляет peer на VPN-сервер по SSH и возвращает готовый конфиг клиенту.
 */
router.post('/:id/connect', authMiddleware, async (req, res) => {
  const user = db.get('users').find({ id: req.userId }).value();
  if (!user) return res.status(404).json({ error: 'Пользователь не найден' });

  if (!user.subscriptionActive) {
    return res.status(403).json({ error: 'Требуется активная подписка' });
  }

  const server = serverPool.find((s) => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Сервер не найден' });

  // Уже есть ключ для этого сервера — переиспользуем
  let peer = user.peers.find((p) => p.serverId === server.id);

  if (!peer) {
    // Генерация новой пары ключей WireGuard.
    // Требует установленного wireguard-tools на машине с бэкендом.
    const privateKey = execSync('wg genkey').toString().trim();
    const publicKey = execSync(`echo "${privateKey}" | wg pubkey`).toString().trim();

    // Следующий свободный IP в подсети сервера — упрощённо, по числу пиров + 2
    const clientNumber = server.nextClientOffset + user.peers.length;
    const address = `${server.subnetPrefix}.${clientNumber}/32`;

    // Добавляем peer на реальный VPN-сервер через SSH
    const ssh = new NodeSSH();
    try {
      await ssh.connect({
        host: server.sshHost,
        username: server.sshUser,
        privateKeyPath: server.sshKeyPath,
      });
      await ssh.execCommand(
        `wg set wg0 peer ${publicKey} allowed-ips ${address}`
      );
      await ssh.execCommand('wg-quick save wg0'); // сохранить в конфиг, чтобы пережило рестарт
    } catch (e) {
      return res.status(500).json({ error: 'Не удалось настроить сервер: ' + e.message });
    } finally {
      ssh.dispose();
    }

    peer = { serverId: server.id, publicKey, privateKey, address };
    user.peers.push(peer);
    db.get('users').find({ id: user.id }).assign({ peers: user.peers }).write();
  }

  res.json({
    id: server.id,
    name: server.name,
    country: server.country,
    flagEmoji: server.flagEmoji,
    endpoint: server.endpoint,
    serverPublicKey: server.serverPublicKey,
    clientPrivateKey: peer.privateKey,
    clientAddress: peer.address,
    dns: server.dns || '1.1.1.1',
  });
});

module.exports = router;
