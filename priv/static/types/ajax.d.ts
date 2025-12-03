export default class Ajax {
    static request(method: any, endPoint: any, headers: any, body: any, timeout: any, ontimeout: any, callback: any): any;
    static fetchRequest(method: any, endPoint: any, headers: any, body: any, timeout: any, ontimeout: any, callback: any): AbortController | null;
    static xdomainRequest(req: any, method: any, endPoint: any, body: any, timeout: any, ontimeout: any, callback: any): any;
    static xhrRequest(req: any, method: any, endPoint: any, headers: any, body: any, timeout: any, ontimeout: any, callback: any): any;
    static parseJSON(resp: any): any;
    static serialize(obj: any, parentKey: any): any;
    static appendParams(url: any, params: any): any;
}
//# sourceMappingURL=ajax.d.ts.map