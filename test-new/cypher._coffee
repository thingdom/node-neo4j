#
# Tests for the GraphDatabase `cypher` method, e.g. the ability to make queries,
# parametrize them, have responses be auto-parsed for nodes & rels, etc.
#

{expect} = require 'chai'
fixtures = require './fixtures'
neo4j = require '../'


## SHARED STATE

{DB} = fixtures

[TEST_NODE_A, TEST_NODE_B, TEST_REL] = []


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

    it '(create test graph)', (_) ->
        [TEST_NODE_A, TEST_REL, TEST_NODE_B] =
            fixtures.createTestGraph module, 2, _

    it 'should properly parse nodes & relationships', (_) ->
        # We do a complex return to test nested/wrapped objects too.
        # NOTE: However, returning an array changes the order of the returned
        # results, no longer the deterministic order of [a, b, r].
        # We overcome this by explicitly indexing and ordering.
        results = DB.cypher
            query: """
                START a = node({idA})
                MATCH (a) -[r]-> (b)
                WITH [
                    {i: 0, elmt: a},
                    {i: 1, elmt: b},
                    {i: 2, elmt: r}
                ] AS array
                UNWIND array AS obj
                RETURN obj.i AS i, [{
                    inner: obj.elmt
                }] AS outer
                ORDER BY i
            """
            params:
                idA: TEST_NODE_A._id
        , _

        expect(results).to.eql [
            i: 0
            outer: [
                inner: TEST_NODE_A
            ]
        ,
            i: 1
            outer: [
                inner: TEST_NODE_B
            ]
        ,
            i: 2
            outer: [
                inner: TEST_REL
            ]
        ]

        # But also test that the returned objects are proper instances:
        expect(results[0].outer[0].inner).to.be.an.instanceOf neo4j.Node
        expect(results[1].outer[0].inner).to.be.an.instanceOf neo4j.Node
        expect(results[2].outer[0].inner).to.be.an.instanceOf neo4j.Relationship

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

    it '(delete test graph)', (_) ->
        fixtures.deleteTestGraph module, _
