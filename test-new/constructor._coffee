#
# Tests for the GraphDatabase constructor, e.g. its options and overloads.
#

$ = require 'underscore'
{expect} = require 'chai'
{GraphDatabase} = require '../'


## CONSTANTS

URL = 'http://foo:bar@baz:1234'
PROXY = 'http://lorem.ipsum'
HEADERS =
    'x-foo': 'bar-baz'
    'x-lorem': 'ipsum'
    # TODO: Test overlap with default headers?
    # TODO: Test custom User-Agent behavior, or blacklist X-Stream?


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


## TESTS

describe 'GraphDatabase::constructor', ->

    it 'should support full options', ->
        db = new GraphDatabase
            url: URL
            proxy: PROXY
            headers: HEADERS

        expectDatabase db, URL, PROXY
        expectHeaders db, HEADERS

    it 'should support just URL string', ->
        db = new GraphDatabase URL

        expectDatabase db, URL
        expectHeaders db, {}

    it 'should throw if no URL given', ->
        fn = -> new GraphDatabase()
        expect(fn).to.throw TypeError

        # Also try giving an options argument, just with no URL:
        fn = -> new GraphDatabase {proxy: PROXY}
        expect(fn).to.throw TypeError
