#
# Tests for the GraphDatabase constructor, e.g. its options and overloads.
#

$ = require 'underscore'
{expect} = require 'chai'
{GraphDatabase} = require '../'
helpers = require './util/helpers'


## CONSTANTS

URL = 'https://example.com:1234'
PROXY = 'https://some.proxy:5678'
HEADERS =
    'x-foo': 'bar-baz'
    'x-lorem': 'ipsum'
    # TODO: Test overlap with default headers?
    # TODO: Test custom User-Agent behavior, or blacklist X-Stream?

USERNAME = 'alice'
PASSWORD = 'p4ssw0rd'


## HELPERS

#
# Asserts that the given object is an instance of GraphDatabase,
# pointing to the given URL, optionally using the given proxy URL.
#
expectDatabase = (db, url, proxy) ->
    expect(db).to.be.an.instanceOf GraphDatabase
    expect(db.url).to.equal url
    expect(db.proxy).to.equal proxy

#
# Asserts that the given GraphDatabase instance has its `headers` property set
# to the union of the given headers and the default GraphDatabase `headers`,
# with the given headers taking precedence.
#
# TODO: If we special-case User-Agent or blacklist X-Stream, update here.
#
expectHeaders = (db, headers) ->
    expect(db.headers).to.be.an 'object'

    defaultHeaders = GraphDatabase::headers
    defaultKeys = Object.keys defaultHeaders
    givenKeys = Object.keys headers
    expectedKeys = $.union defaultKeys, givenKeys   # This de-dupes too.

    # This is an exact check, i.e. *only* these keys:
    expect(db.headers).to.have.keys expectedKeys

    for key, val of db.headers
        expect(val).to.equal headers[key] or defaultHeaders[key]

expectAuth = (db, username, password) ->
    expect(db.auth).to.eql {username, password}

expectNoAuth = (db) ->
    expect(db.auth).to.not.exist()


## TESTS

describe 'GraphDatabase::constructor', ->

    it 'should support full options', ->
        db = new GraphDatabase
            url: URL
            proxy: PROXY
            headers: HEADERS

        expectDatabase db, URL, PROXY
        expectHeaders db, HEADERS
        expectNoAuth db

    it 'should support just URL string', ->
        db = new GraphDatabase URL

        expectDatabase db, URL
        expectHeaders db, {}
        expectNoAuth db

    it 'should throw if no URL given', ->
        fn = -> new GraphDatabase()
        expect(fn).to.throw TypeError, /URL to Neo4j required/

        # Also try giving an options argument, just with no URL:
        fn = -> new GraphDatabase {proxy: PROXY}
        expect(fn).to.throw TypeError, /URL to Neo4j required/

    it 'should support and parse auth in URL', ->
        url = "https://#{USERNAME}:#{PASSWORD}@auth.test:9876"
        db = new GraphDatabase url

        expectDatabase db, url
        expectAuth db, USERNAME, PASSWORD

    it 'should support and parse auth as separate string option', ->
        db = new GraphDatabase
            url: URL
            auth: "#{USERNAME}:#{PASSWORD}"

        expectDatabase db, URL
        expectAuth db, USERNAME, PASSWORD

    it 'should support and parse auth as separate object option', ->
        db = new GraphDatabase
            url: URL
            auth:
                username: USERNAME
                password: PASSWORD

        expectDatabase db, URL
        expectAuth db, USERNAME, PASSWORD

    it 'should prefer separate auth option over auth in the URL
            (and should clear auth in URL then)', ->
        host = 'auth.test:9876'
        wrong1 = helpers.getRandomStr()
        wrong2 = helpers.getRandomStr()

        db = new GraphDatabase
            url: "https://#{wrong1}:#{wrong2}@#{host}"
            auth: "#{USERNAME}:#{PASSWORD}"

        # NOTE: The constructor adds a trailing slash, but that's okay.
        expectDatabase db, "https://#{host}/"
        expectAuth db, USERNAME, PASSWORD

    it 'should support clearing auth via empty string option', ->
        host = 'auth.test:9876'
        url = "https://#{USERNAME}:#{PASSWORD}@#{host}"

        db = new GraphDatabase
            url: url
            auth: ''

        # NOTE: The constructor adds a trailing slash, but that's okay.
        expectDatabase db, "https://#{host}/"
        expectNoAuth db

    it 'should support clearing auth via empty object option', ->
        host = 'auth.test:9876'
        url = "https://#{USERNAME}:#{PASSWORD}@#{host}"

        db = new GraphDatabase
            url: url
            auth: {}

        # NOTE: The constructor adds a trailing slash, but that's okay.
        expectDatabase db, "https://#{host}/"
        expectNoAuth db

    it 'should be robust to colons in the password with string option', ->
        password = "#{PASSWORD}:#{PASSWORD}:#{PASSWORD}"

        db = new GraphDatabase
            url: URL
            auth: "#{USERNAME}:#{password}"

        expectDatabase db, URL
        expectAuth db, USERNAME, password
