#
# Tests for constraints, e.g. creating, retrieivng, and dropping constraints.
# In the process, also tests that constraints actually have an effect.
#

{expect} = require 'chai'
fixtures = require './fixtures'
helpers = require './util/helpers'
neo4j = require '../'


## SHARED STATE

{DB, TEST_LABEL} = fixtures

[TEST_NODE_A, TEST_REL, TEST_NODE_B] = []

# Important: we generate a random prop to guarantee no same constraint yet.
# We set the value to the node's ID, to ensure uniqueness.
TEST_PROP = "constraint_#{helpers.getRandomStr()}"

# These are the constraints that exist before this test suite runs...
ORIG_CONSTRAINTS_ALL = null     # ...Across all labels
ORIG_CONSTRAINTS_LABEL = null   # ...On our TEST_LABEL

# And this is the constraint we create:
TEST_CONSTRAINT = null


## HELPERS

expectConstraint = (constraint, label, property) ->
    expect(constraint).to.be.an.instanceOf neo4j.Constraint
    expect(constraint.label).to.equal label if label
    expect(constraint.property).to.equal property if property

expectConstraints = (constraints, label) ->
    expect(constraints).to.be.an 'array'
    for constraint in constraints
        expectConstraint constraint, label

violateConstraint = (_) ->
    # Do this in a transaction, so that we don't actually persist:
    tx = DB.beginTransaction()

    try
        tx.cypher
            query: """
                START n = node({idB})
                SET n.#{TEST_PROP} = {idA}
            """
            params:
                idA: TEST_NODE_A._id
                idB: TEST_NODE_B._id
        , _

    # Not technically needed, but prevent Neo4j from waiting up to a minute for
    # the transaction to expire in case of any errors:
    finally
        tx.rollback _


## TESTS

describe 'Constraints', ->

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
                    SET n.#{TEST_PROP} = ID(n)
                """
                params:
                    ids: [TEST_NODE_A._id, TEST_NODE_B._id]
            , _

            # Update our local instances too:
            TEST_NODE_A.properties[TEST_PROP] = TEST_NODE_A._id
            TEST_NODE_B.properties[TEST_PROP] = TEST_NODE_B._id


    describe '(before constraint created)', ->

        it 'should support listing all constraints', (_) ->
            constraints = DB.getConstraints _
            expectConstraints constraints

            ORIG_CONSTRAINTS_ALL = constraints

        it 'should support listing constraints for a particular label', (_) ->
            constraints = DB.getConstraints TEST_LABEL, _
            expectConstraints constraints, TEST_LABEL

            ORIG_CONSTRAINTS_LABEL = constraints

        it 'should support querying for specific constraint', (_) ->
            bool = DB.hasConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(bool).to.equal false

        it '(verify constraint doesn’t exist yet)', (_) ->
            # This shouldn't throw an error:
            violateConstraint _

        it 'should support creating constraint', (_) ->
            constraint = DB.createConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expectConstraint constraint, TEST_LABEL, TEST_PROP

            TEST_CONSTRAINT = constraint


    describe '(after constraint created)', ->

        it '(verify by re-listing all constraints)', (_) ->
            constraints = DB.getConstraints _
            expect(constraints).to.have.length ORIG_CONSTRAINTS_ALL.length + 1
            expect(constraints).to.contain TEST_CONSTRAINT

        it '(verify by re-listing constraints for test label)', (_) ->
            constraints = DB.getConstraints TEST_LABEL, _
            expect(constraints).to.have.length ORIG_CONSTRAINTS_LABEL.length + 1
            expect(constraints).to.contain TEST_CONSTRAINT

        it '(verify by re-querying specific test constraint)', (_) ->
            bool = DB.hasConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(bool).to.equal true

        it '(verify with test query)', (done) ->
            violateConstraint (err) ->
                expect(err).to.exist()

                helpers.expectError err,
                    'ClientError', 'Schema', 'ConstraintViolation',
                    "Node #{TEST_NODE_A._id} already exists
                        with label #{TEST_LABEL}
                        and property \"#{TEST_PROP}\"=[#{TEST_NODE_A._id}]"

                done()

        it 'should throw on create of already-created constraint', (done) ->
            DB.createConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , (err, constraint) ->
                expMessage = "Label '#{TEST_LABEL}' and property '#{TEST_PROP}'
                    already have a unique constraint defined on them."

                # Neo4j 2.2 returns a proper new-style error object for this
                # case, but previous versions return an old-style error.
                try
                    helpers.expectError err, 'ClientError', 'Schema',
                        'ConstraintAlreadyExists', expMessage
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

                expect(constraint).to.not.exist()
                done()

        it 'should support dropping constraint', (_) ->
            DB.dropConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , _


    describe '(after constraint dropped)', ->

        it '(verify by re-listing all constraints)', (_) ->
            constraints = DB.getConstraints _
            expect(constraints).to.eql ORIG_CONSTRAINTS_ALL

        it '(verify by re-listing constraints for test label)', (_) ->
            constraints = DB.getConstraints TEST_LABEL, _
            expect(constraints).to.eql ORIG_CONSTRAINTS_LABEL

        it '(verify by re-querying specific test constraint)', (_) ->
            bool = DB.hasConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , _

            expect(bool).to.equal false

        it 'should throw on drop of already-dropped constraint', (done) ->
            DB.dropConstraint
                label: TEST_LABEL
                property: TEST_PROP
            , (err) ->
                helpers.expectHttpError err, 404
                done()


    describe '(misc)', ->

        it 'should require both label and property to query specific constraint', ->
            for fn in [
                -> DB.hasConstraint null, ->
                -> DB.hasConstraint '', ->
                -> DB.hasConstraint {}, ->
                -> DB.hasConstraint TEST_LABEL, ->
                -> DB.hasConstraint {label: TEST_LABEL}, ->
                -> DB.hasConstraint {property: TEST_PROP}, ->
            ]
                expect(fn).to.throw TypeError, /label and property required/i

        it 'should require both label and property to create constraint', ->
            for fn in [
                -> DB.createConstraint null, ->
                -> DB.createConstraint '', ->
                -> DB.createConstraint {}, ->
                -> DB.createConstraint TEST_LABEL, ->
                -> DB.createConstraint {label: TEST_LABEL}, ->
                -> DB.createConstraint {property: TEST_PROP}, ->
            ]
                expect(fn).to.throw TypeError, /label and property required/i

        it 'should require both label and property to drop constraint', ->
            for fn in [
                -> DB.dropConstraint null, ->
                -> DB.dropConstraint '', ->
                -> DB.dropConstraint {}, ->
                -> DB.dropConstraint TEST_LABEL, ->
                -> DB.dropConstraint {label: TEST_LABEL}, ->
                -> DB.dropConstraint {property: TEST_PROP}, ->
            ]
                expect(fn).to.throw TypeError, /label and property required/i


    describe '(teardown)', ->

        it '(delete test nodes)', (_) ->
            fixtures.deleteTestGraph module, _
