#
# Tests for Transaction support, e.g. the ability to make multiple queries,
# across network requests, in a single transaction; commit; rollback; etc.
#

{expect} = require 'chai'
fixtures = require './fixtures'
flows = require 'streamline/lib/util/flows'
helpers = require './util/helpers'
neo4j = require '../'


## SHARED STATE

{DB, TEST_LABEL} = fixtures

[TEST_NODE_A, TEST_NODE_B, TEST_REL] = []


## HELPERS

# Calls the given asynchronous function with a placeholder callback, and
# immediately returns a "future" that can be called with a real callback.
# TODO: Achieve this with Streamline futures once we upgrade to 1.0.
# https://github.com/Sage/streamlinejs/issues/181#issuecomment-148926447
# Need this manual implementation for now, since `db.cypher` isn't Streamline.
defer = (fn) ->
    # Modeled off of Streamline's own futures implementation:
    # https://bjouhier.wordpress.com/2011/04/04/currying-the-callback-or-the-essence-of-futures/
    results = null

    cb = (_results...) ->
        results = _results

    fn (_results...) ->
        cb _results...

    return (_cb) ->
        if results
            _cb results...
        else
            cb = _cb

# Neo4j <2.2.6 used to keep transactions open on client and transient errors --
# even though transactions would always fail to commit later in those cases.
# Neo4j 2.2.6 fixed this, so transactions automatically roll back then.
# This helper accounts for this change by deriving the expected state after
# client and transient errors, based on the current Neo4j version.
# It also manually rolls the transaction back then, if Neo4j <2.2.6.
expectTxErrorRolledBack = (tx, _) ->
    fixtures.queryDbVersion _

    if fixtures.DB_VERSION_STR < '2.2.6'
        expect(tx.state).to.equal tx.STATE_OPEN
        tx.rollback _

    expect(tx.state).to.equal tx.STATE_ROLLED_BACK


## TESTS

describe 'Transactions', ->

    it 'should support simple queries', (_) ->
        tx = DB.beginTransaction()

        [{foo}] = tx.cypher 'RETURN "bar" AS foo', _

        expect(foo).to.equal 'bar'

    it 'should convey pending state, and reject concurrent requests', (done) ->
        tx = DB.beginTransaction()
        expect(tx.state).to.equal tx.STATE_OPEN

        fn = ->
            tx.cypher 'RETURN "bar" AS foo', cb
            expect(tx.state).to.equal tx.STATE_PENDING

        cb = (err, results) ->
            expect(err).to.not.exist()
            expect(tx.state).to.equal tx.STATE_OPEN
            done()

        fn()
        expect(fn).to.throw neo4j.ClientError, /concurrent requests/i

    it '(create test graph)', (_) ->
        [TEST_NODE_A, TEST_REL, TEST_NODE_B] =
            fixtures.createTestGraph module, 2, _

    it 'should isolate effects', (_) ->
        tx = DB.beginTransaction()

        # NOTE: It's important for us to create something new here, rather than
        # modify something existing. Otherwise, since we don't explicitly
        # rollback our open transaction at the end of this test, Neo4j sits and
        # waits for it to expire before returning other queries that touch the
        # existing graph -- including our last "delete test graph" step.
        # To that end, we test creating a new node here.

        {labels, properties} = fixtures.createTestNode module, _

        [{node}] = tx.cypher
            query: """
                CREATE (node:#{TEST_LABEL} {properties})
                RETURN node
            """
            params: {properties}
        , _

        expect(node).to.be.an.instanceOf neo4j.Node
        expect(node.properties).to.eql properties
        expect(node.labels).to.eql labels
        expect(node._id).to.be.a 'number'

        # Outside the transaction, we shouldn't see this newly created node:
        results = DB.cypher
            query: """
                MATCH (node:#{TEST_LABEL})
                WHERE #{(
                    # NOTE: Cypher doesn’t support directly comparing nodes and
                    # property bags, so we have to compare each property.
                    # HACK: CoffeeLint thinks the below is bad indentation.
                    # https://github.com/clutchski/coffeelint/issues/456
                    # coffeelint: disable=indentation
                    for prop of properties
                        "node.#{prop} = {properties}.#{prop}"
                    # coffeelint: enable=indentation
                    # HACK: CoffeeLint also thinks the below is double quotes!
                    # https://github.com/clutchski/coffeelint/issues/368
                    # coffeelint: disable=no_unnecessary_double_quotes
                ).join ' AND '}
                RETURN node
            """
            # coffeelint: enable=no_unnecessary_double_quotes
            params: {properties}
        , _

        expect(results).to.be.empty()

    it 'should support committing, and reject subsequent requests', (_) ->
        tx = DB.beginTransaction()

        [{nodeA}] = tx.cypher
            query: '''
                START nodeA = node({idA})
                SET nodeA.test = 'committing'
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'committing'

        expect(tx.state).to.equal tx.STATE_OPEN
        tx.commit _
        expect(tx.state).to.equal tx.STATE_COMMITTED

        expect(-> tx.cypher 'RETURN "bar" AS foo')
            .to.throw neo4j.ClientError, /been committed/i

        # Outside of the transaction, we should see this change now:
        [{nodeA}] = DB.cypher
            query: '''
                START nodeA = node({idA})
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'committing'

    it 'should support committing before any queries', (_) ->
        tx = DB.beginTransaction()
        expect(tx.state).to.equal tx.STATE_OPEN

        tx.commit _
        expect(tx.state).to.equal tx.STATE_COMMITTED

    it 'should support auto-committing', (_) ->
        tx = DB.beginTransaction()

        # Rather than test auto-committing on the first query, which doesn't
        # actually create a new transaction, auto-commit on the second.

        [{nodeA}] = tx.cypher
            query: '''
                START nodeA = node({idA})
                SET nodeA.test = 'auto-committing'
                SET nodeA.i = 1
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'auto-committing'
        expect(nodeA.properties.i).to.equal 1

        expect(tx.state).to.equal tx.STATE_OPEN

        [{nodeA}] = tx.cypher
            query: '''
                START nodeA = node({idA})
                SET nodeA.i = 2
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
            commit: true
        , _

        expect(nodeA.properties.test).to.equal 'auto-committing'
        expect(nodeA.properties.i).to.equal 2

        expect(tx.state).to.equal tx.STATE_COMMITTED

        expect(-> tx.cypher 'RETURN "bar" AS foo')
            .to.throw neo4j.ClientError, /been committed/i

        # Outside of the transaction, we should see this change now:
        [{nodeA}] = DB.cypher
            query: '''
                START nodeA = node({idA})
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'auto-committing'
        expect(nodeA.properties.i).to.equal 2

    it 'should support rolling back, and reject subsequent requests', (_) ->
        tx = DB.beginTransaction()

        [{nodeA}] = tx.cypher
            query: '''
                START a = node({idA})
                SET a.test = 'rolling back'
                RETURN a AS nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'rolling back'

        expect(tx.state).to.equal tx.STATE_OPEN
        tx.rollback _
        expect(tx.state).to.equal tx.STATE_ROLLED_BACK

        expect(-> tx.cypher 'RETURN "bar" AS foo')
            .to.throw neo4j.ClientError, /been rolled back/i

        # Back outside this transaction now, the change should *not* be visible:
        [{nodeA}] = DB.cypher
            query: '''
                START a = node({idA})
                RETURN a AS nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.not.equal 'rolling back'

    it 'should support rolling back before any queries', (_) ->
        tx = DB.beginTransaction()
        expect(tx.state).to.equal tx.STATE_OPEN

        tx.rollback _
        expect(tx.state).to.equal tx.STATE_ROLLED_BACK

    # NOTE: Skipping this test by default, because it's slow (we have to pause
    # one second; see note within) and not really a mission-critical feature.
    it.skip 'should support renewing (slow)', (_) ->
        tx = DB.beginTransaction()

        [{nodeA}] = tx.cypher
            query: '''
                START a = node({idA})
                SET a.test = 'renewing'
                RETURN a AS nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'renewing'

        expect(tx.expiresAt).to.be.an.instanceOf Date
        expect(tx.expiresAt).to.be.greaterThan new Date
        expect(tx.expiresIn).to.be.a 'number'
        expect(tx.expiresIn).to.be.greaterThan 0
        expect(tx.expiresIn).to.equal tx.expiresAt - new Date

        # NOTE: We can't easily test transactions actually expiring (that would
        # take too long, and there's no way for the client to shorten the time),
        # so we can't test that renewing actually *works* / has an effect.
        # We can only test that it *appears* to work / have an effect.
        #
        # NOTE: Neo4j's expiry appears to have a granularity of one second,
        # so to be robust (local requests are frequently faster than that),
        # we pause a second first.

        oldExpiresAt = tx.expiresAt
        setTimeout _, 1000      # TODO: Provide visual feedback?

        expect(tx.state).to.equal tx.STATE_OPEN
        tx.renew _
        expect(tx.state).to.equal tx.STATE_OPEN

        expect(tx.expiresAt).to.be.an.instanceOf Date
        expect(tx.expiresAt).to.be.greaterThan new Date
        expect(tx.expiresAt).to.be.greaterThan oldExpiresAt
        expect(tx.expiresIn).to.be.a 'number'
        expect(tx.expiresIn).to.be.greaterThan 0
        expect(tx.expiresIn).to.equal tx.expiresAt - new Date

        # To prevent Neo4j from hanging at the end waiting for this transaction
        # to commit or expire (since it touches the existing graph, and our last
        # step is to delete the existing graph), roll this transaction back.
        tx.rollback _
        expect(tx.state).to.equal tx.STATE_ROLLED_BACK

        # We also ensure that renewing didn't cause the transaction to commit.
        [{nodeA}] = DB.cypher
            query: '''
                START a = node({idA})
                RETURN a AS nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.not.equal 'renewing'

    it 'should properly handle (fatal) client errors', (_) ->
        tx = DB.beginTransaction()

        [{nodeA}] = tx.cypher
            query: '''
                START nodeA = node({idA})
                SET nodeA.test = 'client errors'
                SET nodeA.i = 1
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'client errors'
        expect(nodeA.properties.i).to.equal 1

        # Now trigger a client error by omitting a referenced parameter.
        # For precision, implementing this step without Streamline.
        do (cont=_) =>
            tx.cypher
                query: '''
                    START nodeA = node({idA})
                    SET nodeA.i = 2
                    RETURN {foo}
                '''
                params:
                    idA: TEST_NODE_A._id
            , (err, results) =>
                expect(err).to.exist()
                helpers.expectError err, 'ClientError', 'Statement',
                    'ParameterMissing', 'Expected a parameter named foo'
                cont()

        # All transaction errors, including client ones, are fatal, so the
        # transaction should be rolled back -- except in Neo4j <2.2.6.
        # See the documentation of `expectTxErrorRolledBack` for details:
        expectTxErrorRolledBack tx, _

        expect(-> tx.cypher 'RETURN "bar" AS foo')
            .to.throw neo4j.ClientError, /been rolled back/i

        # Back outside this transaction now, the change should *not* be visible:
        [{nodeA}] = DB.cypher
            query: '''
                START a = node({idA})
                RETURN a AS nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.not.equal 'client errors'

    # NOTE: Skipping this test by default, because it's slow (we have to pause
    # one second; see note within) and not crucial, unique test coverage.
    it.skip 'should properly handle (fatal) transient errors (slow)', (_) ->
        # The main transient error we can trigger is a DeadlockDetected error.
        # We can do this by having two separate transactions take locks on the
        # same two nodes, across two queries, but in opposite order.
        # (Taking a lock on a node just means writing to the node.)
        tx1 = DB.beginTransaction()
        tx2 = DB.beginTransaction()

        [[{nodeA}], [{nodeB}]] = flows.collect _, [
            defer tx1.cypher.bind tx1,
                query: '''
                    START nodeA = node({idA})
                    SET nodeA.test = 'transient errors'
                    SET nodeA.tx = 1
                    RETURN nodeA
                '''
                params:
                    idA: TEST_NODE_A._id

            defer tx2.cypher.bind tx2,
                query: '''
                    START nodeB = node({idB})
                    SET nodeB.test = 'transient errors'
                    SET nodeB.tx = 2
                    RETURN nodeB
                '''
                params:
                    idB: TEST_NODE_B._id
        ]

        expect(nodeA.properties.test).to.equal 'transient errors'
        expect(nodeA.properties.tx).to.equal 1
        expect(nodeB.properties.test).to.equal 'transient errors'
        expect(nodeB.properties.tx).to.equal 2

        # Now have each transaction attempt to lock the other's node.
        # This should trigger a DeadlockDetected error in one transaction.
        # It can also happen in the other, however, depending on timing.
        # HACK: To simplify this test, we thus add a pause, to reduce the
        # chance that both transactions will fail. This isn't bulletproof.

        # Kick off the first transaction's query asynchronously...
        future1 = defer tx1.cypher.bind tx1,
            query: '''
                START nodeB = node({idB})
                SET nodeB.tx = 1
                RETURN nodeB
            '''
            params:
                idB: TEST_NODE_B._id

        # Then pause for a bit...
        setTimeout _, 1000

        # Now make the second transaction's query (synchronously)...
        # which should fail right right away with a transient error.
        # For precision, implementing this step without Streamline.
        do (cont=_) ->
            tx2.cypher
                query: '''
                    START nodeA = node({idA})
                    SET nodeA.tx = 2
                    RETURN nodeA
                '''
                params:
                    idA: TEST_NODE_A._id
            , (err, results) ->
                expect(err).to.exist()
                # NOTE: Deadlock detected messages aren't predictable,
                # so having the assertion for it simply check itself:
                helpers.expectError err, 'TransientError', 'Transaction',
                    'DeadlockDetected', err.neo4j?.message or '???'
                cont()

        # All transaction errors, including transient ones, are fatal, so this
        # second transaction should be rolled back -- except in Neo4j <2.2.6.
        # See the documentation of `expectTxErrorRolledBack` for details:
        expectTxErrorRolledBack tx2, _

        # That should free up the first transaction to succeed, so wait for it:
        [{nodeB}] = future1 _

        # The second transaction's effects should *not* be visible within the
        # first transaction; only the first transaction's effects should be:
        expect(nodeB.properties.test).to.not.equal 'transient errors'
        expect(nodeB.properties.tx).to.equal 1

        # To prevent Neo4j from hanging at the end waiting for this transaction
        # to commit or expire (since it touches the existing graph, and our last
        # step is to delete the existing graph), roll this transaction back.
        expect(tx1.state).to.equal tx1.STATE_OPEN
        tx1.rollback _
        expect(tx1.state).to.equal tx1.STATE_ROLLED_BACK

    it 'should properly handle (fatal) database errors', (_) ->
        tx = DB.beginTransaction()

        # Important: don't auto-commit in the first query, because that doesn't
        # let us test that a transaction gets *returned* and *then* rolled back.
        [{nodeA}] = tx.cypher
            query: '''
                START nodeA = node({idA})
                SET nodeA.test = 'database errors'
                SET nodeA.i = 1
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'database errors'
        expect(nodeA.properties.i).to.equal 1

        # HACK: Depending on a known bug to trigger a DatabaseError;
        # that makes this test brittle, since the bug could get fixed!
        # https://github.com/neo4j/neo4j/issues/3870#issuecomment-76650113
        # For precision, implementing this step without Streamline.
        do (cont=_) =>
            tx.cypher
                query: 'CREATE (n {props})'
                params:
                    props: {foo: null}
            , (err, results) =>
                expect(err).to.exist()
                helpers.expectError err,
                    'DatabaseError', 'Statement', 'ExecutionFailure',
                    'scala.MatchError: (foo,null) (of class scala.Tuple2)'
                cont()

        expect(tx.state).to.equal tx.STATE_ROLLED_BACK

        expect(-> tx.cypher 'RETURN "bar" AS foo')
            .to.throw neo4j.ClientError, /been rolled back/i

        # The change should thus *not* be visible back outside the transaction:
        [{nodeA}] = DB.cypher
            query: '''
                START a = node({idA})
                RETURN a AS nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.not.equal 'database errors'

    it 'should properly handle (fatal) errors during commit', (_) ->
        tx = DB.beginTransaction()

        # Important: don't auto-commit in the first query, because that doesn't
        # let us test that a transaction gets *returned* and *then* rolled back.
        [{nodeA}] = tx.cypher
            query: '''
                START nodeA = node({idA})
                SET nodeA.test = 'errors during commit'
                SET nodeA.i = 1
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        , _

        expect(nodeA.properties.test).to.equal 'errors during commit'
        expect(nodeA.properties.i).to.equal 1

        # Now trigger a client error by omitting a referenced parameter.
        # For precision, implementing this step without Streamline.
        do (cont=_) =>
            tx.cypher
                query: '''
                    START nodeA = node({idA})
                    SET nodeA.i = 2
                    RETURN {foo}
                '''
                params:
                    idA: TEST_NODE_A._id
                commit: true
            , (err, results) =>
                expect(err).to.exist()
                helpers.expectError err, 'ClientError', 'Statement',
                    'ParameterMissing', 'Expected a parameter named foo'
                cont()

        # All transaction errors are fatal during commit, even in Neo4j <2.2.6:
        expect(tx.state).to.equal tx.STATE_ROLLED_BACK

    it 'should properly handle (fatal) errors on the first query', (_) ->
        tx = DB.beginTransaction()
        expect(tx.state).to.equal tx.STATE_OPEN

        # For precision, implementing this step without Streamline.
        do (cont=_) =>
            tx.cypher 'RETURN {foo}', (err, results) =>
                expect(err).to.exist()
                helpers.expectError err, 'ClientError', 'Statement',
                    'ParameterMissing', 'Expected a parameter named foo'
                cont()

        # All transaction errors, including on the first query, are fatal,
        # so the transaction should be rolled back -- except in Neo4j <2.2.6.
        # See the documentation of `expectTxErrorRolledBack` for details:
        expectTxErrorRolledBack tx, _

    it 'should properly handle (fatal) errors
            on an auto-commit first query', (_) ->
        tx = DB.beginTransaction()
        expect(tx.state).to.equal tx.STATE_OPEN

        # For precision, implementing this step without Streamline.
        do (cont=_) =>
            tx.cypher
                query: 'RETURN {foo}'
                commit: true
            , (err, results) =>
                expect(err).to.exist()
                helpers.expectError err, 'ClientError', 'Statement',
                    'ParameterMissing', 'Expected a parameter named foo'
                cont()

        # All transaction errors are fatal during commit, even in Neo4j <2.2.6,
        # and even on the first query:
        expect(tx.state).to.equal tx.STATE_ROLLED_BACK

    it 'should properly handle (fatal) errors with batching', (_) ->
        tx = DB.beginTransaction()

        results = tx.cypher [
            query: '''
                START nodeA = node({idA})
                SET nodeA.test = 'errors with batching'
            '''
            params:
                idA: TEST_NODE_A._id
        ,
            query: '''
                START nodeA = node({idA})
                SET nodeA.i = 1
                RETURN nodeA
            '''
            params:
                idA: TEST_NODE_A._id
        ], _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 2

        for result in results
            expect(result).to.be.an 'array'

        expect(results[0]).to.be.empty()
        expect(results[1]).to.have.length 1

        [{nodeA}] = results[1]

        expect(nodeA.properties.test).to.equal 'errors with batching'
        expect(nodeA.properties.i).to.equal 1

        expect(tx.state).to.equal tx.STATE_OPEN

        # Now trigger a client error by omitting a referenced parameter.
        # For precision, implementing this step without Streamline.
        do (cont=_) =>
            tx.cypher
                queries: [
                    query: '''
                        START nodeA = node({idA})
                        SET nodeA.i = 2
                        RETURN nodeA
                    '''
                    params:
                        idA: TEST_NODE_A._id
                    lean: true
                ,
                    '(syntax error)'
                ,
                    query: '''
                        START nodeA = node({idA})
                        SET nodeA.i = 3
                        RETURN nodeA
                    '''
                    params:
                        idA: TEST_NODE_A._id
                ]
            , (err, results) =>
                expect(err).to.exist()

                # Simplified error checking, since the message is complex:
                expect(err).to.be.an.instanceOf neo4j.ClientError
                expect(err.neo4j).to.be.an 'object'
                expect(err.neo4j.code).to.equal \
                    'Neo.ClientError.Statement.InvalidSyntax'

                expect(results).to.be.an 'array'
                expect(results).to.have.length 1

                [result] = results

                expect(result).to.be.an 'array'
                expect(result).to.have.length 1

                [{nodeA}] = result

                # We requested `lean: true`, so `nodeA` is just properties:
                expect(nodeA.test).to.equal 'errors with batching'
                expect(nodeA.i).to.equal 2

                cont()

        # All transaction errors, including client ones in a batch, are fatal,
        # so the transaction should be rolled back -- except in Neo4j <2.2.6.
        # See the documentation of `expectTxErrorRolledBack` for details:
        expectTxErrorRolledBack tx, _

    it 'should support streaming (TODO)'

    it '(delete test graph)', (_) ->
        fixtures.deleteTestGraph module, _
