// crud_.js
// Test cases for creating, reading, updating and deleting nodes and edges.
// Written in Streamline.js syntax: https://github.com/Sage/streamlinejs

var assert = require('assert');
var db = require('./setup');

// DATA

var data = {
    name: 'Daniel Gasienica',
    magicNumber: 42,
    lovesIceCream: true,
};

var newData = {
    name: 'Daniel Gasienica',
    father: {
        firstName: 'Jan',
        lastName: 'Gasienica'
    },
    tired: false,
};

// HELPERS

function getNodeId(url) {
    var NODE_REGEX = /node\/(\d+)/g;
    var match = NODE_REGEX.exec(url);
    return match ? parseInt(match[1]) : null;
}

// TEST CRUD (create, read, update, delete)

module.exports = function (beforeExit, _) {     // _ arg req'd by Streamline
    
    // don't bother try-catching; we want errors to propogate.
    // note that createNode() returns a string url, whereas getNode() returns a data object!
    // TODO createNode() should return a data object too; update this test in that case.
    var url1 = db.createNode(data, _);
    var id = getNodeId(url1);
    
    var res2 = db.getNode(id, _);
    assert.deepEqual(res2, data, 'Retrieved data does not match original data.');
    
    var res3 = db.updateNode(id, newData, _);
    var res4 = db.getNode(id, _);
    assert.deepEqual(res4, newData, 'Retrieved data does not match updated data.');
    
    db.deleteNode(id, _);
    
    try {
        db.getNode(id, _);
        assert.fail('Found node even though it was deleted.');
    } catch (err) {
        assert.strictEqual(err.statusCode, 404, 'Nonexistent node returned non-404 error.');
    }

};
