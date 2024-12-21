 import { global, XHR_STATES } from "./constants";

export default class Ajax {
  static activeRequests = new Map(); // Store active requests with unique IDs

  static request(id, method, endPoint, accept, body, timeout, ontimeout, callback) {
    if (global.XDomainRequest) {
      let req = new global.XDomainRequest(); // IE8, IE9
      this.activeRequests.set(id, req);
      return this.xdomainRequest(req, id, method, endPoint, body, timeout, ontimeout, callback);
    } else {
      let req = new global.XMLHttpRequest(); // IE7+, Firefox, Chrome, Opera, Safari
      this.activeRequests.set(id, req);
      return this.xhrRequest(req, id, method, endPoint, accept, body, timeout, ontimeout, callback);
    }
  }

  static xdomainRequest(req, id, method, endPoint, body, timeout, ontimeout, callback) {
    req.timeout = timeout;
    req.open(method, endPoint);
    req.onload = () => {
      let response = this.parseJSON(req.responseText);
      callback && callback(response);
      this.activeRequests.delete(id); // Remove the request after completion
    };
    if (ontimeout) {
      req.ontimeout = () => {
        ontimeout();
        this.activeRequests.delete(id);
      };
    }

    req.onprogress = () => {}; // Workaround for IE9 bug
    req.send(body);
    return req;
  }

  static xhrRequest(req, id, method, endPoint, accept, body, timeout, ontimeout, callback) {
    req.open(method, endPoint, true);
    req.timeout = timeout;
    req.setRequestHeader("Content-Type", accept);
    req.onerror = () => {
      callback && callback(null);
      this.activeRequests.delete(id);
    };
    req.onreadystatechange = () => {
      if (req.readyState === XHR_STATES.complete && callback) {
        let response = this.parseJSON(req.responseText);
        callback(response);
        this.activeRequests.delete(id);
      }
    };
    if (ontimeout) {
      req.ontimeout = () => {
        ontimeout();
        this.activeRequests.delete(id);
      };
    }

    req.send(body);
    return req;
  }

  static cancelRequest(id) {
    let req = this.activeRequests.get(id);
    if (req) {
      req.abort();
      this.activeRequests.delete(id);
      console.log(`Request with ID ${id} has been canceled.`);
    }
  }

  static parseJSON(resp) {
    if (!resp || resp === "") {
      return null;
    }
    try {
      return JSON.parse(resp);
    } catch (e) {
      console && console.log("Failed to parse JSON response", resp);
      return null;
    }
  }

  static serialize(obj, parentKey) {
    let queryStr = [];
    for (var key in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, key)) {
        continue;
      }
      let paramKey = parentKey ? `${parentKey}[${key}]` : key;
      let paramVal = obj[key];
      if (typeof paramVal === "object") {
        queryStr.push(this.serialize(paramVal, paramKey));
      } else {
        queryStr.push(encodeURIComponent(paramKey) + "=" + encodeURIComponent(paramVal));
      }
    }
    return queryStr.join("&");
  }

  static appendParams(url, params) {
    if (Object.keys(params).length === 0) {
      return url;
    }

    let prefix = url.match(/\?/) ? "&" : "?";
    return `${url}${prefix}${this.serialize(params)}`;
  }
}
