(function() {
  var URL, USER_AGENT, flatten, lib, request, transform, unflatten,
    __slice = [].slice;

  lib = require('../package.json');

  request = require('request');

  URL = require('url');

  USER_AGENT = "node-neo4j/" + lib.version;

  exports.wrapRequest = function(_arg) {
    var auth, modifyArgs, proxy, req, url, verb, wrapper, _fn, _i, _len, _ref;
    url = _arg.url, proxy = _arg.proxy;
    req = request.defaults({
      json: true,
      proxy: proxy
    });
    auth = URL.parse(url).auth;
    modifyArgs = function(args) {
      var arg, opts;
      arg = args[0];
      opts = typeof arg === 'string' ? {
        url: arg
      } : arg;
      url = opts.url || opts.uri;
      url = URL.parse(url);
      if (url.auth !== auth) {
        url.host = "" + auth + "@" + url.host;
      }
      url = URL.format(url);
      opts.url = opts.uri = url;
      opts.headers || (opts.headers = {});
      opts.headers['User-Agent'] = USER_AGENT;
      opts.headers['X-Stream'] = true;
      args[0] = opts;
      return args;
    };
    wrapper = {};
    _ref = ['get', 'post', 'put', 'del', 'head'];
    _fn = function(verb) {
      return wrapper[verb] = function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return req[verb].apply(req, modifyArgs(args));
      };
    };
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      verb = _ref[_i];
      _fn(verb);
    }
    return wrapper;
  };

  exports.adjustError = function(error) {
    var serverError;
    if (error.statusCode) {
      serverError = error.body || {
        message: 'Unknown Neo4j error.'
      };
      if (typeof serverError === 'string') {
        try {
          serverError = JSON.parse(serverError);
        } catch (_error) {}
      }
      error = new Error;
      error.message = serverError.message || serverError;
    }
    if (typeof error !== 'object') {
      error = new Error(error);
    }
    if (error.code === 'ECONNREFUSED') {
      error.message = "Couldn't reach database (connection refused)";
    }
    return error;
  };

  exports.transform = transform = function(val, db) {
    var Node, Path, Relationship, end, hasProps, key, length, map, nodes, relationships, start, subval;
    if (!val || typeof val !== 'object') {
      return val;
    }
    if (val instanceof Array) {
      return val.map(function(val) {
        return transform(val, db);
      });
    }
    Path = require('./Path');
    Node = require('./Node');
    Relationship = require('./Relationship');
    hasProps = function(props) {
      var key, keys, type, _i, _len, _ref;
      for (type in props) {
        keys = props[type];
        _ref = keys.split('|');
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          key = _ref[_i];
          if (typeof val[key] !== type) {
            return false;
          }
        }
      }
      return true;
    };
    if (hasProps({
      string: 'self|traverse',
      object: 'data'
    })) {
      return new Node(db, val);
    }
    if (hasProps({
      string: 'self|type|start|end',
      object: 'data'
    })) {
      return new Relationship(db, val);
    }
    if (hasProps({
      string: 'start|end',
      number: 'length',
      object: 'nodes|relationships'
    })) {
      start = new Node(db, {
        self: val.start
      });
      end = new Node(db, {
        self: val.end
      });
      length = val.length;
      nodes = val.nodes.map(function(url) {
        return new Node(db, {
          self: url
        });
      });
      relationships = val.relationships.map(function(url) {
        return new Relationship(db, {
          self: url
        });
      });
      return new Path(start, end, length, nodes, relationships);
    } else {
      map = {};
      for (key in val) {
        subval = val[key];
        map[key] = transform(subval, db);
      }
      return map;
    }
  };

  exports.serialize = function(o, separator) {
    return JSON.stringify(flatten(o, separator));
  };

  exports.deserialize = function(o, separator) {
    return unflatten(JSON.parse(o), separator);
  };

  flatten = function(o, separator, result, prefix) {
    var key, value, _i, _len, _ref;
    separator = separator || '.';
    result = result || {};
    prefix = prefix || '';
    if (typeof o !== 'object') {
      return o;
    }
    _ref = Object.keys(o);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      key = _ref[_i];
      value = o[key];
      if (typeof value !== 'object') {
        result[prefix + key] = value;
      } else {
        flatten(value, separator, result, key + separator);
      }
    }
    return result;
  };

  unflatten = function(o, separator, result) {
    var currentKey, i, key, keys, lastKey, numKeys, separatorIndex, target, value, _i, _j, _len, _ref, _ref1;
    separator = separator || '.';
    result = result || {};
    if (typeof o !== 'object') {
      return o;
    }
    _ref = Object.keys(o);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      key = _ref[_i];
      value = o[key];
      separatorIndex = key.indexOf(separator);
      if (separatorIndex === -1) {
        result[key] = value;
      } else {
        keys = key.split(separator);
        target = result;
        numKeys = keys.length;
        for (i = _j = 0, _ref1 = numKeys - 2; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; i = 0 <= _ref1 ? ++_j : --_j) {
          currentKey = keys[i];
          if (target[currentKey] === void 0) {
            target[currentKey] = {};
          }
          target = target[currentKey];
        }
        lastKey = keys[numKeys - 1];
        target[lastKey] = value;
      }
    }
    return result;
  };

}).call(this);
