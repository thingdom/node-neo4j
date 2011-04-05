var neo4j = require('../lib/neo4j.js');

// database
var DB_HOST = 'localhost';
var DB_PORT = 7474;

module.exports = new neo4j.Client(DB_HOST, DB_PORT, true);