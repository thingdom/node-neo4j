#
# Tests for basic schema management, e.g. retrieving labels, property keys, and
# relationship types. This does *not* cover indexes and constraints.
#

{expect} = require 'chai'
fixtures = require './fixtures'
neo4j = require '../'


## SHARED STATE

{DB, TEST_LABEL, TEST_REL_TYPE} = fixtures

[TEST_NODE_A, TEST_NODE_B, TEST_REL] = []


## TESTS

describe 'Schema', ->

    it '(create test graph)', (_) ->
        [TEST_NODE_A, TEST_REL, TEST_NODE_B] =
            fixtures.createTestGraph module, 2, _

    it 'should support listing all labels', (_) ->
        labels = DB.getLabels _

        expect(labels).to.be.an 'array'
        expect(labels).to.not.be.empty()
        expect(labels).to.contain TEST_LABEL

    it 'should support listing all property keys', (_) ->
        keys = DB.getPropertyKeys _

        expect(keys).to.be.an 'array'
        expect(keys).to.not.be.empty()

        for key of TEST_NODE_A.properties
            expect(keys).to.contain key

    it 'should support listing all relationship types', (_) ->
        types = DB.getRelationshipTypes _

        expect(types).to.be.an 'array'
        expect(types).to.not.be.empty()
        expect(types).to.contain TEST_REL_TYPE

    it '(delete test graph)', (_) ->
        fixtures.deleteTestGraph module, _
