const low = require('lowdb');
const FileSync = require('lowdb/adapters/FileSync');
const path = require('path');

const adapter = new FileSync(path.join(__dirname, 'db.json'));
const db = low(adapter);

// Структура: { users: [{ id, email, passwordHash, subscriptionActive, subscriptionExpiresAt, peers: [{serverId, publicKey, privateKey, address}] }] }
db.defaults({ users: [] }).write();

module.exports = db;
