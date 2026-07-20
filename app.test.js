const request = require("supertest");
const app = require("./app");

describe("GET /", () => {
  test("should return Hello, Node is running!", async () => {
    const response = await request(app).get("/");

    expect(response.statusCode).toBe(200);
    expect(response.text).toBe("Hello, Node is running!");
  });
});