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


## CONSTANTS

FAKE_JSON_PATH = "#{__dirname}/fixtures/fake.json"


## SHARED STATE

{DB} = fixtures

[TEST_NODE_A, TEST_NODE_B, TEST_REL] = []


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

            # TEMP: Neo4j 2.2 responds here with a new-style error object,
            # but it's currently a `DatabaseError` in 2.2.0-RC01.
            # https://github.com/neo4j/neo4j/issues/4145
            try
                helpers.expectOldError err, 404, 'NodeNotFoundException',
                    'org.neo4j.server.rest.web.NodeNotFoundException',
                    'Cannot find node with id [-1] in database.'
            catch assertionErr
                # Check for the Neo4j 2.2 case, but if this fails,
                # throw the original assertion error, not this one.
                try
                    helpers.expectError err,
                        'DatabaseError', 'General', 'UnknownFailure',
                        'org.neo4j.server.rest.web.NodeNotFoundException:
                            Cannot find node with id [-1] in database.'
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
        expect(resp.headers['content-type']).to.match /// ^application/json\b ///
        expectNeo4jRoot resp.body

    it 'should not throw 4xx errors for raw responses', (_) ->
        resp = DB.http
            method: 'POST'
            path: '/'
            raw: true
        , _

        expectResponse resp, 405 # Method Not Allowed

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

    it 'should support streaming', (done) ->
        opts =
            method: 'POST'
            path: '/db/data/node'
            headers:
                # NOTE: It seems that Neo4j needs an explicit Content-Length,
                # at least for requests to this `POST /db/data/node` endpoint.
                'Content-Length': (fs.statSync FAKE_JSON_PATH).size
                # Ideally, we would instead send this header for streaming:
                # http://nodejs.org/api/http.html#http_request_write_chunk_encoding_callback
                # 'Transfer-Encoding': 'chunked'

        req = DB.http opts

        expect(req).to.be.an.instanceOf http.ClientRequest
        expect(req.method).to.equal opts.method
        expect(req.path).to.equal opts.path

        # Special-case for headers since they're stored differently:
        for name, val of opts.headers
            expect(req.getHeader name).to.equal val

        # Native errors are emitted on this request, so fail-fast if any:
        req.on 'error', done

        # Now stream some fake JSON to the request:
        # TODO: Why doesn't this work?
        # fs.createReadStream(FAKE_JSON_PATH).pipe req
        # TEMP: Instead, we have to manually pipe:
        readStream = fs.createReadStream FAKE_JSON_PATH
        readStream.on 'error', done
        readStream.on 'data', (chunk) -> req.write chunk
        readStream.on 'end', -> req.end()

        # Verify that the request fully waits for our stream to finish
        # before returning a response:
        finished = false
        req.on 'finish', -> finished = true

        # When the response is received, stream down its JSON too:
        req.on 'response', (resp) ->
            expect(finished).to.be.true()
            expectResponse resp, 400

            resp.setEncoding 'utf8'
            body = ''

            resp.on 'data', (str) -> body += str
            resp.on 'error', done
            resp.on 'close', -> done new Error 'Response closed!'
            resp.on 'end', ->
                body = JSON.parse body

                # Simplified error parsing; just verifying stream:
                expect(body).to.be.an 'object'
                expect(body.exception).to.equal 'PropertyValueException'
                expect(body.message).to.equal 'Could not set property "object",
                    unsupported type: {foo={bar=baz}}'
                expect(body.stacktrace).to.be.an 'array'

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
                query: """
                    START a = node({idA})
                    MATCH (a) -[r]-> (b)
                    RETURN a, r, b
                """
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
