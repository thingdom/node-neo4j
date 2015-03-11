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
            bool = DB.hasIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(bool).to.equal false

        it '(verify index doesn’t exist yet)', (done) ->
            DB.cypher TEST_CYPHER, (err, results) ->
                expect(err).to.exist()
                expect(results).to.not.exist()

                helpers.expectError err,
                    'ClientError', 'Schema', 'NoSuchIndex', """
                        No such index found.
                        Label: `#{TEST_LABEL}`
                        Property name: `#{TEST_PROP}`
                    """

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
            bool = DB.hasIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(bool).to.equal true

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

        it 'should throw on create of already-created index', (done) ->
            DB.createIndex
                label: TEST_LABEL
                property: TEST_PROP
            , (err, index) ->
                expMessage = "There already exists an index
                    for label '#{TEST_LABEL}' on property '#{TEST_PROP}'."

                # Neo4j 2.2 returns a proper new-style error object for this
                # case, but previous versions return an old-style error.
                try
                    helpers.expectError err, 'ClientError', 'Schema',
                        'IndexAlreadyExists', expMessage
                catch assertionErr
                    # Check for the older case, but in case it fails,
                    # throw the original assertion error, not a new one.
                    try
                        helpers.expectOldError err, 409,
                            'ConstraintViolationException',
                            'org.neo4j.graphdb.ConstraintViolationException',
                            expMessage
                    catch doubleErr
                        throw assertionErr

                expect(index).to.not.exist()
                done()

        it 'should support dropping index', (_) ->
            DB.dropIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _


    describe '(after index dropped)', ->

        it '(verify by re-listing all indexes)', (_) ->
            indexes = DB.getIndexes _
            expect(indexes).to.eql ORIG_INDEXES_ALL

        it '(verify by re-listing indexes for test label)', (_) ->
            indexes = DB.getIndexes TEST_LABEL, _
            expect(indexes).to.eql ORIG_INDEXES_LABEL

        it '(verify by re-querying specific test index)', (_) ->
            bool = DB.hasIndex
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(bool).to.equal false

        it 'should throw on drop of already-dropped index', (done) ->
            DB.dropIndex
                label: TEST_LABEL
                property: TEST_PROP
            , (err) ->
                helpers.expectHttpError err, 404
                done()


    describe '(misc)', ->

        it 'should require both label and property to query specific index', ->
            for fn in [
                -> DB.hasIndex null, ->
                -> DB.hasIndex '', ->
                -> DB.hasIndex {}, ->
                -> DB.hasIndex TEST_LABEL, ->
                -> DB.hasIndex {label: TEST_LABEL}, ->
                -> DB.hasIndex {property: TEST_PROP}, ->
            ]
                expect(fn).to.throw TypeError, /label and property required/i

        it 'should require both label and property to create index', ->
            for fn in [
                -> DB.createIndex null, ->
                -> DB.createIndex '', ->
                -> DB.createIndex {}, ->
                -> DB.createIndex TEST_LABEL, ->
                -> DB.createIndex {label: TEST_LABEL}, ->
                -> DB.createIndex {property: TEST_PROP}, ->
            ]
                expect(fn).to.throw TypeError, /label and property required/i

        it 'should require both label and property to drop index', ->
            for fn in [
                -> DB.dropIndex null, ->
                -> DB.dropIndex '', ->
                -> DB.dropIndex {}, ->
                -> DB.dropIndex TEST_LABEL, ->
                -> DB.dropIndex {label: TEST_LABEL}, ->
                -> DB.dropIndex {property: TEST_PROP}, ->
            ]
                expect(fn).to.throw TypeError, /label and property required/i


    describe '(teardown)', ->

        it '(delete test nodes)', (_) ->
            fixtures.deleteTestGraph module, _
