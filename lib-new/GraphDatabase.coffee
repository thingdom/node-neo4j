$ = require 'underscore'
{Error} = require './errors'
lib = require '../package.json'
Node = require './Node'
Relationship = require './Relationship'
Request = require 'request'
URL = require 'url'
utils = require './utils'


module.exports = class GraphDatabase

    # Default HTTP headers:
    headers:
        'User-Agent': "node-neo4j/#{lib.version}"
        'X-Stream': 'true'

    constructor: (opts={}) ->
        if typeof opts is 'string'
            opts = {url: opts}

        {@url, @headers, @proxy} = opts

        if not @url
            throw new TypeError 'URL to Neo4j required'

        # TODO: Do we want to special-case User-Agent? Blacklist X-Stream?
        @headers or= {}
        $(@headers).defaults @constructor::headers

    http: (opts={}, cb) ->
        if typeof opts is 'string'
            opts = {path: opts}

        {method, path, headers, body, raw} = opts

        if not path
            throw new TypeError 'Path required'

        method or= 'GET'
        headers or= {}

        # TODO: Do we need to do anything special to support streaming response?
        req = Request
            method: method
            url: URL.resolve @url, path
            headers: $(headers).defaults @headers
            json: body ? true
        , (err, resp) =>

            if err
                # TODO: Do we want to wrap or modify native errors?
                return cb err

            if raw
                # TODO: Do we want to return our own Response object?
                return cb null, resp

            {body, headers, statusCode} = resp

            if err = Error._fromResponse resp
                return cb err

            cb null, _transform body

    cypher: (opts={}, cb) ->
        if typeof opts is 'string'
            opts = {query: opts}

        {query, params, headers, raw} = opts

        method = 'POST'
        path = '/db/data/transaction/commit'

        # NOTE: Lowercase 'rest' matters here for parsing.
        format = if raw then 'row' else 'rest'
        statements = []
        body = {statements}

        # TODO: Support batching multiple queries in this request?
        if query
            statements.push
                statement: query
                parameters: params or {}
                resultDataContents: [format]

        # TODO: Support streaming!
        @http {method, path, headers, body}, (err, body) =>

            if err
                # TODO: Do we want to wrap or modify native errors?
                # NOTE: This includes our own errors for non-2xx responses.
                return cb err

            {results, errors} = body

            if errors.length
                # TODO: Is it possible to get back more than one error?
                # If so, is it fine for us to just use the first one?
                [error] = errors
                return cb Error._fromTransaction error

            # If there are no results, it means no statements were sent
            # (e.g. to commit, rollback, or renew a transaction in isolation),
            # so nothing to return, i.e. a void call in that case.
            # Important: we explicitly don't return an empty array, because that
            # implies we *did* send a query, that just didn't match anything.
            if not results.length
                return cb null, null

            # The top-level `results` is an array of results corresponding to
            # the `statements` (queries) inputted.
            # We send only one statement/query, so we have only one result.
            [result] = results
            {columns, data} = result

            # The `data` is an array of result rows, but each of its elements is
            # actually a dictionary of results keyed by *response format*.
            # We only request one format, `rest` by default, `row` if `raw`.
            # In both cases, the value is an array of rows, where each row is an
            # array of column values.
            # We transform those rows into dictionaries keyed by column names.
            results = $(data).pluck(format).map (row) ->
                result = {}
                for column, i in columns
                    result[column] = row[i]
                result

            cb null, results


## HELPERS

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
