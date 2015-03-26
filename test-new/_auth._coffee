#
# Tests for basic auth management, e.g. the ability to change user passwords.
#
# IMPORTANT: Against a fresh Neo4j 2.2 database (which requires both auth and
# an initial password change by default), this test must be the first to run,
# in order for other tests not to fail. Hence the underscore-prefixed filename.
# (The original password is restored at the end of this suite.)
#
# NOTE: Since auth (a) can be disabled, and (b) isn't supported by Neo4j <2.2,
# this suite first checks if auth is enabled, and *only* runs if it is.
# If auth is disabled or not present, every test here will be skipped.
#

$ = require 'underscore'
{expect} = require 'chai'
fixtures = require './fixtures'
helpers = require './util/helpers'
neo4j = require '../'


## SHARED STATE

{DB} = fixtures

ORIGINAL_PASSWORD = DB.auth?.password
RANDOM_PASSWORD = helpers.getRandomStr()

SUITE = null


## HELPERS

disable = (reason) ->
    console.warn "#{reason}; not running auth tests."

    # HACK: Perhaps relying on Mocha's internals to achieve skip all:
    for test, i in SUITE.tests
        continue if i is 0  # This is our "check" test
        test.pending = true

    # TODO: It'd be nice if we could support bailing on *all* suites,
    # in case of an auth error, e.g. bad credentials.


## TESTS

describe 'Auth', ->

    SUITE = @

    it '(check if auth is enabled)', (_) ->
        if not ORIGINAL_PASSWORD
            return disable 'Auth creds unspecified'

        # Querying user status (what this check method does) fails both when
        # auth is unavailable (Neo4j 2.1-) and when it's disabled (Neo4j 2.2+).
        try
            DB.checkPasswordChangeNeeded _
        catch err
            if err instanceof neo4j.ClientError and err.message.match /^404 /
                disable 'Auth disabled or unavailable'
            else
                disable 'Error checking auth'
                throw err

    it 'should fail when auth is required but not set', (done) ->
        db = new neo4j.GraphDatabase
            url: DB.url
            auth: {}    # Explicitly clears auth

        # NOTE: Explicitly not using `db.checkPasswordChangeNeeded` since that
        # rejects calls when no auth is set.
        db.http '/db/data/', (err, data) ->
            expect(err).to.exist()
            helpers.expectError err, 'ClientError', 'Security',
                'AuthorizationFailed', 'No authorization header supplied.'
            expect(data).to.not.exist()
            done()

    it 'should fail when auth is incorrect (username)', (done) ->
        db = new neo4j.GraphDatabase
            url: DB.url
            auth: $(DB.auth).clone()

        db.auth.username = RANDOM_PASSWORD

        db.checkPasswordChangeNeeded (err, bool) ->
            expect(err).to.exist()
            helpers.expectError err, 'ClientError', 'Security',
                'AuthorizationFailed', 'Invalid username or password.'
            expect(bool).to.not.exist()
            done()

    it 'should fail when auth is incorrect (password)', (done) ->
        db = new neo4j.GraphDatabase
            url: DB.url
            auth: $(DB.auth).clone()

        db.auth.password = RANDOM_PASSWORD

        db.checkPasswordChangeNeeded (err, bool) ->
            expect(err).to.exist()
            helpers.expectError err, 'ClientError', 'Security',
                'AuthorizationFailed', 'Invalid username or password.'
            expect(bool).to.not.exist()
            done()

    it 'should support checking whether a password change is needed', (_) ->
        needed = DB.checkPasswordChangeNeeded _
        expect(needed).to.be.a 'boolean'

    it 'should support changing the current user’s password', (_) ->
        DB.changePassword RANDOM_PASSWORD, _

    it 'should reject empty and null new passwords', ->
        cb = -> throw new Error 'Callback shouldn’t have been called!'

        for fn in [
            -> DB.changePassword null, cb
            -> DB.changePassword '', cb
            -> DB.changePassword {}, cb
            -> DB.changePassword {password: null}, cb
            -> DB.changePassword {password: ''}, cb
        ]
            expect(fn).to.throw TypeError, /Password required/

    it 'should automatically update state on password changes', (_) ->
        expect(DB.auth.password).to.equal RANDOM_PASSWORD

        # Verify with another password change needed check:
        needed = DB.checkPasswordChangeNeeded _
        expect(needed).to.equal false

    it '(change password back)', (_) ->
        DB.changePassword ORIGINAL_PASSWORD, _
        expect(DB.auth.password).to.equal ORIGINAL_PASSWORD
