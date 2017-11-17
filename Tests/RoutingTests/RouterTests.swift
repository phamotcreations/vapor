import Async
import HTTP
import Bits
import Routing
import XCTest

class RouterTests: XCTestCase {
    func testRouter() throws {
        let router = TrieRouter()
        
        XCTAssertEqual(["path", "to", "hello/world"].makePathComponents().count, 4)

        router.on(.get, to: ["hello", "world"].makePathComponents()) { req -> Response in
            return try Response(body: "hello")
        }

        router.on(.get, to: ["foo", "bar", "baz"].makePathComponents()) { req -> Response in
            return try Response(body: "foo")
        }

        router.on(.get, to: ["users", User.parameter, "comments"].makePathComponents()) { req -> Future<Response> in
            return req.parameters.next(User.self).map { bob in
                XCTAssertEqual(bob.name, "bob")
                return try Response(body: "users!")
            }
        }

        do {
            let request = Request(method: .get, uri: URI(path: "/foo/bar/baz"))
            let responder = router.route(request: request)

            XCTAssertNotNil(responder)
            
            let res = try responder?.respond(to: request).blockingAwait()
            
            res?.body.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: res!.body.count)
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "foo")
            }
        }

        do {
            let request = Request(method: .get, uri: URI(path: "/hello/world"))
            let responder = router.route(request: request)

            XCTAssertNotNil(responder)
            
            let res = try responder?.respond(to: request).blockingAwait()
            res?.body.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: res!.body.count)
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "hello")
            }
        }

        do {
            let request = Request(method: .get, uri: URI(path: "/users/bob/comments"))
            let responder = router.route(request: request)

            XCTAssertNotNil(responder)
            
            let res = try responder?.respond(to: request).blockingAwait()
            res?.body.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: res!.body.count)
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "users!")
            }
        }
    }


    static let allTests = [
        ("testRouter", testRouter),
    ]
}

extension Response: FutureType {
    public typealias Expectation = Response
}

final class User: Parameter {
    static let uniqueSlug: String = "user"
    var name: String

    init(name: String) {
        self.name = name
    }

    static func make(for parameter: String, in request: Request) throws -> Future<User> {
        return Future(User(name: parameter))
    }
}
