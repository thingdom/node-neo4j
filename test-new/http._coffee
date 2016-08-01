#
# Tests for the GraphDatabase `http` method, e.g. the ability to make custom,
# arbitrary HTTP requests, and have responses parsed for nodes, rels, & errors.
#

{expect} = require 'chai'
fixtures = require './fixtures'
fs = require 'fs'
helpers = require './util/helpers'
http = require 'http'
neo4j = require '../'
Request = require 'request'


## CONSTANTS

FAKE_JSON_PATH = "#{__dirname}/fixtures/fake.json"
FAKE_JSON = require FAKE_JSON_PATH


## SHARED STATE

{DB} = fixtures

[TEST_NODE_A, TEST_NODE_B, TEST_REL] = []


## HELPERS

#
# Asserts that the given object is a proper HTTP client request,
# set to the given method and path, and optionally including the given headers.
#
expectRequest = (req, method, path, headers={}) ->
    expect(req).to.be.an.instanceOf Request.Request
    expect(req.method).to.equal method
    expect(req.path).to.equal path

    # Special-case for headers since they're stored differently:
    for name, val of headers
        expect(req.getHeader name).to.equal val

#
# Asserts that the given object is a proper HTTP client response,
# with the given status code, and by default, a JSON Content-Type.
#
expectResponse = (resp, statusCode, json=true) ->
    expect(resp).to.be.an.instanceOf http.IncomingMessage
    expect(resp.statusCode).to.equal statusCode
    expect(resp.headers).to.be.an 'object'

    if json
        expect(resp.headers['content-type']).to.match /^application\/json\b/

#
# Asserts that the given object is the root Neo4j object.
#
expectNeo4jRoot = (body) ->
    expect(body).to.be.an 'object'
    expect(body).to.have.keys 'data', 'management'

#
# Streams the given Request response, and calls either the error callback
# (for failing tests) or the success callback (with the parsed JSON body).
# Also asserts that the response has the given status code.
#
streamRequestResponse = (req, statusCode, cbErr, cbBody) ->
    body = null

    req.on 'error', cbErr
    req.on 'close', -> cbErr new Error 'Response closed!'

    req.on 'response', (resp) ->
        expectResponse resp, statusCode

    req.on 'data', (str) ->
        body ?= ''
        body += str

    req.on 'end', ->
        try
            body = JSON.parse body
        catch err
            return cbErr err

        cbBody body


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

    it 'should throw errors for 4xx responses by default', (done) ->
        DB.http
            method: 'POST'
            path: '/'
        , (err, body) ->
            expect(err).to.exist()
            expect(body).to.not.exist()

            helpers.expectRawError err, 'ClientError',
                '405 Method Not Allowed response for POST /'

            done()

    it 'should properly parse Neo4j exceptions', (done) ->
        DB.http
            method: 'GET'
            path: '/db/data/node/-1'
        , (err, body) ->
            expect(err).to.exist()
            expect(body).to.not.exist()

            # Neo4j 2.2 returns a proper new-style error object for this case,
            # but previous versions return an old-style error.
            try
                helpers.expectError err,
                    'ClientError', 'Statement', 'EntityNotFound',
                    'Cannot find node with id [-1] in database.'
            catch assertionErr
                # Check for the older case, but if this fails,
                # throw the original assertion error, not this one.
                try
                    helpers.expectOldError err, 404, 'NodeNotFoundException',
                        'org.neo4j.server.rest.web.NodeNotFoundException',
                        'Cannot find node with id [-1] in database.'
                catch doubleErr
                    throw assertionErr

            done()

    it 'should support returning raw responses', (_) ->
        resp = DB.http
            method: 'GET'
            path: '/'
            raw: true
        , _

        expectResponse resp, 200
        expectNeo4jRoot resp.body

    it 'should not throw 4xx errors for raw responses', (_) ->
        resp = DB.http
            method: 'POST'
            path: '/'
            raw: true
        , _

        expectResponse resp, 405, false     # Method Not Allowed, no JSON body

    it 'should throw native errors always', (done) ->
        db = new neo4j.GraphDatabase 'http://idontexist.foobarbaz.nodeneo4j'
        db.http
            path: '/'
            raw: true
        , (err, resp) ->
            expect(err).to.exist()
            expect(resp).to.not.exist()

            # NOTE: *Not* using our `expectError` helpers here, because we
            # explicitly don't wrap native (non-Neo4j) errors.
            expect(err).to.be.an.instanceOf Error
            expect(err.name).to.equal 'Error'
            expect(err.code).to.equal 'ENOTFOUND'
            expect(err.syscall).to.equal 'getaddrinfo'
            expect(err.message).to.contain "#{err.syscall} #{err.code}"
                # NOTE: Node 0.12 adds the hostname to the message.
            expect(err.stack).to.contain '\n'
            expect(err.stack.split('\n')[0]).to.equal \
                "#{err.name}: #{err.message}"

            done()

    it 'should support streaming responses', (done) ->
        opts =
            method: 'GET'
            path: '/db/data/node/-1'

        req = DB.http opts

        expectRequest req, opts.method, opts.path

        streamRequestResponse req, 404, done, (body) ->
            # Simplified error parsing; just verifying stream:
            expect(body).to.be.an 'object'
            expect(body.exception).to.equal 'NodeNotFoundException'
            expect(body.message).to.equal '
                Cannot find node with id [-1] in database.'
            # Neo4j 2.2 changed `stacktrace` to `stackTrace`:
            expect(body.stackTrace or body.stacktrace).to.be.an 'array'

            done()

    it 'should support streaming responses, even if not requests', (done) ->
        opts =
            method: 'POST'
            path: '/db/data/node'
            body: FAKE_JSON

        req = DB.http opts

        # TODO: Should we also assert that the request has automatically added
        # Content-Type and Content-Length headers? Not technically required?
        expectRequest req, opts.method, opts.path

        streamRequestResponse req, 400, done, (body) ->
            # Simplified error parsing; just verifying stream:
            expect(body).to.be.an 'object'
            expect(body.exception).to.equal 'PropertyValueException'
            expect(body.message).to.equal 'Could not set property "object",
                unsupported type: {foo={bar=baz}}'
            # Neo4j 2.2 changed `stacktrace` to `stackTrace`:
            expect(body.stackTrace or body.stacktrace).to.be.an 'array'

            done()

    it 'should support streaming both requests and responses', (done) ->
        opts =
            method: 'POST'
            path: '/db/data/node'
            headers:
                'Content-Type': 'application/json'
                # NOTE: It seems that Neo4j needs an explicit Content-Length,
                # at least for requests to this `POST /db/data/node` endpoint.
                'Content-Length': (fs.statSync FAKE_JSON_PATH).size
                # Ideally, we would instead send this header for streaming:
                # http://nodejs.org/api/http.html#http_request_write_chunk_encoding_callback
                # 'Transfer-Encoding': 'chunked'

        req = DB.http opts

        expectRequest req, opts.method, opts.path, opts.headers

        # Now stream some fake JSON to the request:
        fs.createReadStream(FAKE_JSON_PATH).pipe req

        streamRequestResponse req, 400, done, (body) ->
            # Simplified error parsing; just verifying stream:
            expect(body).to.be.an 'object'
            expect(body.exception).to.equal 'PropertyValueException'
            expect(body.message).to.equal 'Could not set property "object",
                unsupported type: {foo={bar=baz}}'
            # Neo4j 2.2 changed `stacktrace` to `stackTrace`:
            expect(body.stackTrace or body.stacktrace).to.be.an 'array'

            done()


    ## Object parsing:

    it '(create test graph)', (_) ->
        [TEST_NODE_A, TEST_REL, TEST_NODE_B] =
            fixtures.createTestGraph module, 2, _

    it 'should parse nodes by default', (_) ->
        node = DB.http
            method: 'GET'
            path: "/db/data/node/#{TEST_NODE_A._id}"
        , _

        expect(node).to.be.an.instanceOf neo4j.Node
        expect(node).to.eql TEST_NODE_A

    it 'should parse relationships by default', (_) ->
        rel = DB.http
            method: 'GET'
            path: "/db/data/relationship/#{TEST_REL._id}"
        , _

        expect(rel).to.be.an.instanceOf neo4j.Relationship
        expect(rel).to.eql TEST_REL

    it 'should parse nested nodes & relationships by default', (_) ->
        {data} = DB.http
            method: 'POST'
            path: '/db/data/cypher'
            body:
                query: '''
                    START a = node({idA})
                    MATCH (a) -[r]-> (b)
                    RETURN a, r, b
                '''
                params:
                    idA: TEST_NODE_A._id
        , _

        [row] = data
        [nodeA, rel, nodeB] = row

        expect(nodeA).to.be.an.instanceOf neo4j.Node
        expect(nodeA).to.eql TEST_NODE_A
        expect(nodeB).to.be.an.instanceOf neo4j.Node
        expect(nodeB).to.eql TEST_NODE_B
        expect(rel).to.be.an.instanceOf neo4j.Relationship
        expect(rel).to.eql TEST_REL

    it 'should not parse nodes for raw responses', (_) ->
        {body} = DB.http
            method: 'GET'
            path: "/db/data/node/#{TEST_NODE_A._id}"
            raw: true
        , _

        expect(body).to.not.be.an.instanceOf neo4j.Node

        # NOTE: Neo4j <2.1.5 didn't return `metadata`, so can't rely on it:
        if fixtures.DB_VERSION_STR >= '2.1.5'
            expect(body.metadata).to.be.an 'object'
            expect(body.metadata.id).to.equal TEST_NODE_A._id
            expect(body.metadata.labels).to.eql TEST_NODE_A.labels

        expect(body.data).to.eql TEST_NODE_A.properties

    it 'should not parse relationships for raw responses', (_) ->
        {body} = DB.http
            method: 'GET'
            path: "/db/data/relationship/#{TEST_REL._id}"
            raw: true
        , _

        expect(body).to.not.be.an.instanceOf neo4j.Relationship

        # NOTE: Neo4j <2.1.5 didn't return `metadata`, so can't rely on it:
        if fixtures.DB_VERSION_STR >= '2.1.5'
            expect(body.metadata).to.be.an 'object'
            expect(body.metadata.id).to.equal TEST_REL._id

        expect(body.type).to.equal TEST_REL.type
        expect(body.data).to.eql TEST_REL.properties

    it '(delete test graph)', (_) ->
        fixtures.deleteTestGraph module, _
