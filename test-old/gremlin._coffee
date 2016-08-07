# will be used for testing gremlin script executions
# as well as validating the return results are as expected.

{expect} = require 'chai'
flows = require 'streamline/lib/util/flows'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# UPDATE: the gremlin plugin no longer ships with Neo4j 2.0,
# so we check for its presence first before running the tests.
# TODO: can we do this without these tests showing up at all?
# can't figure out a way with Mocha, since the check is async.
AVAILABLE = true
UNAVAILABLE_MSG = 'Gremlin plugin not available; not running Gremlin tests.'

# create some nodes
users = for i in [0..6]
    db.createNode
        name: "gremlinTest#{i}"

# convenience aliases
user0 = users[0]
user1 = users[1]
user2 = users[2]
user3 = users[3]
user4 = users[4]
user5 = users[5]
user6 = users[6]

@gremlin =

    '(pre-req) check availability': (_) ->
        {extensions} = db.getServices _
        AVAILABLE = extensions?['GremlinPlugin']?

    '(pre-req) save nodes': (_) ->
        # save in parallel
        flows.collect _,
            for user in users
                user.save not _

    'query single user, using param': (_) ->
        result = db.execute """
            g.v(userId)
        """, {userId: user0.id}, _

        expect(result).to.be.an 'object'
        expect(result.id).to.equal user0.id
        expect(result.data).to.eql user0.data

    '(pre-req) create relationships': (_) ->
        createFollowRelationships = (i, _) ->
            user = users[i]
            i1 = (i + 1) % users.length
            i2 = (i + 2) % users.length
            i3 = (i + 3) % users.length
            flows.collect _, [
                user.createRelationshipTo users[i1], 'gremlin_follows', {}, not _
                user.createRelationshipTo users[i2], 'gremlin_follows', {}, not _
                user.createRelationshipTo users[i3], 'gremlin_follows', {}, not _
            ]

        # create follow relationships for each user in parallel
        # XXX parallelizing causes random Neo4j errors; TODO report!
        # until then, doing these in serial order...
        for user, i in users
            createFollowRelationships i, _

    # TODO test returning relationships too, not just connected nodes

    'query connected nodes': (_) ->
        rels = db.execute """
            g.v(#{user0.id}).in('gremlin_follows')
        """, {}, _

        expect(rels).to.be.an 'array'
        expect(rels).to.have.length 3
        expect(rels[1]).to.be.an 'object'
        # order isn't specified/guaranteed; TODO can we specify it?
        expect([user4.id, user5.id, user6.id]).to.contain rels[1].id

    'return multiple types': (_) ->
        traversals = db.execute """
            g.v(#{user0.id}).transform{ [it, it.out.toList(), it.in.count()] }
        """, {}, _

        expect(traversals).to.be.an 'array'
        expect(traversals).to.have.length 1

        expect(traversals[0]).to.be.an 'array'
        expect(traversals[0]).to.have.length 3

        expect(traversals[0][0]).to.be.an 'object'
        expect(traversals[0][0].id).to.equal user0.id
        expect(traversals[0][0].data).to.eql user0.data
        expect(traversals[0][1]).to.be.an 'array'
        expect(traversals[0][1]).to.have.length 3
        expect(traversals[0][1][1]).to.be.an 'object'
        # order isn't specified/guaranteed again; TODO can we specify it?
        expect([user1.id, user2.id, user3.id]).to.contain traversals[0][1][1].id
        expect(traversals[0][2]).to.equal 3

    'query without params arg': (_) ->
        params_test = db.execute """
            g.v(#{user0.id})
        """, _

        expect(params_test).to.be.an 'object'
        expect(params_test.id).to.equal user0.id
        expect(params_test.data).to.eql user0.data

# wrap every test to check if the gremlin plugin is available:
# (remember to wrap loop body in closure, since tests are async!)
for name, test of @gremlin
    do (name, test) =>
        @gremlin[name] = (_) ->
            if AVAILABLE
                test _
            else
                console.log UNAVAILABLE_MSG
