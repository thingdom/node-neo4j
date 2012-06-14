# TODO many of these functions take a callback but, in some cases, call the
# callback immediately (e.g. if a value is cached). we should probably make
# sure to always call callbacks asynchronously, to prevent race conditions.
# this can be done in Streamline syntax by adding one line before cases where
# we're returning immediately: process.nextTick _

status = require 'http-status'

util = require './util'
adjustError = util.adjustError

Relationship = require './Relationship'
Node = require './Node'

module.exports = class GraphDatabase
    constructor: (url) ->
        @url = url
        @_request = util.wrapRequestForAuth url

        # Cache
        @_root = null
        @_services = null

    # Database
    _purgeCache: ->
        @_root = null
        @_services = null

    _getRoot: (_) ->
        if @_root?
            return @_root

        try
            response = @_request.get @url, _

            if response.statusCode isnt status.OK
                throw response

            @_root = JSON.parse response.body
            return @_root

        catch error
            throw adjustError error

    getServices: (_) ->
        if @_services?
            return @_services

        try
            root = @_getRoot _
            response = @_request.get root.data, _

            if response.statusCode isnt status.OK
                throw response

            @_services = JSON.parse response.body
            return @_services

        catch error
            throw adjustError error

    getVersion: (_) ->
        try
            services = @getServices _

            # Neo4j 1.5 onwards report their version number here;
            # if it's not there, assume Neo4j 1.4.
            parseFloat services['neo4j_version'] or '1.4'

        catch error
            throw adjustError

    # Nodes
    createNode: (data) ->
        data = data || {}
        node = new Node this,
            data: data
        return node

    getNode: (url, _) ->
        try
            response = @_request.get url, _

            if response.statusCode isnt status.OK

                # Node not found
                if response.statusCode is status.NOT_FOUND
                    throw new Error "No node at #{url}"

                throw response

            node = new Node this, JSON.parse response.body
            return node

        catch error
            throw adjustError error

    getIndexedNode: (index, property, value, _) ->
        try
            nodes = @getIndexedNodes index, property, value, _

            node = null
            if nodes and nodes.length > 0
                node = nodes[0]
            return node

        catch error
            throw adjustError error

    getIndexedNodes: (index, property, value, _) ->
        try
            services = @getServices _

            key = encodeURIComponent property
            val = encodeURIComponent value
            url = "#{services.node_index}/#{index}/#{key}/#{val}"

            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success
            nodeArray = JSON.parse response.body
            nodes = nodeArray.map (node) =>
                new Node this, node
            return nodes

        catch error
            throw adjustError error

    getNodeById: (id, _) ->
        try
            services = @getServices _
            url = "#{services.node}/#{id}"
            node = @getNode url, _
            return node

        catch error
            throw adjustError error

    # Relationships
    createRelationship: (startNode, endNode, type, _) ->
        # TODO: Implement

    getRelationship: (url, _) ->
        try
            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # TODO: Handle 404
                throw response

            data = JSON.parse response.body

            # Construct relationship
            relationship = new Relationship this, data

            return relationship

        catch error
            throw adjustError error

    getRelationshipById: (id, _) ->
        services = @getServices _
        # FIXME: Neo4j doesn't expose the path to relationships
        relationshipURL = services.node.replace('node', 'relationship')
        url = "#{relationshipURL}/#{id}"
        @getRelationship url, _

    # wrapper around the Cypher plugin, which comes bundled w/ Neo4j.
    # pass in the Cypher query as a string (can be multi-line), and optionally
    # query parameters as a map -- recommended for both perf and security!
    # http://docs.neo4j.org/chunked/stable/cypher-query-lang.html
    # returns an array of "rows" (matches), where each row is a map from
    # variable name (as given in the passed in query) to value. any values
    # that represent nodes or relationships are transformed to instances.
    query: (query, params, _) ->
        try
            services = @getServices _
            endpoint = services.cypher or
                services.extensions?.CypherPlugin?['execute_query']

            if not endpoint
                throw new Error 'Cypher plugin not installed'

            response = @_request.post
                uri: endpoint
                json: if params then {query, params} else {query}
            , _

            # XXX workaround for neo4j silent failures for invalid queries:
            if response.statusCode is status.NO_CONTENT
                throw new Error """
                    Unknown Neo4j error for query:

                    #{query}

                """

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success: build result maps, and transform nodes/relationships
            body = response.body    # JSON already parsed by request
            columns = body.columns
            results = for row in body.data
                map = {}
                for value, i in row
                    map[columns[i]] =
                        if value and typeof value is 'object' and value.self
                            if value.type then new Relationship this, value
                            else new Node this, value
                        else
                            value
                map
            return results

        catch error
            throw adjustError error

    # XXX temporary backwards compatibility shim for query() argument order:
    do (actual = @::query) =>
        @::query = (query, params, callback) ->
            if typeof query is 'function' and typeof params is 'string'
                # instantiate a new error to derive the current stack, and
                # show the relevant source line in a warning:
                console.warn 'neo4j.GraphDatabase::query()’s signature is ' +
                    'now (query, params, callback). Please update your code!\n' +
                    new Error().stack.split('\n')[2]    # includes indentation
                callback = query
                query = params
                params = null
            else if typeof params is 'function'
                callback = params
                params = null

            actual.call @, query, params, callback

    # executes a query against the given node index. lucene syntax reference:
    # http://lucene.apache.org/java/3_1_0/queryparsersyntax.html
    queryNodeIndex: (index, query, _) ->
        try
            services = @getServices _
            url = "#{services.node_index}/#{index}?query=#{encodeURIComponent query}"

            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success
            nodeArray = JSON.parse response.body
            nodes = nodeArray.map (node) =>
                new Node this, node
            return nodes

        catch error
            throw adjustError error
