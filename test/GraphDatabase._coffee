createMockServer = require './mocks/server'
neo4j = require '..'
{expect} = require 'chai'


describe 'GraphDatabase', ->
    app = null
    server = null
    db = null
    DB_BASE_URL = null

    beforeEach ->
        {app, server, port} = createMockServer()
        DB_BASE_URL = "http://localhost:#{port}"
        db = new neo4j.GraphDatabase DB_BASE_URL

    afterEach ->
        server.close()

    describe '#query', ->
        it 'should forward custom HTTP headers', (_) ->
            app.post '/db/data/cypher', (req, res) ->
                {headers} = req
                res.send
                    columns: ["root"]
                    data: [[
                        paged_traverse: "#{DB_BASE_URL}/db/data/node/0/paged/traverse/{returnType}{?pageSize,leaseTime}"
                        outgoing_relationships: "#{DB_BASE_URL}/db/data/node/0/relationships/out"
                        data: {headers}
                        all_typed_relationships: "#{DB_BASE_URL}/db/data/node/0/relationships/all/{-list|&|types}"
                        traverse: "#{DB_BASE_URL}/db/data/node/0/traverse/{returnType}"
                        all_relationships: "#{DB_BASE_URL}/db/data/node/0/relationships/all"
                        property: "#{DB_BASE_URL}/db/data/node/0/properties/{key}"
                        self: "#{DB_BASE_URL}/db/data/node/0"
                        outgoing_typed_relationships: "#{DB_BASE_URL}/db/data/node/0/relationships/out/{-list|&|types}"
                        properties: "#{DB_BASE_URL}/db/data/node/0/properties"
                        incoming_relationships: "#{DB_BASE_URL}/db/data/node/0/relationships/in"
                        incoming_typed_relationships: "#{DB_BASE_URL}/db/data/node/0/relationships/in/{-list|&|types}"
                        extensions: {}
                        create_relationship: "#{DB_BASE_URL}/db/data/node/0/relationships"
                    ]]

            CUSTOM_HEADERS =
                'X-Request-Id': 'request-id-53'
                'X-B3-Sampled': 'true'

            [{root}] = db.query """
                START root=node({id})
                RETURN root
            """, {id: 0}, {headers: CUSTOM_HEADERS}, _

            {headers} = root._data.data
            for name, value of CUSTOM_HEADERS
                normalizedName = name.toLowerCase()
                normalizedValue = value.toString()
                expect(headers[normalizedName]).to.equal normalizedValue
