# this file is in streamline syntax!
# https://github.com/Sage/streamlinejs

expect = require 'expect.js'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# data we're going to use:
danielData =
    name: 'Daniel'
aseemData =
    name: 'Aseem'

# instances we're going to reuse across tests:
daniel = null
aseem = null
relationship = null

@crud =

    'create nodes': (_) ->
        daniel = db.createNode danielData
        aseem = db.createNode aseemData

        expect(daniel).to.be.an 'object'
        expect(daniel.exists).to.be false
        expect(daniel.self).to.be null
            # TODO should this really be tested? is @self a public API?
            # maybe it should just have a better name than 'self'? like url?

    'save nodes': (_) ->
        # test futures here by saving both aseem and daniel in parallel:
        futures = [daniel.save(), aseem.save()]
        future _ for future in futures

        expect(daniel.exists).to.be true
        expect(daniel.self).to.be.a 'string'    # TODO see above
        expect(daniel.self).to.not.equal aseem.self     # TODO see above
        expect(daniel.data).to.eql danielData

        expect(aseem.exists).to.be true
        expect(aseem.self).to.be.a 'string'     # TODO see above
        expect(aseem.self).to.not.equal daniel.self     # TODO see above
        expect(aseem.data).to.eql aseemData

    'create realtionships': (_) ->
        relationship = daniel.createRelationshipTo aseem, 'follows', {created: Date.now()}, _
        testRelationship relationship

        # in this case, the start and end *should* be our instances
        expect(relationship.start).to.be daniel
        expect(relationship.end).to.be aseem

    'fetch relationships': (_) ->
        # test futures by *initiating* getRelationships() for both aseem and daniel in
        # parallel. note how we'll still "collect" (process) the futures in sequence.
        danielFuture = daniel.getRelationships('follows')
        aseemFuture = aseem.getRelationships('follows')

        relationships = danielFuture _
        testRelationships relationships

        # in this case, the start *should* be our instance
        expect(relationships[0].start).to.be daniel

        relationships = aseemFuture _
        testRelationships relationships

        # in this case, the end *should* be our instance
        expect(relationships[0].end).to.be aseem

    'traverse nodes': (_) ->
        # same parallel lookups using futures:
        danielFuture = daniel.getRelationshipNodes('follows')
        aseemFuture = aseem.getRelationshipNodes('follows')

        nodes = danielFuture _
        expect(nodes).to.be.an 'array'
        expect(nodes).to.have.length 1
        expect(nodes[0]).to.be.an 'object'
        expect(nodes[0].exists).to.be true
        expect(nodes[0].self).to.equal aseem.self   # TODO see above
        expect(nodes[0].data).to.eql aseemData

        # TODO see how this is misleading? we don't respect or report direction!
        nodes = aseemFuture _
        expect(nodes).to.be.an 'array'
        expect(nodes).to.have.length 1
        expect(nodes[0]).to.be.an 'object'
        expect(nodes[0].exists).to.be true
        expect(nodes[0].self).to.equal daniel.self  # TODO see above
        expect(nodes[0].data).to.eql danielData

    'index nodes': (_) ->
        daniel.index 'users', 'name', 'Daniel', _
        node = db.getIndexedNode 'users', 'name', 'Daniel', _
        expect(node).to.be.an 'object'
        expect(node.exists).to.be true
        # TODO FIXME we're not unindexing these nodes after each test, so in fact the
        # returned node and data might be from a previous test!
        # expect(node.self).to.equal daniel.self  # TODO see above
        # expect(node.data).to.eql danielData

    'index relationships': (_) ->
        relationship.index 'follows', 'name', 'Daniel', _
        rel = db.getIndexedRelationship 'follows', 'name', 'Daniel', _
        expect(rel).to.be.an 'object'
        expect(rel.exists).to.be true
        expect(rel.self).to.be.a 'string'   # TODO see above
        expect(rel.type).to.be 'follows'

    # TODO delete tests! that's the 'd' in 'crud'!

testRelationship = (relationship) ->
    expect(relationship).to.be.an 'object'
    expect(relationship.exists).to.be true
    expect(relationship.self).to.be.a 'string'  # TODO see above
    expect(relationship.type).to.be 'follows'

    # in some cases, the start/end nodes may not be "filled", so these are
    # commented out for now:
    # expect(relationship.start).to.eql daniel
    # expect(relationship.end).to.eql aseem

    # TEMP so for the time being, we're testing that at least
    # their "selves" match. not sure if this is a public API.
    expect(relationship.start).to.be.an 'object'
    expect(relationship.end).to.be.an 'object'
    expect(relationship.start.self).to.equal daniel.self
    expect(relationship.end.self).to.equal aseem.self

testRelationships = (relationships) ->
    expect(relationships).to.be.an 'array'
    expect(relationships).to.have.length 1
    testRelationship relationships[0]
