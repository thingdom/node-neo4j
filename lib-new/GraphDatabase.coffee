$ = require 'underscore'
assert = require 'assert'
Constraint = require './Constraint'
{Error} = require './errors'
Index = require './Index'
lib = require '../package.json'
Node = require './Node'
Relationship = require './Relationship'
Request = require 'request'
Transaction = require './Transaction'
URL = require 'url'


module.exports = class GraphDatabase


    ## CORE

    # Default HTTP headers:
    headers:
        'User-Agent': "node-neo4j/#{lib.version}"

    constructor: (opts={}) ->
        if typeof opts is 'string'
            opts = {url: opts}

        {@url, @auth, @headers, @proxy, @agent} = opts

        if not @url
            throw new TypeError 'URL to Neo4j required'

        # Process auth, whether through option or URL creds or both.
        # Option takes precedence, and we clear the URL creds if option given.
        uri = URL.parse @url
        if uri.auth and @auth?
            delete uri.auth
            @url = URL.format uri

        # We also normalize any given auth to an object or null:
        @auth = _normalizeAuth @auth ? uri.auth

        # Extend the given headers with our defaults, but clone first:
        # TODO: Do we want to special-case User-Agent? Or reject if includes
        # reserved headers like Accept, Content-Type, X-Stream?
        @headers or= {}
        @headers = $(@headers)
            .chain()
            .clone()
            .defaults @constructor::headers
            .value()


    ## HTTP

    http: (opts={}, cb) ->
        if typeof opts is 'string'
            opts = {path: opts}

        {method, path, headers, body, raw} = opts

        if not path
            throw new TypeError 'Path required'

        method or= 'GET'
        headers or= {}

        # Extend the given headers, both with both required and optional
        # defaults, but do so without modifying the input object:
        headers = $(headers)
            .chain()
            .clone()
            .defaults @headers      # These headers can be overridden...
            .extend                 # ...while these can't.
                'X-Stream': 'true'
            .value()

        # TODO: Would be good to test custom proxy and agent, but difficult.
        # Same with Neo4j returning gzipped responses (e.g. through an LB).
        Request
            method: method
            url: URL.resolve @url, path
            proxy: @proxy
            auth: @auth
            headers: headers
            agent: @agent
            json: body ? true
            encoding: 'utf8'
            gzip: true  # This is only for responses: decode if gzipped.

        # Important: only pass a callback to Request if a callback was passed
        # to us. This prevents Request from buffering the response in memory
        # (to parse JSON) if the caller prefers to stream the response instead.
        , cb and (err, resp) =>
            if err
                # TODO: Do we want to wrap or modify native errors?
                return cb err

            if raw
                # TODO: Do we want to return our own Response object?
                return cb null, resp

            if err = Error._fromResponse resp
                return cb err

            cb null, _transform resp.body


    ## AUTH

    checkPasswordChangeNeeded: (cb) ->
        if not @auth?.username
            throw new TypeError 'No `auth` specified in constructor!'

        @http
            method: 'GET'
            path: "/user/#{encodeURIComponent @auth.username}"
        , (err, user) ->
            if err
                return cb err

            cb null, user.password_change_required

    changePassword: (opts={}, cb) ->
        if typeof opts is 'string'
            opts = {password: opts}

        {password} = opts

        if not @auth?.username
            throw new TypeError 'No `auth` specified in constructor!'

        if not password
            throw new TypeError 'Password required'

        @http
            method: 'POST'
            path: "/user/#{encodeURIComponent @auth.username}/password"
            body: {password}
        , (err) =>
            if err
                return cb err

            # Since successful, update our saved state for subsequent requests:
            @auth.password = password

            # Void method:
            cb null


    ## CYPHER

    # NOTE: This method is fairly complex, in part out of necessity.
    # We're okay with it since we test it throughly and emphasize its coverage.
    # coffeelint: disable=cyclomatic_complexity
    cypher: (opts={}, cb, _tx) ->
    # coffeelint: enable=cyclomatic_complexity
        if typeof opts is 'string'
            opts = {query: opts}

        if opts instanceof Array
            opts = {queries: opts}

        {queries, query, params, headers, lean, commit, rollback} = opts

        if not _tx and rollback
            throw new Error 'Illegal state: rolling back without a transaction!'

        if commit and rollback
            throw new Error 'Illegal state: both committing and rolling back!'

        if rollback and (query or queries)
            throw new Error 'Illegal state: rolling back with query/queries!'

        if not _tx and commit is false
            throw new TypeError 'Can’t refuse to commit without a transaction!
                To begin a new transaction without committing, call
                `db.beginTransaction()`, and then call `cypher` on that.'

        if not _tx and not (query or queries)
            throw new TypeError 'Query or queries required'

        if query and queries
            throw new TypeError 'Can’t supply both a single query
                and a batch of queries! Do you have a bug in your code?'

        if queries and params
            throw new TypeError 'When batching multiple queries,
                params must be supplied with each query, not globally.'

        if queries and lean
            throw new TypeError 'When batching multiple queries,
                `lean` must be specified with each query, not globally.'

        if (commit or rollback) and not (query or queries) and not _tx._id
            # (Note that we've already required query or queries if no
            # transaction present, so this means a transaction is present.)
            # This transaction hasn't even been created yet from Neo4j's POV
            # (because transactions are created lazily), so nothing to do.
            cb null, null
            return

        method = 'POST'
        method = 'DELETE' if rollback

        path = '/db/data/transaction'
        path += "/#{_tx._id}" if _tx?._id
        path += '/commit' if commit or not _tx

        # Normalize input query or queries to an array of queries always,
        # but remember whether a single query was given (not a batch).
        # Also handle the case where no queries were given; this is either a
        # void action (e.g. rollback), or legitimately an empty batch.
        if query
            queries = [{query, params, lean}]
            single = true
        else
            single = not queries    # void action, *not* empty [] given
            queries or= []

        # Generate the request body by transforming each query (which is
        # potentially a simple string) into Neo4j's `statement` format.
        # We need to remember what result format we requested for each query.
        formats = []
        body =
            statements:
                for query in queries
                    if typeof query is 'string'
                        query = {query}

                    if query.headers
                        throw new TypeError 'When batching multiple queries,
                            custom request headers cannot be supplied per query;
                            they must be supplied globally.'

                    {query, params, lean} = query

                    # NOTE: Lowercase 'rest' matters here for parsing.
                    formats.push format = if lean then 'row' else 'rest'

                    # NOTE: Braces needed by CoffeeLint for now.
                    # https://github.com/clutchski/coffeelint/issues/459
                    {
                        statement: query
                        parameters: params or {}
                        resultDataContents: [format]
                    }

        # TODO: Support streaming!
        #
        # NOTE: Specifying `raw: true` to save on parsing work (see `_transform`
        # helper at the bottom of this file) if any queries are `lean: true`.
        # Easy enough for us to parse ourselves, which we do, when needed.
        #
        @http {method, path, headers, body, raw: true}, (err, resp) =>

            if err
                # TODO: Do we want to wrap or modify native errors?
                # NOTE: This includes our own errors for non-2xx responses.
                return cb err

            if err = Error._fromResponse resp
                return cb err

            _tx?._updateFromResponse resp

            {results, errors} = resp.body

            # Parse any results first, before errors, in case this is a batch
            # request, where we want to return results alongside errors.
            # The top-level `results` is an array of results corresponding to
            # the `statements` (queries) inputted.
            # We want to transform each query's results from Neo4j's complex
            # format to a simple array of dictionaries.
            results =
                for result, i in results
                    {columns, data} = result
                    format = formats[i]

                    # The `data` for each query is an array of rows, but each of
                    # its elements is actually a dictionary of results keyed by
                    # response format. We only request one format per query.
                    # The value of each format is an array of rows, where each
                    # row is an array of column values. We transform those rows
                    # into dictionaries keyed by column names. Finally, we also
                    # parse nodes & relationships into object instances if this
                    # query didn't request a raw format. Phew!
                    $(data).pluck(format).map (row) ->
                        result = {}

                        for column, j in columns
                            result[column] = row[j]

                        if format is 'rest'
                            result = _transform result

                        result

            # What exactly we return depends on how we were called:
            #
            # - Batch: if an array of queries were given, we always return an
            #   array of each query's results.
            #
            # - Single: if a single query was given, we always return just that
            #   query's results.
            #
            # - Void: if neither was given, we explicitly return null.
            #   This is for transaction actions, e.g. commit, rollback, renew.
            #
            # We're already set up for the batch case by default, so we only
            # need to account for the other cases.
            #
            if single
                # This means a batch of queries was *not* given, but we still
                # normalized to an array of queries...
                if queries.length
                    # This means a single query was given:
                    assert.equal queries.length, 1,
                        'There should be *exactly* one query given.'
                    assert results.length <= 1,
                        'There should be *at most* one set of results.'
                    results = results[0]
                else
                    # This means no query was given:
                    assert.equal results.length, 0,
                        'There should be *no* results.'
                    results = null

            if errors.length
                # TODO: Is it possible to get back more than one error?
                # If so, is it fine for us to just use the first one?
                [error] = errors
                err = Error._fromObject error

            cb err, results

    beginTransaction: ->
        new Transaction @


    ## SCHEMA

    getLabels: (cb) ->
        # This endpoint returns the array of labels directly:
        # http://neo4j.com/docs/stable/rest-api-node-labels.html#rest-api-list-all-labels
        # Hence passing the callback directly. `http` handles 4xx, 5xx errors.
        @http
            method: 'GET'
            path: '/db/data/labels'
        , cb

    getPropertyKeys: (cb) ->
        # This endpoint returns the array of property keys directly:
        # http://neo4j.com/docs/stable/rest-api-property-values.html#rest-api-list-all-property-keys
        # Hence passing the callback directly. `http` handles 4xx, 5xx errors.
        @http
            method: 'GET'
            path: '/db/data/propertykeys'
        , cb

    getRelationshipTypes: (cb) ->
        # This endpoint returns the array of relationship types directly:
        # http://neo4j.com/docs/stable/rest-api-relationship-types.html#rest-api-get-relationship-types
        # Hence passing the callback directly. `http` handles 4xx, 5xx errors.
        @http
            method: 'GET'
            path: '/db/data/relationship/types'
        , cb


    ## INDEXES

    getIndexes: (opts={}, cb) ->
        # Support passing no options at all, to mean "across all labels":
        if typeof opts is 'function'
            cb = opts
            opts = {}

        # Also support passing a label directory:
        if typeof opts is 'string'
            opts = {label: opts}

        {label} = opts

        # Support both querying for a given label, and across all labels:
        path = '/db/data/schema/index'
        path += "/#{encodeURIComponent label}" if label

        @http
            method: 'GET'
            path: path
        , (err, indexes) ->
            cb err, indexes?.map Index._fromRaw

    hasIndex: (opts={}, cb) ->
        {label, property} = opts

        if not (label and property)
            throw new TypeError \
                'Label and property required to query whether an index exists.'

        # NOTE: This is just a convenience method; there is no REST API endpoint
        # for this directly (surprisingly, since there is for constraints).
        # https://github.com/neo4j/neo4j/issues/4214
        @getIndexes {label}, (err, indexes) ->
            cb err, indexes?.some (index) ->
                index.label is label and index.property is property

    createIndex: (opts={}, cb) ->
        {label, property} = opts

        if not (label and property)
            throw new TypeError \
                'Label and property required to create an index.'

        # Passing `raw: true` so we can handle the 409 case below.
        @http
            method: 'POST'
            path: "/db/data/schema/index/#{encodeURIComponent label}"
            body: {'property_keys': [property]}
            raw: true
        , (err, resp) ->
            if err
                return cb err

            # Neo4j returns a 409 error (w/ varying code across versions)
            # if this index already exists (including for a constraint).
            if resp.statusCode is 409
                return cb null, null

            # Translate all other error responses as legitimate errors:
            if err = Error._fromResponse resp
                return cb err

            cb err, if resp.body then Index._fromRaw resp.body

    dropIndex: (opts={}, cb) ->
        {label, property} = opts

        if not (label and property)
            throw new TypeError 'Label and property required to drop an index.'

        # This endpoint is void, i.e. returns nothing:
        # http://neo4j.com/docs/stable/rest-api-schema-indexes.html#rest-api-drop-index
        # Passing `raw: true` so we can handle the 409 case below.
        @http
            method: 'DELETE'
            path: "/db/data/schema/index\
                /#{encodeURIComponent label}/#{encodeURIComponent property}"
            raw: true
        , (err, resp) ->
            if err
                return cb err

            # Neo4j returns a 404 response (with an empty body)
            # if this index doesn't exist (has already been dropped).
            if resp.statusCode is 404
                return cb null, false

            # Translate all other error responses as legitimate errors:
            if err = Error._fromResponse resp
                return cb err

            cb err, true    # Index existed and was dropped


    ## CONSTRAINTS

    getConstraints: (opts={}, cb) ->
        # Support passing no options at all, to mean "across all labels":
        if typeof opts is 'function'
            cb = opts
            opts = {}

        # Also support passing a label directory:
        if typeof opts is 'string'
            opts = {label: opts}

        # TODO: We may need to support querying within a particular `type` too,
        # if any other types beyond uniqueness get added.
        {label} = opts

        # Support both querying for a given label, and across all labels.
        #
        # NOTE: We're explicitly *not* assuming uniqueness type here, since we
        # couldn't achieve consistency with vs. without a label provided.
        # (The `/uniqueness` part of the path can only come after a label.)
        #
        path = '/db/data/schema/constraint'
        path += "/#{encodeURIComponent label}" if label

        @http
            method: 'GET'
            path: path
        , (err, constraints) ->
            cb err, constraints?.map Constraint._fromRaw

    hasConstraint: (opts={}, cb) ->
        # TODO: We may need to support an additional `type` param too,
        # if any other types beyond uniqueness get added.
        {label, property} = opts

        if not (label and property)
            throw new TypeError 'Label and property required to query
                whether a constraint exists.'

        # NOTE: A REST API endpoint *does* exist to get a specific constraint:
        # http://neo4j.com/docs/stable/rest-api-schema-constraints.html
        # But it (a) returns an array, and (b) throws a 404 if no constraint.
        # https://github.com/neo4j/neo4j/issues/4214
        # For those reasons, it's actually easier to just fetch all constraints;
        # no error handling needed, and array processing either way.
        #
        # NOTE: We explicitly *are* assuming uniqueness type here, since we
        # also would if we were querying for a specific constraint.
        # (The `/uniqueness` part of the path comes before the property.)
        #
        @http
            method: 'GET'
            path: "/db/data/schema/constraint\
                /#{encodeURIComponent label}/uniqueness"
        , (err, constraints) ->
            if err
                cb err
            else
                cb null, constraints.some (constraint) ->
                    constraint = Constraint._fromRaw constraint
                    constraint.label is label and
                        constraint.property is property

    createConstraint: (opts={}, cb) ->
        # TODO: We may need to support an additional `type` param too,
        # if any other types beyond uniqueness get added.
        {label, property} = opts

        if not (label and property)
            throw new TypeError \
                'Label and property required to create a constraint.'

        # NOTE: We explicitly *are* assuming uniqueness type here, since
        # that's our only option today for creating constraints.
        # NOTE: Passing `raw: true` so we can handle the 409 case below.
        @http
            method: 'POST'
            path: "/db/data/schema/constraint\
                /#{encodeURIComponent label}/uniqueness"
            body: {'property_keys': [property]}
            raw: true
        , (err, resp) ->
            if err
                return cb err

            # Neo4j returns a 409 error (w/ varying code across versions)
            # if this constraint already exists.
            if resp.statusCode is 409
                return cb null, null

            # Translate all other error responses as legitimate errors:
            if err = Error._fromResponse resp
                return cb err

            cb err, if resp.body then Constraint._fromRaw resp.body

    dropConstraint: (opts={}, cb) ->
        # TODO: We may need to support an additional `type` param too,
        # if any other types beyond uniqueness get added.
        {label, property} = opts

        if not (label and property)
            throw new TypeError \
                'Label and property required to drop a constraint.'

        # This endpoint is void, i.e. returns nothing:
        # http://neo4j.com/docs/stable/rest-api-schema-constraints.html#rest-api-drop-constraint
        # Passing `raw: true` so we can handle the 409 case below.
        @http
            method: 'DELETE'
            path: "/db/data/schema/constraint/#{encodeURIComponent label}\
                /uniqueness/#{encodeURIComponent property}"
            raw: true
        , (err, resp) ->
            if err
                return cb err

            # Neo4j returns a 404 response (with an empty body)
            # if this constraint doesn't exist (has already been dropped).
            if resp.statusCode is 404
                return cb null, false

            # Translate all other error responses as legitimate errors:
            if err = Error._fromResponse resp
                return cb err

            cb err, true    # Constraint existed and was dropped


    # TODO: Legacy indexing


## HELPERS

#
# Normalizes the given auth value, which can be a 'username:password' string
# or a {username, password} object, to an object or null always.
#
_normalizeAuth = (auth) ->
    # Support empty string for no auth:
    return null if not auth

    # Parse string if given, being robust to colons in the password:
    if typeof auth is 'string'
        [username, passwordParts...] = auth.split ':'
        password = passwordParts.join ':'
        auth = {username, password}

    # Support empty object for no auth also:
    return null if (Object.keys auth).length is 0

    auth

#
# Deep inspects the given object -- which could be a simple primitive, a map,
# an array with arbitrary other objects, etc. -- and transforms any objects that
# look like nodes and relationships into Node and Relationship instances.
# Returns the transformed object, and does not mutate the input object.
#
_transform = (obj) ->
    # Nothing to transform for primitives and null:
    if (not obj) or (typeof obj isnt 'object')
        return obj

    # Process arrays:
    # (NOTE: Not bothering to detect arrays made in other JS contexts.)
    if obj instanceof Array
        return obj.map _transform

    # Feature-detect (AKA "duck-type") Node & Relationship objects, by simply
    # trying to parse them as such.
    # Important: check relationships first, for precision/specificity.
    # TODO: If we add a Path class, we'll need to check for that here too.
    if rel = Relationship._fromRaw obj
        return rel
    if node = Node._fromRaw obj
        return node

    # Otherwise, process as a dictionary/map:
    map = {}
    for key, val of obj
        map[key] = _transform val
    map
