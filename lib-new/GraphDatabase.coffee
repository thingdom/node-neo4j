$ = require 'underscore'
errors = require './errors'
lib = require '../package.json'
Node = require './Node'
Relationship = require './Relationship'
Request = require 'request'
URL = require 'url'

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

            if statusCode >= 500
                # TODO: Parse errors, and differentiate w/ TransientErrors.
                err = new errors.DatabaseError 'TODO',
                    http: {body, headers, statusCode}
                return cb err

            if statusCode >= 400
                # TODO: Parse errors.
                err = new errors.ClientError 'TODO',
                    http: {body, headers, statusCode}
                return cb err

            # Parse nodes and relationships in the body, and return:
            return cb null, _transform body


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
