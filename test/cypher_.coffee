# we'll be creating a somewhat complex graph and testing that cypher queries
# on it return expected results.

assert = require 'assert'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# convenience wrapper:
createNode = (name) ->
    node = db.createNode {name}
    node.name = name
    node.toString = -> name
    node

# FOLLOWERS

# users: user0 thru user9
users = for i in [0..9]
    createNode "user#{i}"

# save in parallel
futures = (user.save() for user in users)
future _ for future in futures

# convenience aliases
user0 = users[0]
user1 = users[1]
user2 = users[2]
user3 = users[3]

# test: can query a single user
{columns, data} = db.query _, "start n=(#{user0.id}) return n"
assert.ok columns instanceof Array
assert.equal columns.length, 1
assert.equal columns[0], 'n'
assert.ok data instanceof Array
assert.equal data.length, 1
assert.ok data[0] instanceof Array
assert.equal data[0].length, 1
assert.equal typeof data[0][0], 'object'
assert.equal data[0][0].data.name, user0.name
