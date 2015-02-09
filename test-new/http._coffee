#
# Tests for the GraphDatabase `http` method, e.g. the ability to make custom,
# arbitrary HTTP requests, and have responses parsed for nodes, rels, & errors.
#

{expect} = require 'chai'
fixtures = require './fixtures'
fs = require 'fs'
http = require 'http'
neo4j = require '../'


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

#
# Asserts that the given object is a proper instance of the given Neo4j Error
# subclass, including with the given message.
# Additional checks, e.g. of the `neo4j` property's contents, are up to you.
#
expectError = (err, ErrorClass, message) ->
    expect(err).to.be.an.instanceOf ErrorClass
    expect(err.name).to.equal "neo4j.#{ErrorClass.name}"
    expect(err.neo4j).to.be.an 'object'
    expect(err.message).to.equal message
    expect(err.stack).to.contain '\n'
    expect(err.stack.split('\n')[0]).to.equal "#{err.name}: #{err.message}"


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
            try
                expect(err).to.exist()
                expect(body).to.not.exist()

                expectError err, neo4j.ClientError,
                    '[405] Method Not Allowed response for POST /'
                expect(err.neo4j).to.be.empty()

            catch assertionErr
                return done assertionErr

            done()

    it 'should properly parse Neo4j exceptions', (done) ->
        DB.http
            method: 'GET'
            path: '/db/data/node/-1'
        , (err, body) ->
            try
                expect(err).to.exist()
                expect(body).to.not.exist()

                expectError err, neo4j.ClientError, '[404] [NodeNotFoundException]
                    Cannot find node with id [-1] in database.'

                expect(err.neo4j).to.be.an 'object'
                expect(err.neo4j.exception).to.equal 'NodeNotFoundException'
                expect(err.neo4j.fullname).to.equal '
                    org.neo4j.server.rest.web.NodeNotFoundException'
                expect(err.neo4j.message).to.equal '
                    Cannot find node with id [-1] in database.'

                expect(err.neo4j.stacktrace).to.be.an 'array'
                expect(err.neo4j.stacktrace).to.not.be.empty()
                for line in err.neo4j.stacktrace
                    expect(line).to.be.a 'string'
                    expect(line).to.not.be.empty()

            catch assertionErr
                return done assertionErr

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
            try
                expect(err).to.exist()
                expect(resp).to.not.exist()

                # NOTE: *Not* using `expectError` here, because we explicitly
                # don't wrap native (non-Neo4j) errors.
                expect(err).to.be.an.instanceOf Error
                expect(err.name).to.equal 'Error'
                expect(err.code).to.equal 'ENOTFOUND'
                expect(err.syscall).to.equal 'getaddrinfo'
                expect(err.message).to.contain "#{err.syscall} #{err.code}"
                    # NOTE: Node 0.12 adds the hostname to the message.
                expect(err.stack).to.contain '\n'
                expect(err.stack.split('\n')[0]).to.equal \
                    "#{err.name}: #{err.message}"

            catch assertionErr
                return done assertionErr

            done()

    it 'should support streaming', (done) ->
        opts =
            method: 'PUT'
            path: '/db/data/node/-1/properties'
            headers:
                # Node recommends setting this property when streaming:
                # http://nodejs.org/api/http.html#http_request_write_chunk_encoding_callback
                'Transfer-Encoding': 'chunked'
                'X-Foo': 'Bar'  # This one's just for testing/verifying

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
        fs.createReadStream "#{__dirname}/fixtures/fake.json"
            .pipe req

        # Verify that the request fully waits for our stream to finish
        # before returning a response:
        finished = false
        req.on 'finish', -> finished = true

        # When the response is received, stream down its JSON too:
        req.on 'response', (resp) ->
            expect(finished).to.be.true()
            expectResponse resp, 404

            resp.setEncoding 'utf8'
            body = ''

            resp.on 'data', (str) -> body += str
            resp.on 'error', done
            resp.on 'close', -> done new Error 'Response closed!'
            resp.on 'end', ->
                try
                    body = JSON.parse body

                    # Simplified error parsing; just verifying stream:
                    expect(body).to.be.an 'object'
                    expect(body.exception).to.equal 'NodeNotFoundException'
                    expect(body.stacktrace).to.be.an 'array'

                catch err
                    return done err

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
