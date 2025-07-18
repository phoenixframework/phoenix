/**
 * @jest-environment node
 */

import { TextEncoder, TextDecoder } from "util";
import { Serializer } from "../js/phoenix";
import { Message } from "../js/phoenix/serializer";

const exampleMsg: Message = {
  join_ref: "0",
  ref: "1",
  topic: "t",
  event: "e",
  payload: { foo: 1 },
};

const binPayload = (): ArrayBuffer => {
  const buffer = new ArrayBuffer(1);
  new DataView(buffer).setUint8(0, 1);
  return buffer;
};

describe("JSON", () => {
  it("encodes general pushes", (done) => {
    Serializer.encode(exampleMsg, (result) => {
      expect(result).toBe('["0","1","t","e",{"foo":1}]');
      done();
    });
  });

  it("decodes", (done) => {
    Serializer.decode('["0","1","t","e",{"foo":1}]', (result) => {
      expect(result).toEqual(exampleMsg);
      done();
    });
  });
});

describe("binary", () => {
  it("encodes", (done) => {
    const buffer = binPayload();
    const bin = "\0\x01\x01\x01\x0101te\x01";
    const decoder = new TextDecoder();
    Serializer.encode(
      { join_ref: "0", ref: "1", topic: "t", event: "e", payload: buffer },
      (result) => {
        expect(decoder.decode(result as ArrayBuffer)).toBe(bin);
        done();
      },
    );
  });

  it("encodes variable length segments", (done) => {
    const buffer = binPayload();
    const bin = "\0\x02\x01\x03\x02101topev\x01";
    const decoder = new TextDecoder();
    Serializer.encode(
      { join_ref: "10", ref: "1", topic: "top", event: "ev", payload: buffer },
      (result) => {
        expect(decoder.decode(result as ArrayBuffer)).toBe(bin);
        done();
      },
    );
  });

  it("decodes push", (done) => {
    const bin = "\0\x03\x03\n123topsome-event\x01\x01";
    const buffer = new TextEncoder().encode(bin).buffer;
    const decoder = new TextDecoder();
    Serializer.decode(buffer, (result) => {
      expect(result.join_ref).toBe("123");
      expect(result.ref).toBeNull();
      expect(result.topic).toBe("top");
      expect(result.event).toBe("some-event");
      expect(result.payload.constructor).toBe(ArrayBuffer);
      expect(decoder.decode(result.payload as ArrayBuffer)).toBe("\x01\x01");
      done();
    });
  });

  it("decodes reply", (done) => {
    const bin = "\x01\x03\x02\x03\x0210012topok\x01\x01";
    const buffer = new TextEncoder().encode(bin).buffer;
    const decoder = new TextDecoder();
    Serializer.decode(buffer, (result) => {
      expect(result.join_ref).toBe("100");
      expect(result.ref).toBe("12");
      expect(result.topic).toBe("top");
      expect(result.event).toBe("phx_reply");
      expect((result.payload as any).status).toBe("ok");
      expect((result.payload as any).response.constructor).toBe(ArrayBuffer);
      expect(decoder.decode((result.payload as any).response)).toBe("\x01\x01");
      done();
    });
  });

  it("decodes broadcast", (done) => {
    const bin = "\x02\x03\ntopsome-event\x01\x01";
    const buffer = new TextEncoder().encode(bin).buffer;
    const decoder = new TextDecoder();
    Serializer.decode(buffer, (result) => {
      expect(result.join_ref).toBeNull();
      expect(result.ref).toBeNull();
      expect(result.topic).toBe("top");
      expect(result.event).toBe("some-event");
      expect(result.payload.constructor).toBe(ArrayBuffer);
      expect(decoder.decode(result.payload as ArrayBuffer)).toBe("\x01\x01");
      done();
    });
  });
});
