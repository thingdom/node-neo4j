{expect} = require 'chai'
{GraphDatabase} = require '../'
http = require 'http'


# SHARED STATE

DB = null
URL = process.env.NEO4J_URL or 'http://localhost:7474'

FAKE_PROXY = 'http://lorem.ipsum'
FAKE_HEADERS =
    'x-foo': 'bar-baz'
    'x-lorem': 'ipsum'
    # TODO: Test custom User-Agent behavior?


## TESTS

describe 'GraphDatabase::constructor', ->

    it 'should support full options', ->
        DB = new GraphDatabase
            url: URL
            proxy: FAKE_PROXY
            headers: FAKE_HEADERS

        expect(DB).to.be.an.instanceOf GraphDatabase
        expect(DB.url).to.equal URL
        expect(DB.proxy).to.equal FAKE_PROXY
        expect(DB.headers).to.be.an 'object'

        # Default headers should include/contain our given ones,
        # but may include extra default headers too (e.g. X-Stream):
        for key, val of FAKE_HEADERS
            expect(DB.headers[key]).to.equal val

    it 'should support just URL string', ->
        DB = new GraphDatabase URL

        expect(DB).to.be.an.instanceOf GraphDatabase
        expect(DB.url).to.equal URL
        expect(DB.proxy).to.not.exist()
        expect(DB.headers).to.be.an 'object'

    it 'should throw if no URL given', ->
        fn = -> new GraphDatabase()
        expect(fn).to.throw TypeError

        # Also try giving an options argument, just with no URL:
        fn = -> new GraphDatabase {proxy: FAKE_PROXY}
        expect(fn).to.throw TypeError

describe 'GraphDatabase::http', ->

    it 'should support simple GET requests by default', (_) ->
        body = DB.http '/', _

        expect(body).to.be.an 'object'
        expect(body).to.have.keys 'data', 'management'

    it 'should support complex requests with options', (_) ->
        body = DB.http
            method: 'GET'
            path: '/'
            headers: FAKE_HEADERS
        , _

        expect(body).to.be.an 'object'
        expect(body).to.have.keys 'data', 'management'

    it 'should throw errors for 4xx responses by default', (_) ->
        try
            thrown = false
            DB.http
                method: 'POST'
                path: '/'
            , _
        catch err
            thrown = true
            expect(err).to.be.an.instanceOf Error
            # TODO: Deeper and more semantic assertions, e.g. status code.

        expect(thrown).to.be.true()

    it 'should support returning raw responses', (_) ->
        resp = DB.http
            method: 'GET'
            path: '/'
            raw: true
        , _

        expect(resp).to.be.an.instanceOf http.IncomingMessage

        {statusCode, headers, body} = resp

        expect(statusCode).to.equal 200

        expect(headers).to.be.an 'object'
        expect(headers['content-type']).to.match /// ^application/json\b ///

        expect(body).to.be.an 'object'
        expect(body).to.have.keys 'data', 'management'

    it 'should not throw 4xx errors for raw responses', (_) ->
        resp = DB.http
            method: 'POST'
            path: '/'
            raw: true
        , _

        expect(resp).to.be.an.instanceOf http.IncomingMessage
        expect(resp.statusCode).to.equal 405 # Method Not Allowed

    it 'should throw native errors always', (_) ->
        db = new GraphDatabase 'http://idontexist.foobarbaz.nodeneo4j'

        try
            thrown = false
            db.http
                path: '/'
                raw: true
            , _
        catch err
            thrown = true
            expect(err).to.be.an.instanceOf Error
            # TODO: Deeper and more semantic assertions?

        expect(thrown).to.be.true()

    it 'should support streaming'
        # Test that it immediately returns a duplex HTTP stream.
        # Test writing request data to this stream.
        # Test reading response data from this stream.
