/**
 * @jest-environment jsdom
 * @jest-environment-options {"url": "http://example.com/"}
 */
import Ajax from "../js/phoenix/ajax"

describe("Ajax appendParams", function (){
  it("should return URL unchanged when params is empty", () => {
    const url = "ws://example.com/socket"

    const result = Ajax.appendParams(url, {})
    expect(result).toBe(url)
  })

  it("should use & when URL already has query params", () => {
    const url = "ws://example.com/socket?existing=param"
    const result = Ajax.appendParams(url, {
      new: "param",
    })
    expect(result).toBe("ws://example.com/socket?existing=param&new=param")
  })
})
