import {
  global,
  XHR_STATES
} from "./constants"

export default class Ajax {

  static request(method, endPoint, headers, body, timeout, ontimeout, callback){
    if(global.XDomainRequest){
      let req = new global.XDomainRequest() // IE8, IE9
      return this.xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback)
    } else if(global.XMLHttpRequest){
      let req = new global.XMLHttpRequest() // IE7+, Firefox, Chrome, Opera, Safari
      return this.xhrRequest(req, method, endPoint, headers, body, timeout, ontimeout, callback)
    } else if(global.fetch && global.AbortController){
      // Fetch with AbortController for modern browsers
      return this.fetchRequest(method, endPoint, headers, body, timeout, ontimeout, callback)
    } else {
      throw new Error("No suitable XMLHttpRequest implementation found")
    }
  }

  static fetchRequest(method, endPoint, headers, body, timeout, ontimeout, callback){
    let options = {
      method,
      headers,
      body,
    }
    let controller = null
    if(timeout){
      controller = new AbortController()
      const _timeoutId = setTimeout(() => controller.abort(), timeout)
      options.signal = controller.signal
    }
    global.fetch(endPoint, options)
      .then(response => response.text())
      .then(data => this.parseJSON(data))
      .then(data => callback && callback(data))
      .catch(err => {
        if(err.name === "AbortError" && ontimeout){
          ontimeout()
        } else {
          callback && callback(null)
        }
      })
    return controller
  }

  static xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback){
    req.timeout = timeout
    req.open(method, endPoint)
    req.onload = () => {
      let response = this.parseJSON(req.responseText)
      callback && callback(response)
    }
    if(ontimeout){ req.ontimeout = ontimeout }

    // Work around bug in IE9 that requires an attached onprogress handler
    req.onprogress = () => { }

    req.send(body)
    return req
  }

  static xhrRequest(req, method, endPoint, headers, body, timeout, ontimeout, callback){
    req.open(method, endPoint, true)
    req.timeout = timeout
    for(let [key, value] of Object.entries(headers)){
      req.setRequestHeader(key, value)
    }
    req.onerror = () => callback && callback(null)
    req.onreadystatechange = () => {
      if(req.readyState === XHR_STATES.complete && callback){
        let response = this.parseJSON(req.responseText)
        callback(response)
      }
    }
    if(ontimeout){ req.ontimeout = ontimeout }

    req.send(body)
    return req
  }

  static parseJSON(resp){
    if(!resp || resp === ""){ return null }

    try {
      return JSON.parse(resp)
    } catch {
      console && console.log("failed to parse JSON response", resp)
      return null
    }
  }

  static serialize(obj, parentKey){
    let queryStr = []
    for(var key in obj){
      if(!Object.prototype.hasOwnProperty.call(obj, key)){ continue }
      let paramKey = parentKey ? `${parentKey}[${key}]` : key
      let paramVal = obj[key]
      if(typeof paramVal === "object"){
        queryStr.push(this.serialize(paramVal, paramKey))
      } else {
        queryStr.push(encodeURIComponent(paramKey) + "=" + encodeURIComponent(paramVal))
      }
    }
    return queryStr.join("&")
  }

  static appendParams(url, params){
    if(Object.keys(params).length === 0){ return url }

    let prefix = url.match(/\?/) ? "&" : "?"
    return `${url}${prefix}${this.serialize(params)}`
  }
}
