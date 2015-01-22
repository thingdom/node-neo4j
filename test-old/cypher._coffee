# we'll be creating a somewhat complex graph and testing that cypher queries
# on it return expected results.

{expect} = require 'chai'
flows = require 'streamline/lib/util/flows'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# users: user0 thru user9
users = for i in [0..9]
    db.createNode
        name: "user#{i}"

# convenience aliases
user0 = users[0]
user1 = users[1]
user2 = users[2]
user3 = users[3]
user4 = users[4]
user5 = users[5]
user6 = users[6]
user7 = users[7]
user8 = users[8]
user9 = users[9]

@cypher =

    '(pre-req) save nodes': (_) ->
        # save in parallel
        flows.collect _,
            for user in users
                user.save not _

    'query single user': (_) ->
        results = db.query """
            START n=node(#{user0.id})
            RETURN n
        """, _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 1

        expect(results[0]).to.be.an 'object'
        expect(results[0]['n']).to.be.an 'object'
        expect(results[0]['n'].id).to.equal user0.id
        expect(results[0]['n'].data).to.eql user0.data

    'query multiple users': (_) ->
        results = db.query """
            START n=node(#{user0.id},#{user1.id},#{user2.id})
            RETURN n
            ORDER BY n.name
        """, _
        expect(results).to.be.an 'array'
        expect(results).to.have.length 3

        expect(results[1]).to.be.an 'object'
        expect(results[1]['n']).to.be.an 'object'
        expect(results[1]['n'].data).to.eql user1.data

    '(pre-req) create relationships': (_) ->
        # have user0 follow user1, user2 and user3
        # have user1 follow user2, user3 and user4
        # ...
        # have user8 follow user9, user0 and user1
        # have user9 follow user0, user1 and user2
        createFollowRelationships = (i, _) ->
            user = users[i]
            i1 = (i + 1) % users.length
            i2 = (i + 2) % users.length
            i3 = (i + 3) % users.length
            # create three relationships in parallel
            flows.collect _, [
                user.createRelationshipTo users[i1], 'follows', {}, not _
                user.createRelationshipTo users[i2], 'follows', {}, not _
                user.createRelationshipTo users[i3], 'follows', {}, not _
            ]

        # create follow relationships for each user in parallel
        # XXX parallelizing causes random Neo4j errors; TODO report!
        # until then, doing these in serial order...
        for user, i in users
            createFollowRelationships i, _

    'query relationships / return multiple values': (_) ->
        results = db.query """
            START n=node(#{user6.id})
            MATCH (n) -[r:follows]-> (m)
            RETURN r, m.name
            ORDER BY m.name
        """, _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 3

        expect(results[1]).to.be.an 'object'
        expect(results[1]['r']).to.be.an 'object'
        expect(results[1]['r'].type).to.eq 'follows'
        expect(results[1]['m.name']).to.equal user8.data.name

    'send query parameters instead of literals': (_) ->
        results = db.query '''
            START n=node({userId})
            MATCH (n) -[r:follows]-> (m)
            RETURN r, m.name
            ORDER BY m.name
        ''', {userId: user3.id}, _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 3

        expect(results[1]).to.be.an 'object'
        expect(results[1]['r']).to.be.an 'object'
        expect(results[1]['r'].type).to.eq 'follows'
        expect(results[1]['m.name']).to.equal user5.data.name

    'return collection/array of nodes': (_) ->
        results = db.query """
            START n=node(#{user0.id},#{user1.id},#{user2.id})
            RETURN collect(n)
        """, _

        expect(results).to.be.an 'array'
        expect(results).to.have.length 1

        expect(results[0]).to.be.an 'object'
        expect(results[0]['collect(n)']).to.be.an 'array'
        expect(results[0]['collect(n)']).to.have.length 3
        expect(results[0]['collect(n)'][1]).to.be.an 'object'
        expect(results[0]['collect(n)'][1].id).to.equal user1.id
        expect(results[0]['collect(n)'][1].data).to.eql user1.data

    'return paths': (_) ->
        results = db.query """
            START from=node({fromId}), to=node({toId})
            MATCH path=shortestPath(from -[:follows*..3]-> to)
            RETURN path
        """, {fromId: user0.id, toId: user6.id}, _

        # TODO Node and Rel instances in returned Path objects aren't necessarily
        # "filled", so we don't assert equality for those instances' data. it'd be
        # great if future versions of this library fixed that, but is it possible?

        expect(results).to.be.an 'array'
        expect(results).to.have.length 1

        expect(results[0]).to.be.an 'object'
        expect(results[0]['path']).to.be.an 'object'

        expect(results[0]['path'].start).to.be.an 'object'
        expect(results[0]['path'].start.id).to.equal user0.id
        # expect(results[0]['path'].start.data).to.eql user0.data

        expect(results[0]['path'].end).to.be.an 'object'
        expect(results[0]['path'].end.id).to.equal user6.id
        # expect(results[0]['path'].end.data).to.eql user6.data

        expect(results[0]['path'].nodes).to.be.an 'array'
        expect(results[0]['path'].nodes).to.have.length 3
        expect(results[0]['path'].nodes[1]).to.be.an 'object'
        expect(results[0]['path'].nodes[1].id).to.equal user3.id
        # expect(results[0]['path'].nodes[1].data).to.eql user3.data

        expect(results[0]['path'].relationships).to.be.an 'array'
        expect(results[0]['path'].relationships).to.have.length 2
        expect(results[0]['path'].relationships[1]).to.be.an 'object'
        # expect(results[0]['path'].relationships[1].type).to.eq 'follows'
