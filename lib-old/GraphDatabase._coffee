# TODO many of these functions take a callback but, in some cases, call the
# callback immediately (e.g. if a value is cached). we should probably make
# sure to always call callbacks asynchronously, to prevent race conditions.
# this can be done in Streamline syntax by adding one line before cases where
# we're returning immediately: process.nextTick _

PACKAGE = require '../package'

status = require 'http-status'

util = require './util'
adjustError = util.adjustError

Relationship = require './Relationship'
Node = require './Node'

# The key we use in our serialized JSON to identify this library's objects.
JSON_KEY = '_nodeNeo4j'


#
# The class corresponding to a Neo4j graph database. Start here.
#
module.exports = class GraphDatabase

    #
    # Construct a new client for the Neo4j graph database available at the
    # given (root) URL.
    #
    # @overload constructor(url)
    #   @param url {String} The root URL where the Neo4j graph database is
    #     available, e.g. `'http://localhost:7474/'`. This URL should include
    #     HTTP Basic Authentication info if needed, e.g.
    #     `'http://user:password@example.com/'`.
    #
    # @overload constructor(opts)
    #   @param opts {Object}
    #   @option opts url {String} The root URL where the Neo4j graph database
    #     is available, e.g. `'http://localhost:7474/'`. This URL should
    #     include HTTP Basic Authentication info if needed, e.g.
    #     `'http://user:password@example.com/'`.
    #   @option opts proxy {String} An optional proxy URL for all requests.
    #
    constructor: (opts) ->
        # normalize arg:
        opts =
            if typeof opts is 'string' then {url: opts}
            else opts

        {@url} = opts
        @_request = util.wrapRequest opts

        # Cache
        @_root = null
        @_services = null

    ### Database: ###

    #
    # Purge this client's cache of API endpoints for this graph database.
    #
    # @private
    #
    _purgeCache: ->
        @_root = null
        @_services = null

    #
    # Fetch, cache, and "return" (via callback) the API root data for this
    # graph database.
    #
    # @private
    # @param callback {Function}
    # @return {Object}
    #
    _getRoot: (_) ->
        if @_root?
            return @_root

        try
            response = @_request.get @url, _

            if response.statusCode isnt status.OK
                throw response

            return @_root = response.body

        catch error
            throw adjustError error

    #
    # Fetch, cache, and "return" (via callback) the API services data for this
    # graph database.
    #
    # @private
    # @param callback {Function}
    # @return {Object}
    #
    getServices: (_) ->
        if @_services?
            return @_services

        try
            root = @_getRoot _
            response = @_request.get root.data, _

            if response.statusCode isnt status.OK
                throw response

            return @_services = response.body

        catch error
            throw adjustError error

    ### Nodes: ###

    #
    # Create and immediately return a new, unsaved node with the given
    # properties.
    #
    # @note This node will *not* be persisted to the database until and unless
    #   its {Node#save save()} method is called.
    # @todo We should consider changing this method to persist the node (i.e.
    #   call its {Node#save save()} method) as well in the next version of
    #   this library. That'd be a breaking change, but it'd simplify both this
    #   API and its usage (e.g. the node's `id` will be known then).
    #
    # @param data {Object} The properties this new node should have.
    # @return {Node}
    #
    createNode: (data) ->
        data = data || {}
        node = new Node this,
            data: data
        return node

    #
    # Fetch and "return" (via callback) the node at the given URL.
    #
    # @todo Should this indeed throw an error if no node exists at this URL?
    #   Or should we be returning undefined?
    #
    # @private
    # @param url {String}
    # @param callback {Function}
    # @return {Node}
    # @throw {Error} If no node exists at this URL.
    #
    getNode: (url, _) ->
        try
            response = @_request.get url, _

            if response.statusCode isnt status.OK

                # Node not found
                if response.statusCode is status.NOT_FOUND
                    throw new Error "No node at #{url}"

                # Other unknown errors
                throw response

            return new Node this, response.body

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the node with the given Neo4j ID.
    #
    # @todo Should this indeed throw an error if no node exists with this ID?
    #   Or should we be returning undefined?
    #
    # @param id {Number} The integer ID of the node, e.g. `1234`.
    # @param callback {Function}
    # @return {Node}
    # @throw {Error} If no node exists with this ID.
    #
    getNodeById: (id, _) ->
        try
            services = @getServices _
            url = "#{services.node}/#{id}"
            node = @getNode url, _
            return node

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the node indexed under the given
    # property and value in the given index. If none exists, returns
    # undefined.
    #
    # @note With this method, at most one node is returned. See
    #   {#getIndexedNodes} for returning multiple nodes.
    # @todo We should consider removing this method in the next version of
    #   this library. Client code should be aware of multiple hits instead of
    #   this library hiding that information and arbitrarily returning only
    #   the first hit.
    #
    # @param index {String} The name of the index, e.g. `'node_auto_index'`.
    # @param property {String} The name of the property, e.g. `'username'`.
    # @param value {Object} The value of the property, e.g. `'aseemk'`.
    # @param callback {Function}
    # @return {Node}
    #
    getIndexedNode: (index, property, value, _) ->
        try
            nodes = @getIndexedNodes index, property, value, _

            node = null
            if nodes and nodes.length > 0
                node = nodes[0]
            return node

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the nodes indexed under the given
    # property and value in the given index. If no such nodes exist, an
    # empty array is returned.
    #
    # @note This method will return multiple nodes if there are multiple hits.
    #   See {#getIndexedNode} for returning at most one node.
    #
    # @param index {String} The name of the index, e.g. `'node_auto_index'`.
    # @param property {String} The name of the property, e.g. `'platform'`.
    # @param value {Object} The value of the property, e.g. `'xbox'`.
    # @param callback {Function}
    # @return {Array<Node>}
    #
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
            return response.body.map (node) =>
                new Node this, node

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the nodes matching the given query (in
    # {http://lucene.apache.org/core/old_versioned_docs/versions/3_1_0/queryparsersyntax.html Lucene
    # syntax}) from the given index. If no such nodes exist, an empty array is
    # returned.
    #
    # @param index {String} The name of the index, e.g. `node_auto_index`.
    # @param query {String} The Lucene query, e.g. `foo:bar AND hello:world`.
    # @param callback {Function}
    # @return {Array<Node>}
    #
    queryNodeIndex: (index, query, _) ->
        try
            services = @getServices _
            url = "#{services.node_index}/#{index}?query=#{encodeURIComponent query}"

            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success
            return response.body.map (node) =>
                new Node this, node

        catch error
            throw adjustError error

    ### Relationships: ###

    # @private
    createRelationship: (startNode, endNode, type, _) ->
        # TODO: Implement?

    #
    # Fetch and "return" (via callback) the relationship at the given URL.
    #
    # @todo Should this indeed throw an error if no relationship exists at
    #   this URL? Or should we be returning undefined?
    #
    # @private
    # @param url {String}
    # @param callback {Function}
    # @return {Relationship}
    # @throw {Error} If no relationship exists at this URL.
    #
    getRelationship: (url, _) ->
        try
            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # TODO: Handle 404
                throw response

            return new Relationship this, response.body

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the relationship with the given Neo4j
    # ID.
    #
    # @todo Should this indeed throw an error if no relationship exists with
    #   this ID? Or should we be returning undefined?
    #
    # @param id {Number} The integer ID of the relationship, e.g. `1234`.
    # @param callback {Function}
    # @return {Relationship}
    # @throw {Error} If no relationship exists with this ID.
    #
    getRelationshipById: (id, _) ->
        services = @getServices _
        # FIXME: Neo4j doesn't expose the path to relationships
        relationshipURL = services.node.replace('node', 'relationship')
        url = "#{relationshipURL}/#{id}"
        @getRelationship url, _

    #
    # Fetch and "return" (via callback) the relationship indexed under the
    # given property and value in the given index. If none exists, returns
    # undefined.
    #
    # @note With this method, at most one relationship is returned. See
    #   {#getIndexedRelationships} for returning multiple relationships.
    # @todo We should consider removing this method in the next version of
    #   this library. Client code should be aware of multiple hits instead of
    #   this library hiding that information and arbitrarily returning only
    #   the first hit.
    #
    # @param index {String} The name of the index, e.g. `'relationship_auto_index'`.
    # @param property {String} The name of the property, e.g. `'created'`.
    # @param value {Object} The value of the property, e.g. `1346713658393`.
    # @param callback {Function}
    # @return {Relationship}
    #
    getIndexedRelationship: (index, property, value, _) ->
        try
            relationships = @getIndexedRelationships index, property, value, _
            return relationships?[0] or null

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the relationships indexed under the
    # given property and value in the given index. If no such relationships
    # exist, an empty array is returned.
    #
    # @note This method will return multiple relationships if there are
    #   multiple hits. See {#getIndexedRelationship} for returning at most one
    #   relationship.
    #
    # @param index {String} The name of the index, e.g. `'relationship_auto_index'`.
    # @param property {String} The name of the property, e.g. `'favorite'`.
    # @param value {Object} The value of the property, e.g. `true`.
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
    getIndexedRelationships: (index, property, value, _) ->
        try
            services = @getServices _

            key = encodeURIComponent property
            val = encodeURIComponent value
            url = "#{services.relationship_index}/#{index}/#{key}/#{val}"

            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success
            return response.body.map (relationship) =>
                new Relationship this, relationship

        catch error
            throw adjustError error

    #
    # Fetch and "return" (via callback) the relationships matching the given query (in
    # {http://lucene.apache.org/core/old_versioned_docs/versions/3_1_0/queryparsersyntax.html Lucene
    # syntax}) from the given index. If no such relationship exist, an empty array is
    # returned.
    #
    # @param index {String} The name of the index, e.g. `relationship_auto_index`.
    # @param query {String} The Lucene query, e.g. `foo:bar AND hello:world`.
    # @param callback {Function}
    # @return {Array<Relationship>}
    #
    queryRelationshipIndex: (index, query, _) ->
        try
            services = @getServices _
            url = "#{services.relationship_index}/#{index}?query=#{encodeURIComponent query}"

            response = @_request.get url, _

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success
            return response.body.map (relationship) =>
                new Relationship this, relationship

        catch error
            throw adjustError error

    ### Indexes: ###

    #
    # Get the current existing node indexes.
    # "Returns" (via callback) an array of string index names, but the array
    # also serves as a dictionary of index name to its config properties.
    #
    # @param callback {Function}
    # @return {Array<String>}
    #
    #   db.getNodeIndexes(function (err, indexes) {
    #       if (err) throw err;
    #       indexes.forEach(function (name) {
    #           console.log('Index', name, 'has config:', indexes[name]);
    #       });
    #   });
    #
    getNodeIndexes: (_) ->
        try
            services = @getServices _
            response = @_request.get services.node_index, _

            if response.statusCode not in [status.OK, status.NO_CONTENT]
                # Database error
                throw response

            # Success: transform the map into an array-map hybrid.
            map = response.body or {}
            arr = []
            for name, props of map
                arr.push name
                arr[name] = props
            return arr

        catch error
            throw adjustError error

    #
    # Create node index.
    #
    # @param name {String}
    # @param config {Object} Node index configuration
    # @param callback {Function}
    #
    createNodeIndex: (name, config={}, _) ->
        try
            services = @getServices _

            response = @_request.post
                url: services.node_index
                json: {name, config}
            , _

            if response.statusCode isnt status.CREATED
                # Database error
                throw response

            # Success
            return

        catch error
            throw adjustError error

    # helper for overloaded createNodeIndex() method:
    do (actual = @::createNodeIndex) =>
        @::createNodeIndex = (name, config, callback) ->
            if typeof config is 'function'
                callback = config
                config = null

            actual.call @, name, config, callback

    #
    # Delete a node index.
    #
    # @param name {String}
    # @param callback {Function}
    #
    deleteNodeIndex: (name, _) ->
        try
            services = @getServices _
            response = @_request.del
                url: "#{services.node_index}/#{encodeURIComponent name}"
            , _

            if response.statusCode isnt status.NO_CONTENT
                # Database error
                throw response

            # Success
            return

        catch error
            throw adjustError error

    #
    # Get the current existing relationship indexes.
    # "Returns" (via callback) an array of string index names, but the array
    # also serves as a dictionary of index name to its config properties.
    #
    # @param callback {Function}
    # @return {Array<String>}
    #
    #   db.getRelationshipIndexes(function (err, indexes) {
    #       if (err) throw err;
    #       indexes.forEach(function (name) {
    #           console.log('Index', name, 'has config:', indexes[name]);
    #       });
    #   });
    #
    getRelationshipIndexes: (_) ->
        try
            services = @getServices _
            response = @_request.get services.relationship_index, _

            if response.statusCode not in [status.OK, status.NO_CONTENT]
                # Database error
                throw response

            # Success: transform the map into an array-map hybrid.
            map = response.body or {}
            arr = []
            for name, props of map
                arr.push name
                arr[name] = props
            return arr

        catch error
            throw adjustError error

    #
    # Create relationship index.
    #
    # @param name {String}
    # @param config {Object} Relationship index configuration
    # @param callback {Function}
    #
    createRelationshipIndex: (name, config={}, _) ->
        try
            services = @getServices _

            response = @_request.post
                url: "#{services.relationship_index}/"
                json: {name, config}
            , _

            if response.statusCode isnt status.CREATED
                # Database error
                throw response

            # Success
            return

        catch error
            throw adjustError error

    # helper for overloaded createRelationshipIndex() method:
    do (actual = @::createRelationshipIndex) =>
        @::createRelationshipIndex = (name, config, callback) ->
            if typeof config is 'function'
                callback = config
                config = null

            actual.call @, name, config, callback

    #
    # Delete a relationship index.
    #
    # @param name {String}
    # @param callback {Function}
    #
    deleteRelationshipIndex: (name, _) ->
        try
            services = @getServices _
            response = @_request.del
                url: "#{services.relationship_index}/#{encodeURIComponent name}"
            , _

            if response.statusCode isnt status.NO_CONTENT
                # Database error
                throw response

            # Success
            return

        catch error
            throw adjustError error

    ## Serialization: ##

    #
    # Helper for other classes to serialize their data in a format that this
    # GraphDatabase class will understand for *de*-serialization.
    #
    # @private
    # @param obj {PropertyContainer}
    # @return {Object}
    #
    _toJSON: (obj) ->
        json = {}
        # save this lib's basic info both for identification purposes and in
        # case we ever need it in the future (e.g. for breaking changes):
        json[JSON_KEY] =
            version: PACKAGE.version
            # save the object's constructor name, so we can deserialize it:
            constructor: obj.constructor.name
        # important: we don't save this db's URL, because it might contain a
        # basic auth password!
        json

    #
    # Transforms the given node or relationship object, parsed from JSON,
    # to its appropriate node or relationship instance.
    #
    # @param obj {Object}
    # @return {PropertyContainer}
    #
    fromJSON: (obj) ->
        meta = obj?[JSON_KEY]

        if typeof meta?.constructor isnt 'string'
            throw new Error "Invalid JSON object: #{JSON.stringify obj}"

        Constructor = require "./#{meta.constructor}"
        Constructor._fromJSON @, obj

    #
    # A "reviver" function for JSON.parse() that'll transform any serialized
    # nodes or relationships into their appropriate instances.
    #
    # To use, pass this method as the second parameter to JSON.parse().
    # For convenience, it'll be bound to this GraphDatabase instance.
    #
    # @param key {String}
    # @param val {Object}
    # @return {Object}
    # @see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/parse
    # @example Serialize and deserialize nodes and relationships.
    #
    #   var obj = {foo: node, bar: [relationship]};
    #   var str = JSON.stringify(obj);
    #   var res = JSON.parse(str, db.reviveJSON);
    #   // res.foo and res.bar[0] are Node and Relationship instances
    #
    reviveJSON: (key, val) =>
        # only transform objects we recognize; ignore (pass through) the rest:
        if typeof val?[JSON_KEY]?.constructor is 'string'
            @fromJSON val
        else
            val

    ### Misc/Other: ###

    #
    # Fetch and "return" (via callback) the results of the given
    # {http://docs.neo4j.org/chunked/stable/cypher-query-lang.html Cypher}
    # query, optionally passing along the given query parameters (recommended
    # to avoid Cypher injection security vulnerabilities). The returned
    # results are an array of "rows" (matches), where each row is a map from
    # key name (as given in the query) to value. Any values that represent
    # nodes, relationships or paths are returned as {Node}, {Relationship} or
    # {Path} instances.
    #
    # @param query {String} The Cypher query. Can be multi-line.
    # @param params {Object} A map of parameters for the Cypher query.
    # @param callback {Function}
    # @return {Array<Object>}
    # @example Fetch a user's likes.
    #
    #   var query = [
    #     'START user=node({userId})',
    #     'MATCH (user) -[:likes]-> (other)',
    #     'RETURN other'
    #   ].join('\n');
    #
    #   var params = {
    #     userId: currentUser.id
    #   };
    #
    #   db.query(query, params, function (err, results) {
    #     if (err) throw err;
    #     var likes = results.map(function (result) {
    #       return result['other'];
    #     });
    #     // ...
    #   });
    #
    query: (query, params={}, _) ->
        try
            services = @getServices _
            endpoint = services.cypher or
                services.extensions?.CypherPlugin?['execute_query']

            if not endpoint
                throw new Error 'Cypher plugin not installed'

            if typeof query isnt 'string'
                throw new Error "Expected string query; got #{typeof query}."

            response = @_request.post
                uri: endpoint
                json: {query, params}
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
            body = response.body

            # Update: guard against streaming errors where the response code
            # is still 200, but the body is malformed JSON, and node-request
            # swallows the error parsing the JSON:
            # https://github.com/thingdom/node-neo4j/issues/71
            # This is a manual fix for only this operation, since we know
            # here that the response should always be a JSON object.
            if typeof body isnt 'object'
                throw new Error """
                    Malformed Cypher response for query:

                    #{query}

                    Neo4j may have run out of memory processing this query.
                    Maybe try a more efficient query?
                """

            columns = body.columns
            results = for row in body.data
                map = {}
                for value, i in row
                    map[columns[i]] = util.transform value, this
                map
            return results

        catch error
            throw adjustError error

    # XXX temporary backwards compatibility shim for query() argument order,
    # and also to support overloaded method signature:
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

    #
    # Execute and "return" (via callback) the results of the given
    # {http://docs.neo4j.org/chunked/snapshot/gremlin-plugin.html Gremlin}
    # script, optionally passing along the given script parameters
    # (recommended to avoid Gremlin injection security vulnerabilities). Any
    # values in the returned results that represent nodes, relationships or
    # paths are returned as {Node}, {Relationship} or {Path} instances.
    #
    # @param script {String} The Gremlin script. Can be multi-line.
    # @param params {Object} A map of parameters for the Gremlin script.
    # @param callback {Function}
    # @return {Object}
    # @example Fetch a user's likes.
    #
    #   var script = "g.v(userId).out('likes')";
    #
    #   var params = {
    #     userId: currentUser.id
    #   };
    #
    #   db.execute(script, params, function (err, likes) {
    #     if (err) throw err;
    #     likes.forEach(function (node) {
    #       // ...
    #     });
    #   });
    #
    execute: (script, params={}, _) ->
        try
            services = @getServices _
            endpoint = services.extensions?.GremlinPlugin?['execute_script']

            if not endpoint
                throw new Error 'Gremlin plugin not installed'

            response = @_request.post
                uri: endpoint
                json: {script, params}
            , _

            # XXX workaround for neo4j silent failures for invalid queries:
            if response.statusCode is status.NO_CONTENT
                throw new Error """
                    Unknown Neo4j error for Gremlin script:

                    #{script}

                """

            if response.statusCode isnt status.OK
                # Database error
                throw response

            # Success: transform nodes/relationships
            return util.transform response.body, this

        catch error
            throw adjustError error

    # helper for overloaded execute() method:
    do (actual = @::execute) =>
        @::execute = (script, params, callback) ->
            if typeof params is 'function'
                callback = params
                params = null

            actual.call @, script, params, callback
