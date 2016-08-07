#
# NOTE: This file is within a directory named `fixtures`, rather than a file
# named `fixtures._coffee`, in order to not have Mocha treat it like a test.
#

$ = require 'underscore'
{expect} = require 'chai'
helpers = require '../util/helpers'
neo4j = require '../../'

exports.DB = new neo4j.GraphDatabase
    # Support specifying database info via environment variables,
    # but assume Neo4j installation defaults.
    url: process.env.NEO4J_URL or 'http://neo4j:neo4j@localhost:7474'
    auth: process.env.NEO4J_AUTH

# We fill these in, and cache them, the first time tests request them:
exports.DB_VERSION_NUM = null
exports.DB_VERSION_STR = null

exports.TEST_LABEL = 'Test'
exports.TEST_REL_TYPE = 'TEST'

#
# Queries the Neo4j version of the database we're currently testing against,
# if it's not already known.
# Doesn't return anything; instead, `DB_VERSION_*` will be set after this.
#
exports.queryDbVersion = (_) ->
    return if exports.DB_VERSION_NUM

    info = exports.DB.http
        method: 'GET'
        path: '/db/data/'
    , _

    exports.DB_VERSION_STR = info.neo4j_version or '(version unknown)'
    exports.DB_VERSION_NUM = parseFloat exports.DB_VERSION_STR, 10

    if exports.DB_VERSION_NUM < 2
        throw new Error '*** node-neo4j v2 supports Neo4j v2+ only,
            and you’re running Neo4j v1. These tests will fail! ***'

#
# Creates and returns a property bag (dictionary) with unique, random test data
# for the given test suite (pass the suite's Node `module`).
#
exports.createTestProperties = (suite) ->
    suite: suite.filename
    rand: helpers.getRandomStr()

#
# Creates and returns a new Node instance with unique, random test data for the
# given test suite (pass the suite's Node `module`).
#
# NOTE: This method does *not* persist the node. To that end, the returned
# instance *won't* have an `_id` property; you should set it if you persist it.
#
# This method is async because it queries Neo4j's version if we haven't already,
# and strips label metadata if we're running against Neo4j <2.1.5, which didn't
# return label metadata to drivers.
#
exports.createTestNode = (suite, _) ->
    node = new neo4j.Node
        labels: [exports.TEST_LABEL]
        properties: exports.createTestProperties suite

    exports.queryDbVersion _

    if exports.DB_VERSION_STR < '2.1.5'
        node.labels = null

    node

#
# Creates and returns a new Relationship instance with unique, random test data
# for the given test suite (pass the suite's Node `module`).
#
# NOTE: This method does *not* persist the relationship. To that end, the
# returned instance *won't* have its `_id`, `_fromId` or `_toId` properties set;
# you should set those if you persist this relationship.
#
exports.createTestRelationship = (suite) ->
    new neo4j.Relationship
        type: exports.TEST_REL_TYPE
        properties: exports.createTestProperties suite

#
# Executes a Cypher query to create and persist a test graph with the given
# number of nodes, connected in a chain.
#
# TODO: Support other types of graphs, e.g. networks, fan-outs, etc.?
#
# The nodes are identified by the filename of the given test suite (pass the
# suite's Node `module`).
#
# Returns an array of Node and Relationship instances for the created graph,
# in chain order, e.g. [node, rel, node].
#
exports.createTestGraph = (suite, numNodes, _) ->
    expect(numNodes).to.be.at.least 1
    numRels = numNodes - 1

    nodes = (exports.createTestNode suite, _ for i in [0...numNodes])
    rels = (exports.createTestRelationship suite for i in [0...numRels])

    nodeProps = $(nodes).pluck 'properties'
    relProps = $(rels).pluck 'properties'

    params = {}
    for props, i in nodeProps
        params["nodeProps#{i}"] = props
    for props, i in relProps
        params["relProps#{i}"] = props

    query = ''
    for node, i in nodes
        query += "CREATE (node#{i}:#{exports.TEST_LABEL} {nodeProps#{i}}) \n"
    for rel, i in rels
        relStr = "-[rel#{i}:#{exports.TEST_REL_TYPE} {relProps#{i}}]->"
        query += "CREATE (node#{i}) #{relStr} (node#{i + 1}) \n"
    query += 'RETURN '
    query += ("ID(node#{i})" for node, i in nodes).join ', '
    if rels.length
        query += ', '
        query += ("ID(rel#{i})" for rel, i in rels).join ', '

    # NOTE: Using the old Cypher endpoint here. We don't want to rely on this
    # driver's Cypher implementation, nor re-implement the (more complex) new
    # endpoint here. This does, however, rely on this driver's HTTP support in
    # general, but not on its ability to parse nodes and relationships.
    # http://neo4j.com/docs/stable/rest-api-cypher.html#rest-api-use-parameters
    {data} = exports.DB.http
        method: 'POST'
        path: '/db/data/cypher'
        body: {query, params}
    , _

    [row] = data

    for node, i in nodes
        node._id = row[i]

    for rel, i in rels
        rel._id = row[numNodes + i]
        rel._fromId = nodes[i]._id
        rel._toId = nodes[i + 1]._id

    results = []

    for node, i in nodes
        results.push node
        results.push rels[i] if rels[i]

    results

#
# Executes a Cypher query to delete the test graph created by `createTestGraph`
# for the given test suite (pass the suite's Node `module`).
#
exports.deleteTestGraph = (suite, _) ->
    exports.DB.http
        method: 'POST'
        path: '/db/data/cypher'
        body:
            query: """
                MATCH (node:#{exports.TEST_LABEL} {suite: {suite}})
                OPTIONAL MATCH (node) \
                    -[rel:#{exports.TEST_REL_TYPE} {suite: {suite}}]-> ()
                DELETE node, rel
            """
            params: exports.createTestProperties suite
    , _
