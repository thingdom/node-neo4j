assert = require 'assert'
neo4j = require '../lib/neo4j.coffee'

db = new neo4j.GraphDatabase 'http://localhost:7474'

data =
    hello: 'world'

db.getRoot (err, root) ->
    assert.ifError err

node = db.createNode data

assert.strictEqual node.exists, false
assert.strictEqual node.self, null

node.save (err, node) ->
    assert.ifError err
    assert.deepEqual node.data, data
    assert.strictEqual node.exists, true
    assert.ok node.self
