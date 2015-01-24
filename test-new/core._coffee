$ = require 'underscore'
{expect} = require 'chai'
http = require 'http'
neo4j = require '../'


# SHARED STATE

DB = null
URL = process.env.NEO4J_URL or 'http://localhost:7474'

FAKE_PROXY = 'http://lorem.ipsum'
FAKE_HEADERS =
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
    expect(db).to.be.an.instanceOf neo4j.GraphDatabase
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

    defaultHeaders = neo4j.GraphDatabase::headers
    defaultKeys = Object.keys defaultHeaders
    givenKeys = Object.keys headers
    expectedKeys = $.union defaultKeys, givenKeys   # This de-dupes too.

    # This is an exact check, i.e. *only* these keys:
    expect(db.headers).to.have.keys expectedKeys

    for key, val of db.headers
        expect(val).to.equal headers[key] or defaultHeaders[key]

expectResponse = (resp, statusCode) ->
    expect(resp).to.be.an.instanceOf http.IncomingMessage
    expect(resp.statusCode).to.equal statusCode
    expect(resp.headers).to.be.an 'object'

expectNeo4jRoot = (body) ->
    expect(body).to.be.an 'object'
    expect(body).to.have.keys 'data', 'management'


## TESTS

describe 'GraphDatabase::constructor', ->

    it 'should support full options', ->
        DB = new neo4j.GraphDatabase
            url: URL
            proxy: FAKE_PROXY
            headers: FAKE_HEADERS

        expectDatabase DB, URL, FAKE_PROXY
        expectHeaders DB, FAKE_HEADERS

    it 'should support just URL string', ->
        DB = new neo4j.GraphDatabase URL

        expectDatabase DB, URL
        expectHeaders DB, {}

    it 'should throw if no URL given', ->
        fn = -> new neo4j.GraphDatabase()
        expect(fn).to.throw TypeError

        # Also try giving an options argument, just with no URL:
        fn = -> new neo4j.GraphDatabase {proxy: FAKE_PROXY}
        expect(fn).to.throw TypeError

describe 'GraphDatabase::http', ->

    it 'should support simple GET requests by default', (_) ->
        body = DB.http '/', _
        expectNeo4jRoot body

    it 'should support complex requests with options', (_) ->
        body = DB.http
            method: 'GET'
            path: '/'
            headers: FAKE_HEADERS
        , _

        expectNeo4jRoot body

    it 'should throw errors for 4xx responses by default', (_) ->
        try
            thrown = false
            DB.http
                method: 'POST'
                path: '/'
            , _
        catch err
            thrown = true
            expect(err).to.be.an.instanceOf neo4j.ClientError
            expect(err.name).to.equal 'neo4j.ClientError'
            expect(err.http).to.be.an 'object'
            expect(err.http.statusCode).to.equal 405

        expect(thrown).to.be.true()

    it 'should support returning raw responses', (_) ->
        resp = DB.http
            method: 'GET'
            path: '/'
            raw: true
        , _

        expectResponse resp, 200
        expect(resp.headers['content-type']).to.match /// ^application/json\b ///
        expectNeo4jRoot resp.body

    it 'should not throw 4xx errors for raw responses', (_) ->
        resp = DB.http
            method: 'POST'
            path: '/'
            raw: true
        , _

        expectResponse resp, 405 # Method Not Allowed

    it 'should throw native errors always', (_) ->
        db = new neo4j.GraphDatabase 'http://idontexist.foobarbaz.nodeneo4j'

        try
            thrown = false
            db.http
                path: '/'
                raw: true
            , _
        catch err
            thrown = true
            expect(err).to.be.an.instanceOf Error
            expect(err.name).to.equal 'Error'
            expect(err.code).to.equal 'ENOTFOUND'
            expect(err.syscall).to.equal 'getaddrinfo'

        expect(thrown).to.be.true()

    it 'should support streaming'
        # Test that it immediately returns a duplex HTTP stream.
        # Test writing request data to this stream.
        # Test reading response data from this stream.
