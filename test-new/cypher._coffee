#
# Tests for the GraphDatabase `cypher` method, e.g. the ability to make queries,
# parametrize them, have responses be auto-parsed for nodes & rels, etc.
#

{expect} = require 'chai'
fixtures = require './fixtures'
neo4j = require '../'


## SHARED STATE
# TODO: De-dupe these with the HTTP test suite.

{DB, TEST_LABEL, TEST_REL_TYPE} = fixtures

[DB_VERSION_STR, DB_VERSION_NUM] = []

TEST_NODE_A = new neo4j.Node
    # _id will get filled in once we persist
    labels: [TEST_LABEL]
    properties: {suite: module.filename, name: 'a'}

TEST_NODE_B = new neo4j.Node
    # _id will get filled in once we persist
    labels: [TEST_LABEL]
    properties: {suite: module.filename, name: 'b'}

TEST_REL = new neo4j.Relationship
    # _id, _fromId (node A), _toId (node B) will get filled in once we persist
    type: TEST_REL_TYPE
    properties: {suite: module.filename, name: 'r'}


## HELPERS

#
# Asserts that the given object is an instance of the proper Neo4j Error
# subclass, representing the given transactional Neo4j error info.
# TODO: Consider consolidating with a similar helper in the `http` test suite.
#
expectError = (err, classification, category, title, message) ->
    expect(err).to.be.an.instanceOf neo4j[classification]   # e.g. DatabaseError
    expect(err.name).to.equal "neo4j.#{classification}"
    expect(err.message).to.equal "[#{category}.#{title}] #{message}"
    expect(err.stack).to.contain '\n'
    expect(err.stack.split('\n')[0]).to.equal "#{err.name}: #{err.message}"
    expect(err.neo4j).to.be.an 'object'
    expect(err.neo4j).to.eql
        code: "Neo.#{classification}.#{category}.#{title}"
        message: message


## TESTS

describe 'GraphDatabase::cypher', ->

    it 'should support simple queries and results', (_) ->
        results = DB.cypher 'RETURN "bar" AS foo', _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 1

        [result] = results

        expect(result).to.be.an 'object'
        expect(result).to.contain.keys 'foo'    # this is an exact/"only" check
        expect(result.foo).to.equal 'bar'

    it 'should support simple parameters', (_) ->
        [result] = DB.cypher
            query: 'RETURN {foo} AS foo'
            params: {foo: 'bar'}
        , _

        expect(result).to.be.an 'object'
        expect(result.foo).to.equal 'bar'

    it 'should support complex queries, params, and results', (_) ->
        results = DB.cypher
            query: '''
                UNWIND {nodes} AS node
                WITH node
                ORDER BY node.id
                LIMIT {count}
                RETURN node.id, node.name, {count}
            '''
            params:
                count: 3
                nodes: [
                    {id: 2, name: 'Bob'}
                    {id: 4, name: 'Dave'}
                    {id: 1, name: 'Alice'}
                    {id: 3, name: 'Carol'}
                ]
        , _

        expect(results).to.eql [
            'node.id': 1
            'node.name': 'Alice'
            '{count}': 3
        ,
            'node.id': 2
            'node.name': 'Bob'
            '{count}': 3
        ,
            'node.id': 3
            'node.name': 'Carol'
            '{count}': 3
        ]

    it 'should support queries that return nothing', (_) ->
        results = DB.cypher
            query: 'MATCH (n:FooBarBazThisLabelDoesntExist) RETURN n'
            params: {unused: 'param'}
        , _

        expect(results).to.be.empty()

    it 'should reject empty/missing queries', ->
        fn1 = -> DB.cypher '', ->
        fn2 = -> DB.cypher {}, ->
        expect(fn1).to.throw TypeError, /query/i
        expect(fn2).to.throw TypeError, /query/i

    it 'should properly parse and throw Neo4j errors', (done) ->
        DB.cypher 'RETURN {foo}', (err, results) ->
            try
                expect(err).to.exist()
                expect(results).to.not.exist()

                expectError err, 'ClientError', 'Statement',
                    'ParameterMissing', 'Expected a parameter named foo'

            catch assertionErr
                return done assertionErr

            done()

    # TODO: De-dupe with the HTTP test suite.
    it '(query Neo4j version)', (_) ->
        info = DB.http
            method: 'GET'
            path: '/db/data/'
        , _

        DB_VERSION_STR = info.neo4j_version or '0'
        DB_VERSION_NUM = parseFloat DB_VERSION_STR, 10

        if DB_VERSION_NUM < 2
            throw new Error '*** node-neo4j v2 supports Neo4j v2+ only,
                and you’re running Neo4j v1. These tests will fail! ***'

        # Neo4j <2.1.5 didn't return label info, so returned nodes won't have
        # the labels we expect. Account for that:
        if DB_VERSION_STR < '2.1.5'
            TEST_NODE_A.labels = null
            TEST_NODE_B.labels = null

    it 'should properly parse nodes & relationships', (_) ->
        # We do a complex return to test nested/wrapped objects too.
        # NOTE: However, returning an array changes the order of the returned
        # results, no longer the deterministic order of [a, b, r].
        # We overcome this by explicitly indexing and ordering.
        results = DB.cypher
            query: """
                CREATE (a:#{TEST_LABEL} {propsA})
                CREATE (b:#{TEST_LABEL} {propsB})
                CREATE (a) -[r:#{TEST_REL_TYPE} {propsR}]-> (b)
                WITH [
                    {i: 0, elmt: a, id: ID(a)},
                    {i: 1, elmt: b, id: ID(b)},
                    {i: 2, elmt: r, id: ID(r)}
                ] AS array
                UNWIND array AS obj
                RETURN obj.i, obj.id AS _id, [{
                    inner: obj.elmt
                }] AS outer
                ORDER BY obj.i
            """
            params:
                propsA: TEST_NODE_A.properties
                propsB: TEST_NODE_B.properties
                propsR: TEST_REL.properties
        , _

        # We need to grab the native IDs of the objects we created, but after
        # that, we can just compare object equality for simplicity.

        expect(results).to.have.length 3

        [resultA, resultB, resultR] = results

        TEST_NODE_A._id = resultA._id
        TEST_NODE_B._id = resultB._id
        TEST_REL._id = resultR._id
        TEST_REL._fromId = TEST_NODE_A._id
        TEST_REL._toId = TEST_NODE_B._id

        expect(results).to.eql [
            'obj.i': 0
            _id: TEST_NODE_A._id
            outer: [
                inner: TEST_NODE_A
            ]
        ,
            'obj.i': 1
            _id: TEST_NODE_B._id
            outer: [
                inner: TEST_NODE_B
            ]
        ,
            'obj.i': 2
            _id: TEST_REL._id
            outer: [
                inner: TEST_REL
            ]
        ]

        # But also test that the returned objects are proper instances:
        expect(resultA.outer[0].inner).to.be.an.instanceOf neo4j.Node
        expect(resultB.outer[0].inner).to.be.an.instanceOf neo4j.Node
        expect(resultR.outer[0].inner).to.be.an.instanceOf neo4j.Relationship

    it 'should not parse nodes & relationships if raw', (_) ->
        results = DB.cypher
            query: """
                START a = node({idA})
                MATCH (a) -[r]-> (b)
                RETURN a, b, r
            """
            params:
                idA: TEST_NODE_A._id
            raw: true
        , _

        expect(results).to.eql [
            a: TEST_NODE_A.properties
            b: TEST_NODE_B.properties
            r: TEST_REL.properties
        ]

    it 'should support streaming (TODO)'

    it '(delete test objects)', (_) ->
        DB.cypher
            query: """
                START a = node({idA}), b = node({idB}), r = rel({idR})
                DELETE a, b, r
            """
            params:
                idA: TEST_NODE_A._id
                idB: TEST_NODE_B._id
                idR: TEST_REL._id
        , _
