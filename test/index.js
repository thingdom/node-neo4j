var assert = require('assert');
var neo4j = require('../lib/neo4j');
var sys = require('sys');

// database
var DB_HOST = 'localhost';
var DB_PORT = 7474;
var db = new neo4j.Client(DB_HOST, DB_PORT, true);

// data
var data = {
    name: 'Daniel Gasienica',
    magicNumber: 42,
    lovesIceCream: true
};
var newData = {
    name: 'Daniel Gasienica',
    father: {
        firstName: 'Jan',
        lastName: 'Gasienica'
    },
    tired: false
};

// test create, get, update, delete
db.createNode(data, function(err, res) {
    if (err) {
        console.log('Error: Failed to create node');
    } else {
        var id = getNodeId(res);
        db.getNode(id, function (err, res) {
            if (err) {
                console.log('Error: Failed to get node %d (%s)',
                    id, JSON.stringify(err));
            } else {
                assert.deepEqual(res, data,
                        'Retrieved data does not match original data.');
                db.updateNode(id, newData, function (err, res) {
                    assert.ifError(err);
                    db.getNode(id, function (err, res) {
                        assert.deepEqual(res, newData,
                            'Retrieved data does not match updated data.');
                        db.deleteNode(id, function (err, res) {
                            if (err) {
                                console.log('Error: Failed to delete node %d (%s)',
                                    id, JSON.stringify(err));
                            } else {
                                db.getNode(id, function (err, res) {
                                    assert.strictEqual(res, null, 'Result not null.');
                                    assert.strictEqual(err.statusCode, 404,
                                            'Found node even though it was deleted.');
                                })
                            }
                        });
                    });
                });
            }
        });
    }
});

// helper
function print(error, result) {
    console.log(error ? error : (result ? result : ''));
};

function getNodeId(url) {
    var NODE_REGEX = /node\/(\d+)/g;
    var match = NODE_REGEX.exec(url);
    return match ? parseInt(match[1]) : null;
}
