#
# NOTE: This file is within a directory named `fixtures`, rather than a file
# named `fixtures._coffee`, in order to not have Mocha treat it like a test.
#

neo4j = require '../../'

exports.DB =
    new neo4j.GraphDatabase process.env.NEO4J_URL or 'http://localhost:7474'

exports.TEST_LABEL = 'Test'

exports.TEST_REL_TYPE = 'TEST'
