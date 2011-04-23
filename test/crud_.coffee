# this file is in streamline syntax!
# https://github.com/Sage/streamlinejs

assert = require 'assert'
neo4j = require '../lib/neo4j.coffee'

db = new neo4j.GraphDatabase 'http://localhost:7474'

danielData =
    name: 'Daniel'

aseemData =
    name: 'Aseem'

root = db.getRoot _

daniel = db.createNode danielData
aseem = db.createNode aseemData

assert.strictEqual daniel.exists, false, 'Node should not exist'
assert.strictEqual daniel.self, null, 'Node self should be null'
    # TODO should this really be tested? is @self a public API?
    # maybe it should just have a better name than the misleading 'self'?

# TODO why does save() callback w/ a new node? does it also (i.e. shouldn't
# it?) update the existing instance that save() was called on? if so, it might
# be better for us to not send a node arg to callback; just callback(err?).
node = daniel.save _
assert.ok node  # TEMP see above; should we even callback w/ a node arg?
assert.ok node.exists, 'Node should exist'
assert.ok node.self, 'node.self should not be null'     # TODO see above
assert.deepEqual node.data, danielData, 'Sent and received data should match'

# TODO see above
node = aseem.save _
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

relationship = daniel.createRelationshipTo aseem, 'follows', {created: Date.now()}, _
testRelationship(relationship)

# in this case, the start and end *should* be our instances
assert.strictEqual relationship.start, daniel
assert.strictEqual relationship.end, aseem

# TODO it would be good to test streamline futures support here if/when we
# port the library to streamline style. we could test it here by invoking
# getRelationships() on both daniel and aseem in parallel, then waiting for
# both of them to return (i.e. collecting/syncing both futures).

relationships = daniel.getRelationships 'follows', _
testRelationships(relationships)

# in this case, the start *should* be our instance
assert.equal relationships[0].start, daniel

relationships = aseem.getRelationships 'follows', _
testRelationships(relationships)

# in this case, the end *should* be our instance
assert.equal relationships[0].end, aseem

nodes = daniel.getRelationshipNodes 'follows', _
assert.ok nodes
assert.ok nodes.length
assert.equal nodes.length, 1
assert.ok nodes[0]
assert.ok nodes[0].exists
assert.ok nodes[0].self     # TODO see above
assert.deepEqual nodes[0].data, aseemData

# TODO see how this is misleading? we don't respect or report direction!
nodes = aseem.getRelationshipNodes 'follows', _
assert.ok nodes
assert.ok nodes.length
assert.equal nodes.length, 1
assert.ok nodes[0]
assert.ok nodes[0].exists
assert.ok nodes[0].self     # TODO see above
assert.deepEqual nodes[0].data, danielData

daniel.index 'users', 'name', 'Daniel', _
node = db.getIndexedNode 'users', 'name', 'Daniel', _
assert.ok node

# just to ensure that no sorts of silent transformation errors plagued us
console.log 'passed the shit out of the tests'