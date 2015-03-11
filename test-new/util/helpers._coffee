#
# NOTE: This file is within a `util` subdirectory, rather than within the
# top-level `test` directory, in order to not have Mocha treat it like a test.
#

{expect} = require 'chai'
neo4j = require '../../'


#
# Helper used by all the below methods that covers all specific error cases.
# Asserts that the given error at least adheres to our base Error contract.
#
@_expectBaseError = (err, classification) ->
    expect(err).to.be.an.instanceOf neo4j[classification]   # e.g. DatabaseError
    expect(err.name).to.equal "neo4j.#{classification}"

    expect(err.message).to.be.a 'string'
    expect(err.stack).to.be.a 'string'
    expect(err.stack).to.contain '\n'

    # NOTE: Chai doesn't have `beginsWith`, so approximating:
    stackPrefix = "#{err.name}: #{err.message}"
    expect(err.stack.slice 0, stackPrefix.length).to.equal stackPrefix


#
# Asserts that the given object is an instance of the appropriate Neo4j Error
# subclass, representing the given *new-style* Neo4j v2 error info.
#
@expectError = (err, classification, category, title, message) =>
    code = "Neo.#{classification}.#{category}.#{title}"

    @_expectBaseError err, classification

    # If the actual error message is multi-line, it includes the Neo4j stack
    # trace; test that in a simple way by just checking the first line of the
    # trace (subsequent lines can be different, e.g. "Caused by"), but also test
    # that the first line of the message matches the expected message:
    [errMessageLine1, errMessageLine2, ...] = err.message.split '\n'
    expect(errMessageLine1).to.equal "[#{code}] #{message}"
    expect(errMessageLine2).to.match ///
        ^ \s+ at\ [^(]+ \( [^)]+ [.](java|scala):\d+ \)
    /// if errMessageLine2

    expect(err.neo4j).to.be.an 'object'
    expect(err.neo4j.code).to.equal code

    # If the actual error message was multi-line, that means it was the Neo4j
    # stack trace, which can include a larger message than the returned one.
    if errMessageLine2
        expect(err.neo4j.message).to.be.a 'string'
        expect(message).to.contain err.neo4j.message
    else
        expect(err.neo4j.message).to.equal message


#
# Asserts that the given object is an instance of the appropriate Neo4j Error
# subclass, representing the given *old-style* Neo4j v1 error info.
#
# NOTE: This assumes this error is returned from an HTTP response.
#
@expectOldError = (err, statusCode, shortName, longName, message) ->
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
# Asserts that the given object is an instance of the appropriate Neo4j Error
# subclass, with the given raw message.
#
# NOTE: This assumes no details info was returned by Neo4j.
#
@expectRawError = (err, classification, message) =>
    @_expectBaseError err, classification
    expect(err.message).to.equal message
    expect(err.neo4j).to.be.empty()     # TODO: Should this really be the case?


#
# TEMP: Neo4j 2.2.0-RC01 incorrectly classifies `ParameterMissing` errors as
# `DatabaseError` rather than `ClientError`:
# https://github.com/neo4j/neo4j/issues/4144
#
# Returns whether we did have to account for this bug or not.
#
@expectParameterMissingError = (err) =>
    try
        @expectError err, 'ClientError', 'Statement', 'ParameterMissing',
            'Expected a parameter named foo'
        return false

    catch assertionErr
        # Check for the Neo4j 2.2.0-RC01 case, but if it's not,
        # throw the original assertion error, not a new one.
        try
            @expectError err, 'DatabaseError', 'Statement', 'ExecutionFailure',
                'org.neo4j.graphdb.QueryExecutionException:
                    Expected a parameter named foo'
            return true

        throw assertionErr


#
# Returns a random string.
#
@getRandomStr = ->
    "#{Math.random()}"[2..]
