import { global, XHR_STATES } from "./constants";

type HttpMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
type Headers = Record<string, string>;
type RequestBody = string | null;
type AjaxCallback = (response: any) => void;
type TimeoutCallback = () => void;

interface XDomainRequest {
  timeout: number;
  open(method: string, url: string): void;
  send(body?: string | null): void;
  onload: (() => void) | null;
  ontimeout: (() => void) | null;
  onprogress: (() => void) | null;
  responseText: string;
}

interface XMLHttpRequestLike {
  open(method: string, url: string, async?: boolean): void;
  send(body?: string | null): void;
  setRequestHeader(name: string, value: string): void;
  timeout: number;
  readyState: number;
  responseText: string;
  onreadystatechange: ((ev?: any) => any) | null;
  onerror: (() => void) | null;
  ontimeout: (() => void) | null;
}

export default class Ajax {
  static request(
    method: HttpMethod,
    endPoint: string,
    headers: Headers,
    body: RequestBody,
    timeout: number,
    ontimeout: TimeoutCallback | null,
    callback: AjaxCallback | null,
  ): XMLHttpRequestLike | XDomainRequest | AbortController {
    if ((global as any).XDomainRequest) {
      const req = new (global as any).XDomainRequest(); // IE8, IE9
      return this.xdomainRequest(
        req,
        method,
        endPoint,
        body,
        timeout,
        ontimeout,
        callback,
      );
    } else if ((global as any).XMLHttpRequest) {
      const req = new (global as any).XMLHttpRequest(); // IE7+, Firefox, Chrome, Opera, Safari
      return this.xhrRequest(
        req,
        method,
        endPoint,
        headers,
        body,
        timeout,
        ontimeout,
        callback,
      );
    } else if (
      typeof global.fetch === "function" &&
      typeof global.AbortController === "function"
    ) {
      // Fetch with AbortController for modern browsers
      return this.fetchRequest(
        method,
        endPoint,
        headers,
        body,
        timeout,
        ontimeout,
        callback,
      );
    } else {
      throw new Error("No suitable XMLHttpRequest implementation found");
    }
  }

  static fetchRequest(
    method: HttpMethod,
    endPoint: string,
    headers: Headers,
    body: RequestBody,
    timeout: number,
    ontimeout: TimeoutCallback | null,
    callback: AjaxCallback | null,
  ): AbortController {
    const options: RequestInit = {
      method,
      headers,
      body,
    };
    const controller = new AbortController();
    if (timeout) {
      setTimeout(() => controller.abort(), timeout);
      options.signal = controller.signal;
    }
    global
      .fetch(endPoint, options)
      .then((response) => response.text())
      .then((data) => this.parseJSON(data))
      .then((data) => callback && callback(data))
      .catch((err) => {
        if (err.name === "AbortError" && ontimeout) {
          ontimeout();
        } else {
          callback && callback(null);
        }
      });
    return controller;
  }

  static xdomainRequest(
    req: XDomainRequest,
    method: HttpMethod,
    endPoint: string,
    body: RequestBody,
    timeout: number,
    ontimeout: TimeoutCallback | null,
    callback: AjaxCallback | null,
  ): XDomainRequest {
    req.timeout = timeout;
    req.open(method, endPoint);
    req.onload = () => {
      const response = this.parseJSON(req.responseText);
      callback && callback(response);
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }

    // Work around bug in IE9 that requires an attached onprogress handler
    req.onprogress = () => {};

    req.send(body);
    return req;
  }

  static xhrRequest(
    req: XMLHttpRequestLike,
    method: HttpMethod,
    endPoint: string,
    headers: Headers,
    body: RequestBody,
    timeout: number,
    ontimeout: TimeoutCallback | null,
    callback: AjaxCallback | null,
  ): XMLHttpRequestLike {
    req.open(method, endPoint, true);
    req.timeout = timeout;
    for (const [key, value] of Object.entries(headers)) {
      req.setRequestHeader(key, value);
    }
    req.onerror = () => callback && callback(null);
    req.onreadystatechange = () => {
      if (req.readyState === XHR_STATES.complete && callback) {
        const response = this.parseJSON(req.responseText);
        callback(response);
      }
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }

    req.send(body);
    return req;
  }

  static parseJSON(resp: string | null | undefined): any {
    if (!resp || resp === "") {
      return null;
    }

    try {
      return JSON.parse(resp);
    } catch {
      console && console.log("failed to parse JSON response", resp);
      return null;
    }
  }

  static serialize(obj: Record<string, any>, parentKey?: string): string {
    const queryStr: string[] = [];
    for (const key in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, key)) {
        continue;
      }
      const paramKey = parentKey ? `${parentKey}[${key}]` : key;
      const paramVal = obj[key];
      if (typeof paramVal === "object") {
        queryStr.push(this.serialize(paramVal, paramKey));
      } else {
        queryStr.push(
          encodeURIComponent(paramKey) + "=" + encodeURIComponent(paramVal),
        );
      }
    }
    return queryStr.join("&");
  }

  static appendParams(url: string, params: Record<string, any>): string {
    if (Object.keys(params).length === 0) {
      return url;
    }

    const prefix = url.match(/\?/) ? "&" : "?";
    return `${url}${prefix}${this.serialize(params)}`;
  }
}
