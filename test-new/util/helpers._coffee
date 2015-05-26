#
# NOTE: This file is within a `util` subdirectory, rather than within the
# top-level `test` directory, in order to not have Mocha treat it like a test.
#

{expect} = require 'chai'
http = require 'http'
neo4j = require '../../'


#
# Chai doesn't have a `beginsWith` assertion, so this approximates that:
# Asserts that the given string begins with the given prefix.
#
@expectPrefix = (str, prefix) ->
    expect(str).to.be.a 'string'
    expect(str.slice 0, prefix.length).to.equal prefix


#
# Helper used by all the below methods that covers all specific error cases.
# Asserts that the given error at least adheres to our base Error contract.
#
@_expectBaseError = (err, classification) =>
    expect(err).to.be.an.instanceOf neo4j[classification]   # e.g. DatabaseError
    expect(err.name).to.equal "neo4j.#{classification}"

    expect(err.message).to.be.a 'string'
    expect(err.stack).to.be.a 'string'
    expect(err.stack).to.contain '\n'

    @expectPrefix err.stack, "#{err.name}: #{err.message}"


#
# Asserts that the given object is an instance of the appropriate Neo4j Error
# subclass, representing the given *new-style* Neo4j v2 error info.
#
@expectError = (err, classification, category, title, message) =>
    code = "Neo.#{classification}.#{category}.#{title}"
    codePlusMessage = "[#{code}] #{message}"

    @_expectBaseError err, classification

    expect(err.neo4j).to.be.an 'object'
    expect(err.neo4j.code).to.equal code

    # Neo4j can return its own Java stack trace, which changes our logic.
    # So check for the simpler case first, then short-circuit:
    if not err.neo4j.stackTrace
        expect(err.message).to.equal codePlusMessage
        expect(err.neo4j.message).to.equal message
        return

    # Otherwise, we construct our own stack trace from the Neo4j stack trace,
    # by setting our message to the Neo4j stack trace.
    # Neo4j stack traces can have messages with slightly more detail than the
    # returned `message` property, so we test that via "contains".
    expect(err.neo4j.stackTrace).to.be.a 'string'
    expect(err.neo4j.message).to.be.a 'string'
    expect(message).to.contain err.neo4j.message

    # Finally, we test that our returned message indeed includes the Neo4j stack
    # trace, after the expected message part (which can be multi-line).
    # We test just the first line of the stack trace for simplicity.
    # (Subsequent lines can be different, e.g. "Caused by ...").
    @expectPrefix err.message, codePlusMessage
    [errMessageStackLine1, ...] =
        (err.message.slice 0, codePlusMessage.length).split '\n'
    [neo4jStackTraceLine1, ...] = err.neo4j.stackTrace.split '\n'
    expect(errMessageStackLine1).to.contain neo4jStackTraceLine1.trim()


#
# Asserts that the given object is an instance of the appropriate Neo4j Error
# subclass, representing the given *old-style* Neo4j v1 error info.
#
# NOTE: This assumes this error is returned from an HTTP response.
#
@expectOldError = (err, statusCode, shortName, longName, message) =>
    ErrorType = if statusCode >= 500 then 'Database' else 'Client'
    @_expectBaseError err, "#{ErrorType}Error"

    expect(err.message).to.equal "#{statusCode} [#{shortName}] #{message}"

    expect(err.neo4j).to.be.an 'object'
    expect(err.neo4j).to.contain
        exception: shortName
        fullname: longName
        message: message

    expect(err.neo4j.stacktrace).to.be.an 'array'
    expect(err.neo4j.stacktrace).to.not.be.empty()
    for line in err.neo4j.stacktrace
        expect(line).to.be.a 'string'
        expect(line).to.not.be.empty()


#
# Asserts that the given object is an instance of the appropriat Neo4j Error
# subclass, with the given raw message (which can be a fuzzy regex too).
#
# NOTE: This assumes no details info was returned by Neo4j.
#
@expectRawError = (err, classification, message) =>
    @_expectBaseError err, classification

    if typeof message is 'string'
        expect(err.message).to.equal message
    else if message instanceof RegExp
        expect(err.message).to.match message
    else
        throw new Error "Unrecognized type of expected `message`:
            #{typeof message} / #{message?.constructor.name}"

    expect(err.neo4j).to.be.empty()     # TODO: Should this really be the case?


#
# Asserts that the given object is a simple HTTP error for the given response
# status code, e.g. 404 or 501.
#
@expectHttpError = (err, statusCode) =>
    ErrorType = if statusCode >= 500 then 'Database' else 'Client'
    statusText = http.STATUS_CODES[statusCode]  # E.g. "Not Found"

    @expectRawError err, "#{ErrorType}Error", ///
        ^ #{statusCode}\ #{statusText}\ response\ for\ [A-Z]+\ /.* $
    ///


#
# Returns a random string.
#
@getRandomStr = ->
    "#{Math.random()}"[2..]
