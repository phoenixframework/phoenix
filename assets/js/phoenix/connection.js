import {SOCKET_STATES} from "./constants"

/**
 * @private
 *
 * A connection of the socket over a single transport instance.
 *
 * It owns everything that belongs to this connection, so that nothing about it can
 * affect a later connection: the transport events are only handled while it is the
 * socket's current connection, and its state is gone together with it.
 */
export default class Connection {
  /**
   * @param {Socket} socket
   * @param {Object} transport - The transport instance, for example a WebSocket
   */
  constructor(socket, transport){
    this.socket = socket
    this.transport = transport
    // the join ref of each channel whose join was sent over this connection, weakly held
    // as a connection can outlive many channels, e.g. when navigating between LiveViews
    this.joins = new WeakMap()
    // the callbacks of the pings sent over this connection by ref, as their replies can only
    // arrive over it, so they are gone together with it instead of accumulating on the socket
    this.pings = new Map()
    // set when we close the connection, as opposed to the server or the network
    this.closing = false
    // set when the socket does not want this connection anymore, e.g. on disconnect,
    // so that connecting again creates a new one instead of waiting for it
    this.ended = false
    // set once the channels were errored after the connection stopped being open
    this.channelsErrored = false
    // set once the close event was handled, as LongPoll can emit it more than once
    this.closeHandled = false
    transport.onopen = () => { if(this.isCurrent()){ socket.onConnOpen() } }
    transport.onerror = error => { if(this.isCurrent()){ socket.onConnError(error) } }
    transport.onmessage = event => { if(this.isCurrent()){ socket.onConnMessage(event) } }
    transport.onclose = event => {
      if(this.isCurrent() && !this.closeHandled){
        this.closeHandled = true
        socket.onConnClose(event)
      }
    }
  }

  /**
   * Whether this is the connection the socket currently uses. A replaced connection
   * can still emit events while it closes, but they no longer concern the socket.
   */
  isCurrent(){ return this.socket.connection === this }

  isOpen(){ return this.transport.readyState === SOCKET_STATES.open }

  isConnecting(){ return this.transport.readyState === SOCKET_STATES.connecting }

  /**
   * Whether the channel's current join was sent over this connection.
   */
  carried(channel, joinRef = channel.joinRef()){
    return this.joins.has(channel) && this.joins.get(channel) === joinRef
  }

  /**
   * Closes the transport. Its close event then only confirms our close.
   */
  close(code, reason){
    this.closing = true
    // closing a transport that is still connecting makes it emit an error, which is
    // caused by closing it and must not be handled as a transport error
    this.transport.onerror = function (){ } // noop
    if(code){ this.transport.close(code, reason || "") } else { this.transport.close() }
  }
}
