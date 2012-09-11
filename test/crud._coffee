# this file is in streamline syntax!
# https://github.com/Sage/streamlinejs

assert = require 'assert'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

danielData =
    name: 'Daniel'

aseemData =
    name: 'Aseem'

daniel = db.createNode danielData
aseem = db.createNode aseemData

assert.strictEqual daniel.exists, false, 'Node should not exist'
assert.strictEqual daniel.self, null, 'Node self should be null'
    # TODO should this really be tested? is @self a public API?
    # maybe it should just have a better name than the misleading 'self'?

# test futures here by saving both aseem and daniel in parallel:
futures = [daniel.save(), aseem.save()]
future _ for future in futures

assert.ok daniel.exists, 'Node should exist'
assert.ok daniel.self, 'node.self should not be null'   # TODO see above
assert.deepEqual daniel.data, danielData, 'Sent and received data should match'

assert.ok aseem.exists, 'Node should exist'
assert.ok aseem.self, 'node.self should not be null'    # TODO see above
assert.deepEqual aseem.data, aseemData, 'Sent and received data should match'

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

# test futures by *initiating* getRelationships() for both aseem and daniel in
# parallel. note how we'll still "collect" (process) the futures in sequence.
danielFuture = daniel.getRelationships 'follows'
aseemFuture = aseem.getRelationships 'follows'

relationships = danielFuture _
testRelationships(relationships)

# in this case, the start *should* be our instance
assert.equal relationships[0].start, daniel

relationships = aseemFuture _
testRelationships(relationships)

# in this case, the end *should* be our instance
assert.equal relationships[0].end, aseem

# same parallel lookups using futures:
danielFuture = daniel.getRelationshipNodes 'follows'
aseemFuture = aseem.getRelationshipNodes 'follows'

nodes = danielFuture _
assert.ok nodes
assert.ok nodes.length
assert.equal nodes.length, 1
assert.ok nodes[0]
assert.ok nodes[0].exists
assert.ok nodes[0].self     # TODO see above
assert.deepEqual nodes[0].data, aseemData

# TODO see how this is misleading? we don't respect or report direction!
nodes = aseemFuture _
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

relationship.index 'follows', 'name', 'Daniel', _
rel = db.getIndexedRelationship 'follows', 'name', 'Daniel', _
assert.ok rel

# TODO delete tests! that's the 'd' in 'crud'!

# just to ensure that no sorts of silent transformation errors plagued us
console.log 'passed CRUD tests'
