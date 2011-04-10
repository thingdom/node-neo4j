assert = require 'assert'
neo4j = require '../lib/neo4j.coffee'

db = new neo4j.GraphDatabase 'http://localhost:7474'

danielData =
    name: 'Daniel'

aseemData =
    name: 'Aseem'

db.getRoot (err, root) ->
    assert.ifError err

daniel = db.createNode danielData
aseem = db.createNode aseemData

assert.strictEqual daniel.exists, false, 'Node should not exist'
assert.strictEqual daniel.self, null, 'Node self should be null'

daniel.save (err, node) ->
    assert.ifError err
    assert.deepEqual node.data, danielData, 'Sent and received data should match'
    assert.strictEqual node.exists, true, 'Node should exist'
    assert.ok node.self, 'node.self should not be null'

    aseem.save (err, node) ->
        assert.ifError err
        assert.deepEqual node.data, aseemData, 'Sent and received data should match'
        assert.strictEqual node.exists, true, 'Node should exist'
        assert.ok node.self, 'node.self should not be null'

        daniel.createRelationshipTo aseem, 'follows', {created: Date.now()},
            (err, relationship) ->
                assert.ifError err
                assert.strictEqual node.exists, true, 'Relationship should exist'
                assert.ok node.self, 'relationship.self should not be null'

    daniel.index 'users', 'name', 'Daniel',
        (err) =>
            assert.ifError err
            db.getIndexedNode 'users', 'name', 'Daniel',
                (err, node) ->
                    assert.ifError err
                    assert.ok node
