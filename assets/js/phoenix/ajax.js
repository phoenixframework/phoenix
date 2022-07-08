import {
  global,
  XHR_STATES
} from "./constants"

export default class Ajax {

  static request(method, endPoint, accept, body, timeout, ontimeout, callback){
    if(global.XDomainRequest){
      let req = new global.XDomainRequest() // IE8, IE9
      return this.xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback)
    } else {
      let req = new global.XMLHttpRequest() // IE7+, Firefox, Chrome, Opera, Safari
      return this.xhrRequest(req, method, endPoint, accept, body, timeout, ontimeout, callback)
    }
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

  static xhrRequest(req, method, endPoint, accept, body, timeout, ontimeout, callback){
    req.open(method, endPoint, true)
    req.timeout = timeout
    req.setRequestHeader("Content-Type", accept)
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
    } catch (e){
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
