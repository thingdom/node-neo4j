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
    code = "Neo.#{classification}.#{category}.#{title}"

    expect(err).to.be.an.instanceOf neo4j[classification]   # e.g. DatabaseError
    expect(err.name).to.equal "neo4j.#{classification}"

    # If the actual error message is multi-line, it includes the Neo4j stack
    # trace; test that in a simple way by just checking the first line of the
    # trace (subsequent lines can be different, e.g. "Caused by"), but also test
    # that the first line of the message matches the expected message:
    expect(err.message).to.be.a 'string'
    [errMessageLine1, errMessageLine2, ...] = err.message.split '\n'
    expect(errMessageLine1).to.equal "[#{code}] #{message}"
    expect(errMessageLine2).to.match ///
        ^ \s+ at\ [^(]+ \( [^)]+ [.](java|scala):\d+ \)
    /// if errMessageLine2

    expect(err.stack).to.be.a 'string'
    expect(err.stack).to.contain '\n'
    expect(err.stack).to.contain "#{err.name}: #{err.message}"
    [errStackLine1, ...] = err.stack.split '\n'
    expect(errStackLine1).to.equal "#{err.name}: #{errMessageLine1}"

    expect(err.neo4j).to.be.an 'object'
    expect(err.neo4j.code).to.equal code

    # If the actual error message was multi-line, that means it was the Neo4j
    # stack trace, which can include a larger message than the returned one.
    if errMessageLine2
        expect(err.neo4j.message).to.be.a 'string'
        expect(message).to.contain err.neo4j.message
    else
        expect(err.neo4j.message).to.equal message

# TEMP: Neo4j 2.2.0-RC01 incorrectly classifies `ParameterMissing` errors as
# `DatabaseError` rather than `ClientError`.
# https://github.com/neo4j/neo4j/issues/4144
expectParameterMissingError = (err) ->
    try
        expectError err, 'ClientError', 'Statement', 'ParameterMissing',
            'Expected a parameter named foo'

    catch assertionErr
        # Check for the Neo4j 2.2.0-RC01 case, but if it's not,
        # throw the original assertion error, not a new one.
        try
            expectError err, 'DatabaseError', 'Statement', 'ExecutionFailure',
                'org.neo4j.graphdb.QueryExecutionException:
                    Expected a parameter named foo'
        catch doubleErr
            throw assertionErr


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
            expect(err).to.exist()
            expectParameterMissingError err

            # Whether `results` are returned or not depends on the error;
            # Neo4j will return an array if the query could be executed,
            # and then it'll return whatever results it could manage to get
            # before the error. In this case, the query began execution,
            # so we expect an array, but no actual results.
            expect(results).to.be.an 'array'
            expect(results).to.be.empty()

            done()

    it 'should properly return null result on syntax errors', (done) ->
        DB.cypher '(syntax error)', (err, results) ->
            expect(err).to.exist()

            # Simplified error checking, since the message is complex:
            expect(err).to.be.an.instanceOf neo4j.ClientError
            expect(err.neo4j).to.be.an 'object'
            expect(err.neo4j.code).to.equal \
                'Neo.ClientError.Statement.InvalidSyntax'

            # Unlike the previous test case, since Neo4j could not be
            # executed, no results should have been returned at all:
            expect(results).to.not.exist()

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

    it 'should not parse nodes & relationships if lean', (_) ->
        results = DB.cypher
            query: """
                START a = node({idA})
                MATCH (a) -[r]-> (b)
                RETURN a, b, r
            """
            params:
                idA: TEST_NODE_A._id
            lean: true
        , _

        expect(results).to.eql [
            a: TEST_NODE_A.properties
            b: TEST_NODE_B.properties
            r: TEST_REL.properties
        ]

    it 'should support simple batching', (_) ->
        results = DB.cypher [
            query: '''
                START a = node({idA})
                RETURN a
            '''
            params:
                idA: TEST_NODE_A._id
        ,
            query: '''
                START b = node({idB})
                RETURN b
            '''
            params:
                idB: TEST_NODE_B._id
        ,
            query: '''
                START r = rel({idR})
                RETURN r
            '''
            params:
                idR: TEST_REL._id
        ], _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 3

        [resultsA, resultsB, resultsR] = results

        expect(resultsA).to.eql [
            a: TEST_NODE_A
        ]

        expect(resultsB).to.eql [
            b: TEST_NODE_B
        ]

        expect(resultsR).to.eql [
            r: TEST_REL
        ]

    it 'should handle complex batching with errors', (done) ->
        DB.cypher
            queries: [
                query: '''
                    START a = node({idA})
                    RETURN a
                '''
                params:
                    idA: TEST_NODE_A._id
                lean: true
            ,
                'RETURN {foo}'
            ,
                query: '''
                    START r = rel({idR})
                    RETURN r
                '''
                params:
                    idR: TEST_REL._id
            ]
        , (err, results) ->
            expect(err).to.exist()
            expectParameterMissingError err

            # NOTE: With batching, we *do* return any results that we
            # received before the error, in case of an open transaction.
            # This means that we'll always return an array here, and it'll
            # have just as many elements as queries that returned an array
            # before the error. In this case, a ParameterMissing error in
            # the second query means the second array *was* returned (since
            # Neo4j could begin executing the query; see note in the first
            # error handling test case in this suite), so two results.
            expect(results).to.be.an 'array'
            expect(results).to.have.length 2

            [resultsA, resultsB] = results
            expect(resultsA).to.eql [
                a: TEST_NODE_A.properties
            ]
            expect(resultsB).to.be.empty()

            done()

    it 'should support streaming (TODO)'

    it '(delete test graph)', (_) ->
        fixtures.deleteTestGraph module, _
