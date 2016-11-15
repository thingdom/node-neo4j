#
# Tests for indexing, e.g. creating, retrieivng, and dropping indexes.
# In the process, also tests that indexing actually has an effect.
#

{expect} = require 'chai'
fixtures = require './fixtures'
helpers = require './util/helpers'
neo4j = require '../'


## SHARED STATE

{DB, TEST_LABEL} = fixtures

[TEST_NODE_A, TEST_REL, TEST_NODE_B] = []

# Important: we generate a random property to guarantee no index exists yet.
TEST_PROP = "index_#{helpers.getRandomStr()}"
TEST_VALUE = 'test'

# These are the indexes that exist before this test suite runs...
ORIG_INDEXES_ALL = null     # ...Across all labels
ORIG_INDEXES_LABEL = null   # ...On our TEST_LABEL

# And this is the index we create:
TEST_INDEX = null

# Cypher query + params to test our index:
TEST_CYPHER =
    query: """
        MATCH (n:#{TEST_LABEL})
        USING INDEX n:#{TEST_LABEL}(#{TEST_PROP})
        WHERE n.#{TEST_PROP} = {value}
        RETURN n
        ORDER BY ID(n)
    """
    params:
        value: TEST_VALUE


## HELPERS

expectIndex = (index, label, property) ->
    expect(index).to.be.an.instanceOf neo4j.Index
    expect(index.label).to.equal label if label
    expect(index.property).to.equal property if property

expectIndexes = (indexes, label) ->
    expect(indexes).to.be.an 'array'
    for index in indexes
        expectIndex index, label


## TESTS

describe 'Indexes', ->

    # IMPORTANT: Mocha requires all test steps to be at the same nesting level
    # for them to all execute in order. Hence "setup" and "teardown" wrappers.

    describe '(setup)', ->

        it '(create test nodes)', (_) ->
            [TEST_NODE_A, TEST_REL, TEST_NODE_B] =
                fixtures.createTestGraph module, 2, _

        it '(set test properties)', (_) ->
            DB.cypher
                query: """
                    START n = node({ids})
                    SET n.#{TEST_PROP} = {value}
                """
                params:
                    ids: [TEST_NODE_A._id, TEST_NODE_B._id]
                    value: TEST_VALUE
            , _

            # Update our local instances too:
            TEST_NODE_A.properties[TEST_PROP] = TEST_VALUE
            TEST_NODE_B.properties[TEST_PROP] = TEST_VALUE

        # HACK: Only needed because a test that uses it below isn't Streamline.
        it '(query db version)', (_) ->
            fixtures.queryDbVersion _


    describe '(before index created)', ->

        it 'should support listing all indexes', (_) ->
            indexes = DB.getIndexes _
            expectIndexes indexes

            ORIG_INDEXES_ALL = indexes

        it 'should support listing indexes for a particular label', (_) ->
            indexes = DB.getIndexes TEST_LABEL, _
            expectIndexes indexes, TEST_LABEL

            ORIG_INDEXES_LABEL = indexes

        it 'should support querying for specific index', (_) ->
            exists = DB.hasIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(exists).to.equal false

        it '(verify index doesn’t exist yet)', (done) ->
            DB.cypher TEST_CYPHER, (err, results) ->
                # NOTE: Our test Cypher uses `USING INDEX` to test index usage,
                # but Neo4j 2.3+ no longer errors by default on invalid hints:
                # http://neo4j.com/docs/stable/configuration-settings.html#config_dbms.cypher.hints.error
                # So we explicitly guard against that, and just continue then.
                # TODO: Would be nice to test the index another way...
                try
                    expect(err).to.exist
                    expect(results).to.not.exist
                catch assertionErr
                    # HACK: Because this test isn't a Streamline function,
                    # relying on `fixtures.queryDbVersion` having been called
                    # already, as part of the suite's setup.
                    if fixtures.DB_VERSION_NUM >= 2.3
                        return done()
                    else
                        throw assertionErr

                # NOTE: At some point, Neo4j regressed and improperly returned
                # DatabaseError for this case, rather than ClientError.
                # https://github.com/neo4j/neo4j/issues/5902
                expMessage = """
                    No such index found.
                    Label: `#{TEST_LABEL}`
                    Property name: `#{TEST_PROP}`
                """
                try
                    helpers.expectError err,
                        'ClientError', 'Schema', 'NoSuchIndex', expMessage
                catch assertionErr
                    # Check for the regression case, but if this fails,
                    # throw the original assertion error, not this one.
                    #
                    # HACK: The newlines in the error message are atypical,
                    # and too hard to work with (since our friendly error code
                    # indents multi-line messages and stack traces),
                    # so we hard-code simplified assertions here.
                    #
                    try
                        expect(err).to.be.an.instanceOf neo4j.DatabaseError
                        expect(err.neo4j?.code).to.equal \
                            'Neo.DatabaseError.Statement.ExecutionFailure'
                        expect(err.neo4j?.message).to.equal expMessage
                    catch doubleErr
                        throw assertionErr

                done()

        it 'should support creating index', (_) ->
            index = DB.createIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expectIndex index, TEST_LABEL, TEST_PROP

            TEST_INDEX = index


    describe '(after index created)', ->

        it '(verify by re-listing all indexes)', (_) ->
            indexes = DB.getIndexes _
            expect(indexes).to.have.length ORIG_INDEXES_ALL.length + 1
            expect(indexes).to.contain TEST_INDEX

        it '(verify by re-listing indexes for test label)', (_) ->
            indexes = DB.getIndexes TEST_LABEL, _
            expect(indexes).to.have.length ORIG_INDEXES_LABEL.length + 1
            expect(indexes).to.contain TEST_INDEX

        it '(verify by re-querying specific test index)', (_) ->
            exists = DB.hasIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(exists).to.equal true

        # TODO: This sometimes fails because the index hasn't come online yet,
        # but Neo4j's REST API doesn't return index online/offline status.
        # We may need to change this to retry/poll for some time.
        it.skip '(verify with test query)', (_) ->
            results = DB.cypher TEST_CYPHER, _

            expect(results).to.eql [
                n: TEST_NODE_A
            ,
                n: TEST_NODE_B
            ]

        it 'should be idempotent on repeat creates of index', (_) ->
            index = DB.createIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(index).to.not.exist

        it 'should support dropping index', (_) ->
            dropped = DB.dropIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(dropped).to.equal true


    describe '(after index dropped)', ->

        it '(verify by re-listing all indexes)', (_) ->
            indexes = DB.getIndexes _
            expect(indexes).to.eql ORIG_INDEXES_ALL

        it '(verify by re-listing indexes for test label)', (_) ->
            indexes = DB.getIndexes TEST_LABEL, _
            expect(indexes).to.eql ORIG_INDEXES_LABEL

        it '(verify by re-querying specific test index)', (_) ->
            exists = DB.hasIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(exists).to.equal false

        it 'should be idempotent on repeat drops of constraint', (_) ->
            dropped = DB.dropIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(dropped).to.equal false


    describe '(misc)', ->

        fail = -> throw new Error 'Callback should not have been called'

        it 'should require both label and property to query specific index', ->
            for fn in [
                -> DB.hasIndex null, fail
                -> DB.hasIndex '', fail
                -> DB.hasIndex {}, fail
                -> DB.hasIndex TEST_LABEL, fail
                -> DB.hasIndex {label: TEST_LABEL}, fail
                -> DB.hasIndex {property: TEST_PROP}, fail
            ]
                expect(fn).to.throw TypeError, /label and property required/i

        it 'should require both label and property to create index', ->
            for fn in [
                -> DB.createIndex null, fail
                -> DB.createIndex '', fail
                -> DB.createIndex {}, fail
                -> DB.createIndex TEST_LABEL, fail
                -> DB.createIndex {label: TEST_LABEL}, fail
                -> DB.createIndex {property: TEST_PROP}, fail
            ]
                expect(fn).to.throw TypeError, /label and property required/i

        it 'should require both label and property to drop index', ->
            for fn in [
                -> DB.dropIndex null, fail
                -> DB.dropIndex '', fail
                -> DB.dropIndex {}, fail
                -> DB.dropIndex TEST_LABEL, fail
                -> DB.dropIndex {label: TEST_LABEL}, fail
                -> DB.dropIndex {property: TEST_PROP}, fail
            ]
                expect(fn).to.throw TypeError, /label and property required/i


    describe '(teardown)', ->

        it '(delete test nodes)', (_) ->
            fixtures.deleteTestGraph module, _
