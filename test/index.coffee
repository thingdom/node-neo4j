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

# TODO should this really be tested? is @self a public API?
assert.strictEqual daniel.self, null, 'Node self should be null'

# TODO why does save() callback w/ a new node? does it also (i.e. shouldn't
# it?) update the existing instance that save() was called on? if so, it might
# be better for us to not send a node arg to callback; just callback(err?).
daniel.save (err, node) ->
    assert.ifError err
    assert.ok node  # TEMP see above; should we even callback w/ a node arg?
    assert.ok node.exists, 'Node should exist'
    assert.ok node.self, 'node.self should not be null'     # TODO see above
    assert.deepEqual node.data, danielData, 'Sent and received data should match'

    # TODO see above
    aseem.save (err, node) ->
        assert.ifError err
        assert.ok node  # TEMP see above
        assert.ok node.exists, 'Node should exist'
        assert.ok node.self, 'node.self should not be null'
        assert.deepEqual node.data, aseemData, 'Sent and received data should match'

        testRelationship = (relationship) ->
            assert.ok relationship
            assert.ok relationship.exists, 'Relationship should exist'
            assert.ok relationship.self, 'relationship.self should not be null'     # TODO see above
            assert.equal relationship.type, 'follows', 'Relationship type should be "follows".'
            
            # in some cases, the start/end nodes may not be "filled".
            # they also may not point to the same instances we have.
            #assert.equal relationship.start, daniel
            #assert.equal relationship.end, aseem
            
            # TEMP so for the time being, we're testing that at least
            # their "selves" match. not sure if this is a public API.
            assert.ok relationship.start, 'Relationship should have a start node.'
            assert.ok relationship.end, 'Relationship should have an end node.'
            assert.equal relationship.start.self, daniel.self
            assert.equal relationship.end.self, aseem.self
        
        testRelationships = (relationships) ->
            assert.ok relationships
            assert.ok relationships.length, 'Relationships should be an array.'
            assert.equal relationships.length, 1, 'There should only be one relationship.'
            testRelationship(relationships[0])
        
        daniel.createRelationshipTo aseem, 'follows', {created: Date.now()},
            (err, relationship) ->
                assert.ifError err
                testRelationship(relationship)
                
                # in this case, the start and end *should* be our instances
                assert.strictEqual relationship.start, daniel
                assert.strictEqual relationship.end, aseem
                
                daniel.getRelationships 'follows', (err, relationships) ->
                    assert.ifError err
                    testRelationships(relationships)
                    
                    # in this case, the start *should* be our instance
                    assert.equal relationships[0].start, daniel
                
                aseem.getRelationships 'follows', (err, relationships) ->
                    assert.ifError err
                    testRelationships(relationships)
                    
                    # in this case, the end *should* be our instance
                    assert.equal relationships[0].end, aseem

    daniel.index 'users', 'name', 'Daniel',
        (err) =>
            assert.ifError err
            db.getIndexedNode 'users', 'name', 'Daniel',
                (err, node) ->
                    assert.ifError err
                    assert.ok node
