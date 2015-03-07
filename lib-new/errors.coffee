$ = require 'underscore'
http = require 'http'

class @Error extends Error

    constructor: (@message='Unknown error', @neo4j={}) ->
        @name = 'neo4j.' + @constructor.name
        Error.captureStackTrace @, @constructor

    #
    # Accepts the given HTTP client response, and if it represents an error,
    # creates and returns the appropriate Error instance from it.
    # If the response doesn't represent an error, returns null.
    #
    @_fromResponse: (resp) ->
        {body, headers, statusCode} = resp

        return null if statusCode < 400

        # TODO: Do some status codes (or perhaps inner `exception` names)
        # signify Transient errors rather than Database ones?
        ErrorType = if statusCode >= 500 then 'Database' else 'Client'
        ErrorClass = exports["#{ErrorType}Error"]

        message = "#{statusCode} "
        logBody = statusCode >= 500     # TODO: Config to always log body?

        if body?.exception
            message += "[#{body.exception}] #{body.message or '(no message)'}"
        else
            statusText = http.STATUS_CODES[statusCode]  # E.g. "Not Found"
            reqText = "#{resp.req.method} #{resp.req.path}"
            message += "#{statusText} response for #{reqText}"
            logBody = true  # always log body if non-error returned

        if logBody and body?
            message += ": #{JSON.stringify body, null, 4}"

        new ErrorClass message, body

    #
    # Accepts the given error object from a transactional Cypher response, and
    # creates and returns the appropriate Error instance for it.
    #
    @_fromTransaction: (obj) ->
        # http://neo4j.com/docs/stable/rest-api-transactional.html#rest-api-handling-errors
        # http://neo4j.com/docs/stable/status-codes.html
        {code, message, stackTrace} = obj
        [neo, classification, category, title] = code.split '.'

        ErrorClass = exports[classification]    # e.g. DatabaseError

        # Prefix all messages with the full semantic code, for at-a-glance-ness:
        fullMessage = "[#{code}] "

        # If this is a database error with a Java stack trace from Neo4j,
        # include that stack, for bug reporting to the Neo4j team.
        # Also include the stack if there's no summary message.
        # TODO: Should we make it configurable to always include it?
        # NOTE: The stack seems to be returned as a string, not an array.
        if stackTrace and (classification is 'DatabaseError' or not message)
            # It seems that this stack trace includes the summary message,
            # but checking just in case it doesn't, and adding it if so.
            if message and (stackTrace.indexOf message) is -1
                stackTrace = "#{message}: #{stackTrace}"

            # Stack traces can include "Caused by" lines which aren't indented,
            # and indented lines use tabs. Normalize to 4 spaces, and indent
            # everything one extra level, to differentiate from Node.js lines.
            stackTrace = stackTrace
                .replace /\t/g, '    '
                .replace /\n/g, '\n    '

            fullMessage += stackTrace

        # Otherwise, e.g. for client errors, omit any stack; just the message:
        else
            fullMessage += message

        new ErrorClass fullMessage, obj

    # TODO: Helper to rethrow native/inner errors? Not sure if we need one.

class @ClientError extends @Error

class @DatabaseError extends @Error

class @TransientError extends @Error
