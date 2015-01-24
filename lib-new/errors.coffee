$ = require 'underscore'

class @Error extends Error

    Object.defineProperties @::,
        name: {get: -> 'neo4j.' + @constructor.name}

    constructor: (@message='Unknown error', {@http, @neo4j}={}) ->
        Error.captureStackTrace @, @constructor

    # TODO: Helper to rethrow native/inner errors? Not sure if we need one.

class @ClientError extends @Error

class @DatabaseError extends @Error

class @TransientError extends @Error
