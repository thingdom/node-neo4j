#
# Tests for the GraphDatabase `http` method, e.g. the ability to make custom,
# arbitrary HTTP requests, and have responses parsed for nodes, rels, & errors.
#

{expect} = require 'chai'
http = require 'http'
neo4j = require '../'


## SHARED STATE

DB = new neo4j.GraphDatabase process.env.NEO4J_URL or 'http://localhost:7474'


## HELPERS

#
# Asserts that the given object is a proper HTTP client response with the given
# status code.
#
expectResponse = (resp, statusCode) ->
    expect(resp).to.be.an.instanceOf http.IncomingMessage
    expect(resp.statusCode).to.equal statusCode
    expect(resp.headers).to.be.an 'object'

#
# Asserts that the given object is the root Neo4j object.
#
expectNeo4jRoot = (body) ->
    expect(body).to.be.an 'object'
    expect(body).to.have.keys 'data', 'management'


## TESTS

describe 'GraphDatabase::http', ->

    it 'should support simple GET requests by default', (_) ->
        body = DB.http '/', _
        expectNeo4jRoot body

    it 'should support complex requests with options', (_) ->
        body = DB.http
            method: 'GET'
            path: '/'
            headers:
                'X-Foo': 'bar'
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

    it 'should support streaming (TODO)'
        # Test that it immediately returns a duplex HTTP stream.
        # Test writing request data to this stream.
        # Test reading response data from this stream.
