# this file is in streamline syntax!
# https://github.com/Sage/streamlinejs

{expect} = require 'chai'
flows = require 'streamline/lib/util/flows'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# data we're going to use:
danielData =
    name: 'Daniel'
aseemData =
    name: 'Aseem'
matData =
    name: 'Mat'
    name2: 'Matt'
    id: '12345'
indexConfig =
    type: 'fulltext'
    provider: 'lucene'
    to_lower_case: 'true'
indexConfig2 =
    type: 'fulltext'
    to_lower_case: 'false'

# instances we're going to reuse across tests:
daniel = null
aseem = null
mat = null
relationship = null

# index list
nodeIndexName = 'testUsers'
nodeCustomIndexName = 'testUsersFullTextLowercase'
nodeCustomIndexName2 = 'testUsersFullTextNoLowercase'
relIndexName = 'testFollows'
relCustomIndexName = 'testFollowsFullTextLowercase'
relCustomIndexName2 = 'testFollowsFullTextNoLowercase'


## TESTS:

@crud =

    'getNodeIndexes': (_) ->
        nodeIndexes = db.getNodeIndexes _

        # we should always get back an array of names, but the array should
        # have map-like properties for the index config details too:
        expect(nodeIndexes).to.be.an 'array'
        for name in nodeIndexes
            expect(nodeIndexes).to.contain.key name
            expect(nodeIndexes[name]).to.be.an 'object'
            expect(nodeIndexes[name].type).to.be.a 'string'

    'getRelationshipIndexes': (_) ->
        relIndexes = db.getRelationshipIndexes _

        # we should always get back an array of names, but the array should
        # have map-like properties for the index config details too:
        expect(relIndexes).to.be.an 'array'
        for name in relIndexes
            expect(relIndexes).to.contain.key name
            expect(relIndexes[name]).to.be.an 'object'
            expect(relIndexes[name].type).to.be.a 'string'

    'createNodeIndex': (_) ->
        db.createNodeIndex nodeIndexName, _

        # our newly created index should now be in the list of indexes:
        nodeIndexes = db.getNodeIndexes _
        expect(nodeIndexes).to.contain nodeIndexName
        expect(nodeIndexes).to.contain.key nodeIndexName

    'createNodeIndex custom fulltext with lowercase': (_) ->
        db.createNodeIndex nodeCustomIndexName, indexConfig, _

        # our newly created index should now be in the list of indexes:
        nodeIndexes = db.getNodeIndexes _
        expect(nodeIndexes).to.contain nodeCustomIndexName
        expect(nodeIndexes).to.contain.key nodeCustomIndexName

    'createNodeIndex custom fulltext with no lowercase': (_) ->
        db.createNodeIndex nodeCustomIndexName2, indexConfig, _

        # our newly created index should now be in the list of indexes:
        nodeIndexes = db.getNodeIndexes _
        expect(nodeIndexes).to.contain nodeCustomIndexName2
        expect(nodeIndexes).to.contain.key nodeCustomIndexName2

    'createRelationshipIndex': (_) ->
        db.createRelationshipIndex relIndexName, _

        # our newly created index should now be in the list of indexes:
        relIndexes = db.getRelationshipIndexes _
        expect(relIndexes).to.contain relIndexName
        expect(relIndexes).to.contain.key relIndexName

    'createRelationshipIndex custom fulltext with lowercase': (_) ->
        db.createRelationshipIndex relCustomIndexName, indexConfig, _

        # our newly created index should now be in the list of indexes:
        relIndexes = db.getRelationshipIndexes _
        expect(relIndexes).to.contain relCustomIndexName
        expect(relIndexes).to.contain.key relCustomIndexName

    'createRelationshipIndex custom fulltext with no lowercase': (_) ->
        db.createRelationshipIndex relCustomIndexName2, indexConfig, _

        # our newly created index should now be in the list of indexes:
        relIndexes = db.getRelationshipIndexes _
        expect(relIndexes).to.contain relCustomIndexName2
        expect(relIndexes).to.contain.key relCustomIndexName2

    'create nodes': (_) ->
        daniel = db.createNode danielData
        aseem = db.createNode aseemData
        mat = db.createNode matData

        expect(daniel).to.be.an 'object'
        expect(daniel.exists).to.be.false
        expect(daniel.self).to.not.exist
            # TODO should this really be tested? is @self a public API?
            # maybe it should just have a better name than 'self'? like url?

    'save nodes': (_) ->
        # test futures here by saving both aseem and daniel in parallel:
        flows.collect _, [
            daniel.save not _
            aseem.save not _
            mat.save not _
        ]

        expect(daniel.exists).to.be.true
        expect(daniel.self).to.be.a 'string'    # TODO see above
        expect(daniel.self).to.not.equal aseem.self     # TODO see above
        expect(daniel.data).to.eql danielData

        expect(aseem.exists).to.be.true
        expect(aseem.self).to.be.a 'string'     # TODO see above
        expect(aseem.self).to.not.equal daniel.self     # TODO see above
        expect(aseem.data).to.eql aseemData

    'create realtionships': (_) ->
        relationship = daniel.createRelationshipTo aseem, 'follows', {created: Date.now()}, _
        testRelationship relationship

        # in this case, the start and end *should* be our instances
        expect(relationship.start).to.eq daniel
        expect(relationship.end).to.eq aseem

    'serialize & de-serialize nodes': (_) ->
        json = JSON.stringify [aseem, daniel]
        obj = JSON.parse json, db.reviveJSON

        expect(obj).to.be.an 'array'
        expect(obj).to.have.length 2

        [aseem2, daniel2] = obj

        expect(aseem2).to.be.an 'object'
        expect(aseem2.data).to.eql aseem.data

        expect(daniel2).to.be.an 'object'
        expect(daniel2.data).to.eql daniel.data

    'serialize & de-serialize relationship': (_) ->
        json = JSON.stringify {foo: {bar: relationship}}
        obj = JSON.parse json, db.reviveJSON

        expect(obj).to.be.an 'object'
        expect(obj.foo).to.be.an 'object'

        rel2 = obj.foo.bar

        expect(rel2).to.be.an 'object'
        expect(rel2.data).to.eql relationship.data

    'fetch relationships': (_) ->
        # test futures by *initiating* getRelationships() for both aseem and daniel in
        # parallel. note how we'll still "collect" (process) the futures in sequence.
        danielFuture = daniel.getRelationships 'follows', not _
        aseemFuture = aseem.getRelationships 'follows', not _

        relationships = danielFuture _
        testRelationships relationships

        # in this case, the start *should* be our instance
        expect(relationships[0].start).to.eq daniel

        relationships = aseemFuture _
        testRelationships relationships

        # in this case, the end *should* be our instance
        expect(relationships[0].end).to.eq aseem

    'traverse nodes': (_) ->
        # same parallel lookups using futures:
        danielFuture = daniel.getRelationshipNodes 'follows', not _
        aseemFuture = aseem.getRelationshipNodes 'follows', not _

        nodes = danielFuture _
        expect(nodes).to.be.an 'array'
        expect(nodes).to.have.length 1
        expect(nodes[0]).to.be.an 'object'
        expect(nodes[0].exists).to.be.true
        expect(nodes[0].self).to.equal aseem.self   # TODO see above
        expect(nodes[0].data).to.eql aseemData

        # TODO see how this is misleading? we don't respect or report direction!
        nodes = aseemFuture _
        expect(nodes).to.be.an 'array'
        expect(nodes).to.have.length 1
        expect(nodes[0]).to.be.an 'object'
        expect(nodes[0].exists).to.be.true
        expect(nodes[0].self).to.equal daniel.self  # TODO see above
        expect(nodes[0].data).to.eql danielData

    'index nodes': (_) ->
        daniel.index 'users', 'name', 'Daniel', _
        node = db.getIndexedNode 'users', 'name', 'Daniel', _
        expect(node).to.be.an 'object'
        expect(node.exists).to.be.true
        daniel.unindex 'users', 'name', 'Daniel', _ # Delete created node index
        # TODO FIXME we're not unindexing these nodes after each test, so in fact the
        # returned node and data might be from a previous test!
        # expect(node.self).to.equal daniel.self  # TODO see above
        # expect(node.data).to.eql danielData

    # Since fulltext search is using Lucene Query Language we cannot use getIndexedNode, instead we use queryNodeIndex method
    'index nodes to custom fulltext index with lowercase': (_) ->
        daniel.index nodeCustomIndexName, 'name', 'Daniel', _
        nodes = db.queryNodeIndex nodeCustomIndexName, 'name:dan*', _
        expect(nodes).to.be.an 'array'
        expect(nodes[0].exists).to.be.true
        daniel.unindex nodeCustomIndexName, 'name', 'Daniel', _ # Delete created custom node index

    'index nodes to custom fulltext index with no lowercase': (_) ->
        daniel.index nodeCustomIndexName2, 'name', 'Daniel', _
        nodes = db.queryNodeIndex nodeCustomIndexName2, 'name:Dan*', _
        expect(nodes).to.be.an 'array'
        expect(nodes[0].exists).to.be.true
        daniel.unindex nodeCustomIndexName2, 'name', 'Daniel', _ # Delete created custom node index

    'index relationships': (_) ->
        relationship.index 'follows', 'name', 'Daniel', _
        rel = db.getIndexedRelationship 'follows', 'name', 'Daniel', _
        expect(rel).to.be.an 'object'
        expect(rel.exists).to.be.true
        expect(rel.self).to.be.a 'string'   # TODO see above
        expect(rel.type).to.eq 'follows'
        relationship.unindex 'follows', 'name', 'Daniel', _ # Delete created relationship index

    # Since fulltext search is using Lucene Query Language we cannot use getIndexedRelationship, instead we use queryRelationshipIndex method
    # queryRelationshipIndex method was not implemented, so I implemented it for this method to work
    # Due to comments of queryNodeIndex method, queryRelationshipIndex was a to-do
    'index relationships to custom fulltext index with lowercase': (_) ->
        relationship.index relCustomIndexName, 'name', 'Daniel', _
        rels = db.queryRelationshipIndex relCustomIndexName, 'name:*niE*', _
        expect(rels).to.be.an 'array'
        expect(rels[0].exists).to.be.true
        expect(rels[0].self).to.be.a 'string'
        expect(rels[0].type).to.eq 'follows'
        relationship.unindex relCustomIndexName, 'name', 'Daniel', _ # Delete created custom relationship index

    'index relationships to custom fulltext index with no lowercase': (_) ->
        relationship.index relCustomIndexName2, 'name', 'Daniel', _
        rels = db.queryRelationshipIndex relCustomIndexName2, 'name:*nie*', _
        expect(rels).to.be.an 'array'
        expect(rels[0].exists).to.be.true
        expect(rels[0].self).to.be.a 'string'
        expect(rels[0].type).to.eq 'follows'
        relationship.unindex relCustomIndexName2, 'name', 'Daniel', _ # Delete created custom relationship index

    'unindex nodes': (_) ->
        mat.index nodeIndexName, 'name', 'Mat', _
        mat.index nodeIndexName, 'name', 'Matt', _
        mat.index nodeIndexName, 'id', '12345', _

        # delete entries for the node that match index, key, value
        mat.unindex nodeIndexName, 'name', 'Matt', _
        mattNode = db.getIndexedNode nodeIndexName, 'name', 'Matt', _
        matNode = db.getIndexedNode nodeIndexName, 'name', 'Mat', _
        idNode = db.getIndexedNode nodeIndexName, 'id', '12345', _
        expect(mattNode).to.not.exist
        expect(matNode).to.be.an 'object'
        expect(matNode.exists).to.be.true
        expect(idNode).to.be.an 'object'
        expect(idNode.exists).to.be.true

        # delete entries for the node that match index, key
        mat.unindex nodeIndexName, 'name', _
        mattNode = db.getIndexedNode nodeIndexName, 'name', 'Matt', _
        matNode = db.getIndexedNode nodeIndexName, 'name', 'Mat', _
        idNode = db.getIndexedNode nodeIndexName, 'id', '12345', _
        expect(mattNode).to.not.exist
        expect(matNode).to.not.exist
        expect(idNode).to.be.an 'object'
        expect(idNode.exists).to.be.true

        # delete entries for the node that match index
        mat.unindex nodeIndexName, _
        mattNode = db.getIndexedNode nodeIndexName, 'name', 'Matt', _
        matNode = db.getIndexedNode nodeIndexName, 'name', 'Mat', _
        idNode = db.getIndexedNode nodeIndexName, 'id', '12345', _
        expect(mattNode).to.not.exist
        expect(matNode).to.not.exist
        expect(idNode).to.not.exist

    'unindex relationships': (_) ->
        relationship.index relIndexName, 'name', 'Mat', _
        relationship.index relIndexName, 'name', 'Matt', _
        relationship.index relIndexName, 'id', '12345', _

        # delete entries for the relationship that match index, key, value
        relationship.unindex relIndexName, 'name', 'Matt', _
        mattRelationship = db.getIndexedRelationship relIndexName, 'name', 'Matt', _
        matRelationship = db.getIndexedRelationship relIndexName, 'name', 'Mat', _
        idRelationship = db.getIndexedRelationship relIndexName, 'id', '12345', _
        expect(mattRelationship).to.not.exist
        expect(matRelationship).to.be.an 'object'
        expect(matRelationship.exists).to.be.true
        expect(idRelationship).to.be.an 'object'
        expect(idRelationship.exists).to.be.true

        # delete entries for the relationship that match index, key
        relationship.unindex relIndexName, 'name', _
        mattRelationship = db.getIndexedRelationship relIndexName, 'name', 'Matt', _
        matRelationship = db.getIndexedRelationship relIndexName, 'name', 'Mat', _
        idRelationship = db.getIndexedRelationship relIndexName, 'id', '12345', _
        expect(mattRelationship).to.not.exist
        expect(matRelationship).to.not.exist
        expect(idRelationship).to.be.an 'object'
        expect(idRelationship.exists).to.be.true

        # delete entries for the relationship that match index
        relationship.unindex relIndexName, _
        mattRelationship = db.getIndexedRelationship relIndexName, 'name', 'Matt', _
        matRelationship = db.getIndexedRelationship relIndexName, 'name', 'Mat', _
        idRelationship = db.getIndexedRelationship relIndexName, 'id', '12345', _
        expect(mattRelationship).to.not.exist
        expect(matRelationship).to.not.exist
        expect(idRelationship).to.not.exist

    # TODO test deleting nodes and relationships!

    'deleteNodeIndex': (_) ->
        db.deleteNodeIndex nodeIndexName, _

        # our index should no longer be in the list of indexes:
        nodeIndexes = db.getNodeIndexes _
        expect(nodeIndexes).to.not.contain nodeIndexName
        expect(nodeIndexes).to.not.contain.key nodeIndexName

    'deleteRelationshipIndex': (_) ->
        db.deleteRelationshipIndex relIndexName, _

        # our index should no longer be in the list of indexes:
        relIndexes = db.getRelationshipIndexes _
        expect(relIndexes).to.not.contain relIndexName
        expect(relIndexes).to.not.contain.key relIndexName


## HELPERS:

testRelationship = (relationship) ->
    expect(relationship).to.be.an 'object'
    expect(relationship.exists).to.be.true
    expect(relationship.self).to.be.a 'string'  # TODO see above
    expect(relationship.type).to.eq 'follows'

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
