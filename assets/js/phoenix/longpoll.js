 import { SOCKET_STATES, TRANSPORTS } from "./constants";
import Ajax from "./ajax";

const arrayBufferToBase64 = (buffer) => {
  let binary = "";
  let bytes = new Uint8Array(buffer);
  for (let byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
};

export default class LongPoll {
  constructor(endPoint) {
    this.endPoint = null;
    this.token = null;
    this.skipHeartbeat = true;
    this.reqs = new Set();
    this.awaitingBatchAck = false;
    this.currentBatch = null;
    this.currentBatchTimer = null;
    this.batchBuffer = [];
    this.onopen = () => {}; // No-op
    this.onerror = () => {}; // No-op
    this.onmessage = () => {}; // No-op
    this.onclose = () => {}; // No-op
    this.onfeedback = (message) => console.info(message); // Feedback callback
    this.pollEndpoint = this.normalizeEndpoint(endPoint);
    this.readyState = SOCKET_STATES.connecting;

    // Start polling
    setTimeout(() => this.poll(), 0);
  }

  normalizeEndpoint(endPoint) {
    return endPoint
      .replace("ws://", "http://")
      .replace("wss://", "https://")
      .replace(
        new RegExp(`(.*)\/${TRANSPORTS.websocket}`),
        `$1/${TRANSPORTS.longpoll}`
      );
  }

  endpointURL() {
    return Ajax.appendParams(this.pollEndpoint, { token: this.token });
  }

  closeAndRetry(code, reason, wasClean) {
    this.onfeedback(`Closing connection: code=${code}, reason=${reason}`);
    this.close(code, reason, wasClean);
    this.readyState = SOCKET_STATES.connecting;
  }

  ontimeout() {
    this.onfeedback("Polling timeout occurred");
    this.onerror("timeout");
    this.closeAndRetry(1005, "timeout", false);
  }

  isActive() {
    return (
      this.readyState === SOCKET_STATES.open ||
      this.readyState === SOCKET_STATES.connecting
    );
  }

  poll() {
    this.onfeedback("Starting poll request...");
    this.ajax("GET", "application/json", null, () => this.ontimeout(), (resp) => {
      if (resp) {
        const { status, token, messages } = resp;
        this.token = token;
      } else {
        status = 0;
      }

      switch (status) {
        case 200:
          this.onfeedback("Messages received via polling");
          messages.forEach((msg) => {
            setTimeout(() => this.onmessage({ data: msg }), 0);
          });
          this.poll();
          break;
        case 204:
          this.onfeedback("No new messages; continuing to poll");
          this.poll();
          break;
        case 410:
          this.readyState = SOCKET_STATES.open;
          this.onfeedback("Polling upgraded to open state");
          this.onopen({});
          this.poll();
          break;
        case 403:
          this.onfeedback("Forbidden response received; closing connection");
          this.onerror(403);
          this.close(1008, "forbidden", false);
          break;
        case 0:
        case 500:
          this.onfeedback(
            `Server error (status ${status}); retrying connection`
          );
          this.onerror(500);
          this.closeAndRetry(1011, "internal server error", 500);
          break;
        default:
          throw new Error(`Unhandled poll status: ${status}`);
      }
    });
  }

  send(body) {
    if (typeof body !== "string") {
      body = arrayBufferToBase64(body);
    }
    if (this.currentBatch) {
      this.currentBatch.push(body);
    } else if (this.awaitingBatchAck) {
      this.batchBuffer.push(body);
    } else {
      this.currentBatch = [body];
      this.currentBatchTimer = setTimeout(() => {
        this.batchSend(this.currentBatch);
        this.currentBatch = null;
      }, 0);
    }
  }

  batchSend(messages) {
    this.onfeedback("Sending batch messages");
    this.awaitingBatchAck = true;
    this.ajax(
      "POST",
      "application/x-ndjson",
      messages.join("\n"),
      () => this.onerror("timeout"),
      (resp) => {
        this.awaitingBatchAck = false;
        if (!resp || resp.status !== 200) {
          this.onfeedback("Batch send failed");
          this.onerror(resp && resp.status);
          this.closeAndRetry(1011, "internal server error", false);
        } else {
          this.onfeedback("Batch send succeeded");
          if (this.batchBuffer.length > 0) {
            this.batchSend(this.batchBuffer);
            this.batchBuffer = [];
          }
        }
      }
    );
  }

  close(code, reason, wasClean) {
    this.onfeedback(`Connection closing: code=${code}, reason=${reason}`);
    for (let req of this.reqs) {
      req.abort();
    }
    this.readyState = SOCKET_STATES.closed;
    const opts = {
      code: 1000,
      reason: undefined,
      wasClean: true,
      ...{ code, reason, wasClean },
    };
    this.batchBuffer = [];
    clearTimeout(this.currentBatchTimer);
    this.currentBatchTimer = null;

    if (typeof CloseEvent !== "undefined") {
      this.onclose(new CloseEvent("close", opts));
    } else {
      this.onclose(opts);
    }
  }

  ajax(method, contentType, body, onCallerTimeout, callback) {
    let req;
    const ontimeout = () => {
      this.reqs.delete(req);
      onCallerTimeout();
    };
    req = Ajax.request(
      method,
      this.endpointURL(),
      contentType,
      body,
      this.timeout,
      ontimeout,
      (resp) => {
        this.reqs.delete(req);
        if (this.isActive()) {
          callback(resp);
        }
      }
    );
    this.reqs.add(req);
  }
}
