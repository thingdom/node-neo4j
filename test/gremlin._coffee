# will be used for testing gremlin script executions
# as well as validating the return results are as expected

assert = require('assert')
neo4j = require('..')

db = new neo4j.GraphDatabase 'http://localhost:7474'

# convenience wrapper
createNode = (name) ->
	node = db.createNode {name}
	node.name = name
	node.toString = -> name
	node

#create some nodes
users = for i in [0..6]
	createNode "gremlinTest#{i}"

# save in parallel
futures = (user.save() for user in users)
future _ for future in futures

# convenience aliases
user0 = users[0]
user1 = users[1]
user2 = users[2]
user3 = users[3]
user4 = users[4]
user5 = users[5]
user6 = users[6]

# test: can query a single user
results = db.execute """
	g.v(#{user0.id})
""", {}, _

assert.ok typeof results, 'object'
assert.ok typeof results.data.name, 'string' # dislike this because it will throw for the wrong reasons possibly 
assert.equal results.data.name, user0.name

# test: create relationships between users (same as cypher tests), then query by relationships
createFollowRelationships = (i, _) ->
	user = users[i]
	i1 = (i + 1) % users.length
	i2 = (i + 2) % users.length
	i3 = (i + 3) % users.length
	f1 = user.createRelationshipTo users[i1], 'gremlin_follows', {}
	f2 = user.createRelationshipTo users[i2], 'gremlin_follows', {}
	f3 = user.createRelationshipTo users[i3], 'gremlin_follows', {}
	f1 _
	f2 _
	f3 _

# create follow relationships for each user in parallel
futures = (createFollowRelationships(i) for user, i in users)
future _ for future in futures

relationships = db.execute """
	g.v(#{user0.id}).in('gremlin_follows')
""", {} , _

# above is working, but lib should support returning instances of Node and Relationship if possible


# handle multiple types of data return
traversals = db.execute """
	g.v(#{user0.id}).transform{ [it, it.out.toList(), it.in.count()] }
""", {}, _

assert.ok traversals instanceof Array
assert.equal traversals.length, 1

assert.ok traversals[0] instanceof Array
assert.equal traversals[0].length, 3

assert.ok typeof traversals[0][0], 'object'
assert.ok traversals[0][1] instanceof Array
assert.ok typeof traversals[0][2], 'number'


# ensure you can call without params

params_test = db.execute """
	g.v(#{user0.id})
""", _

assert.ok typeof params_test, 'object'
assert.equal params_test.data.name, user0.name

# Should be relatively clear at this point the .execute() function is working with gremlin on some level
console.log 'Passed initial Gremlin tests'