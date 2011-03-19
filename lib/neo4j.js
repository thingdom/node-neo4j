//////////////////////////////////////////////////////////////////////////////
//
//  Neo4j REST client for Node.js
//
//  Copyright 2011 Daniel Gasienica <daniel@gasienica.ch>
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may
//  not use this file except in compliance with the License. You may obtain
//  a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations
//  under the License.
//
//////////////////////////////////////////////////////////////////////////////

var http = require('http');
var qs = require('querystring');

var Neo4jClient = exports = module.exports = function Neo4jClient(host, port, basePath) {
    this.host = host || 'localhost';
    this.port = port || 7474;
    this.basePath = basePath || '/db/data';
};

Neo4jClient.prototype.getRoot = function (callback) {
    var options = {
        method: 'GET'
    };
    this.request('/', options, jsonBodyHandler(callback));
};

Neo4jClient.prototype.getNode = function (id, callback) {
    var options = {
        method: 'GET'
    };
    this.request('/node/' + id + '/properties', options, jsonBodyHandler(callback));
};

Neo4jClient.prototype.createNode = function (data, callback) {
    var options = {
        method: 'POST',
        data: data ? JSON.stringify(data) : data
    };
    this.request('/node', options,
        function(err, res) {
            var error;
            if (err) {
                callback(err, null);
            } else if (res.statusCode !== 201) {
                error = createErrorFromResponse(res);
                switch(res.statusCode) {
                    case 400:
                        error.message = 'Invalid data sent.';
                        break;
                }
                callback(error, null);
            } else {
                var location = res.headers['location'];
                callback(null, location);
            }
        }
    );
};

Neo4jClient.prototype.updateNode = function (id, data, callback) {
    var options = {
        method: 'PUT',
        data: JSON.stringify(data)
    };
    this.request('/node/' + id + '/properties', options,
        function(err, res) {
            var error;
            if (err) {
                callback(err);
            } else if (res.statusCode !== 204) {
                error = createErrorFromResponse(res);
                switch(res.statusCode) {
                    case 400:
                        error.message = 'Invalid data sent.';
                        break;
                    case 404:
                        error.message = 'Node not found';
                        break;
                    default:
                        break;
                }
                callback(error);
            } else {
                callback(null);
            }
        }
    );
};

Neo4jClient.prototype.deleteNode = function (id, callback) {
    var options = {
        method: 'DELETE'
    };
    this.request('/node/' + id, options,
        function(err, res) {
            var error;
            if (err) {
                callback(err);
            } else if (res.statusCode !== 204) {
                error = createErrorFromResponse(res);
                switch(res.statusCode) {
                    case 404:
                        error.message = 'Node not found';
                        break;
                    case 409:
                        error.message = 'Node could not be deleted (still has relationships?)';
                        break;
                    default:
                        break;
                }
                callback(error);
            } else {
                callback(null);
            }
        }
    );
};

Neo4jClient.prototype.request = function (path, options, callback) {
    var path = path || '/';

    var options = options || {};
    var method = options.method || 'GET';
    var data = options.data || null;
    var params = options.params || null;

    // normalize path to begin with a slash
    if (path.charAt(0) !== '/') {
        path = '/' + path;
    }

    // add base path
    path = this.basePath + path;

    // attach query string parameters
    if (params) {
        var separator = '?';
        if (path.indexOf('?') !== -1) {
            separator = '&';
        }
        path += separator + qs.stringify(params);
    }

    var requestOptions = {
        host: this.host,
        port: this.port,
        method: method,
        path: path,
        headers: {
            'Accept': 'application/json'
        }
    };

    if (data) {
        requestOptions.headers['Content-Type'] = 'application/json';
    }

    var request = http.request(requestOptions, function (res) {
        res.setEncoding('utf8');
        var body = '';
        res.on('data', function (chunk) {
            body += chunk;
        });
        res.on('end', function () {
            res.body = body
            callback(null, res);
        });
    });

    request.on('error', function (err) {
        callback(error, null);
    });

    if (data) {
        request.write(data);
    }

    request.end();
};


function createErrorFromResponse(response) {
    var error = {
        statusCode: response.statusCode,
        headers: response.headers
    };
    return error;
}

function jsonBodyHandler(callback) {
    return function(err, res) {
        var error = null;
        if (err) {
            callback(err, null);
        } else if (res.statusCode !== 200) {
            error = createErrorFromResponse(res);
            callback(error, null);
        } else {
            var data;
            try {
                data = JSON.parse(res.body);
            } catch(e) {
                error = new Error('Failed to parse JSON.');
                error.innerError = e;
            }
            if (error) {
                callback(error, null);
            } else {
                callback(null, data);
            }
        }
    };
}
