express = require 'express'


module.exports = ->
    app = express()
    server = app.listen()
    port = server.address().port

    BASE_URL = "http://localhost:#{port}"

    # Root
    app.get '/', (req, res) ->
        res.json
            management: "#{BASE_URL}/db/manage/"
            data: "#{BASE_URL}/db/data/"

    # Data
    app.get '/db/data/', (req, res) ->
        res.json
            extensions:
                CypherPlugin:
                    execute_query: "#{BASE_URL}/db/data/ext/CypherPlugin/graphdb/execute_query"

                GremlinPlugin:
                    execute_script: "#{BASE_URL}/db/data/ext/GremlinPlugin/graphdb/execute_script"

              node: "#{BASE_URL}/db/data/node"
              reference_node: "#{BASE_URL}/db/data/node/0"
              node_index: "#{BASE_URL}/db/data/index/node"
              relationship_index: "#{BASE_URL}/db/data/index/relationship"
              extensions_info: "#{BASE_URL}/db/data/ext"
              relationship_types: "#{BASE_URL}/db/data/relationship/types"
              batch: "#{BASE_URL}/db/data/batch"
              cypher: "#{BASE_URL}/db/data/cypher"
              neo4j_version: "1.9.5"

    {app, server, port}
