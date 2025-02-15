import { global, SOCKET_STATES, AUTH_TOKEN_PREFIX } from "./constants"

export default class Transport {
    constructor(url, options = {}) {
        this.url = url
        this.options = options
        // TODO: abstract websocket specifics (e.g. readyState)?
        this.readyState = SOCKET_STATES.connecting
        this.onopen = null
        this.onerror = null
        this.onmessage = null
        this.onclose = null
        this.authToken = options.authToken
    }

    static isTransport(transport) {
        return transport.prototype instanceof Transport
    }

    send(_data) {
        throw new Error("send() must be implemented by subclass")
    }

    close(_code, _reason) {
        throw new Error("close() must be implemented by subclass")
    }

    // Helper methods for subclasses to trigger events
    triggerOpen() {
        this.readyState = SOCKET_STATES.open
        if (this.onopen) this.onopen()
    }

    triggerError(error) {
        if (this.onerror) this.onerror(error)
    }

    triggerMessage(message) {
        if (this.onmessage) this.onmessage(message)
    }

    triggerClose(event) {
        this.readyState = SOCKET_STATES.closed
        if (this.onclose) this.onclose(event)
    }
}

export class WebSocketTransport extends Transport {
    constructor(url, options = {}) {
        super(url, options)
        
        // Handle WebSocket-specific protocol setup
        const subprotocols = ["phoenix"]
        if (this.authToken) {
            subprotocols.push(`${AUTH_TOKEN_PREFIX}${btoa(this.authToken).replace(/=/g, "")}`)
        }

        const WebSocket = options.WebSocket || global.WebSocket
        this.ws = new WebSocket(url, subprotocols)
        this.ws.binaryType = options.binaryType

        this.ws.onopen = () => this.triggerOpen()
        this.ws.onerror = (error) => this.triggerError(error)
        this.ws.onmessage = (event) => this.triggerMessage(event)
        this.ws.onclose = (event) => this.triggerClose(event)
    }

    send(data) {
        this.ws.send(data)
    }

    close(code, reason) {
        this.ws.close(code, reason)
    }
}

export class WrapperTransport {
    constructor(transport) {
        return class extends WebSocketTransport {
            constructor(url, options) {
                options.WebSocket = transport
                super(url, options)
            }
        }
    }
}
