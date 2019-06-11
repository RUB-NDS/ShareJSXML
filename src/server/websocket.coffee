# This implements the WebSocket network API for ShareJS.
EventEmitter = require('events').EventEmitter
WebSocketServer = require('ws').Server

sessionHandler = require('./session').handler

wrapSession = (conn) ->
  wrapper = new EventEmitter
  wrapper.abort = -> conn.close()
  wrapper.stop = -> conn.close()
  wrapper.send = (response) ->
    conn.send JSON.stringify response if wrapper.ready()
  wrapper.ready = -> conn.readyState is 1
  conn.on 'message', (data) ->
    try
      parsed = JSON.parse data
      wrapper.emit 'message', parsed
    catch error
      console.log "Received data parsing error #{error}"
  conn.on 'connection', (ws, req) ->
    ws.upgradeReq = req

  wrapper.headers = conn.upgradeReq.headers
  # TODO - I don't think this is the right way to get the address
  wrapper.address = conn._socket.server._connectionKey?
  wrapper

exports.attach = (server, createAgent, options) ->
  options.prefix or= '/websocket'
  wss = new WebSocketServer {server: server, path: options.prefix}
  wss.on 'connection', (conn, req) ->
    conn.upgradeReq = req
    sessionHandler wrapSession(conn), createAgent
