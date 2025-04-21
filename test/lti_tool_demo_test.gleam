import gleam/list
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import lti/providers/memory_provider
import lti_tool_demo/app_context.{AppContext}
import lti_tool_demo/database
import lti_tool_demo/router
import lti_tool_demo/session
import wisp/testing

pub fn main() {
  gleeunit.main()
}

fn app_context() {
  let assert Ok(session_config) = session.init()

  let assert Ok(lti_data_provider) = memory_provider.start()

  AppContext(
    port: 8080,
    secret_key_base: "secret_key_base",
    db: database.connect("lti_tool_demo_test"),
    static_directory: "static_directory",
    session_config: session_config,
    lti_data_provider: lti_data_provider,
  )
}

pub fn get_home_page_test() {
  let request = testing.get("/", [])
  let response = router.handle_request(request, app_context())

  response.status
  |> should.equal(200)

  response.headers
  |> list.contains(#("content-type", "text/html; charset=utf-8"))
  |> should.be_true

  response.headers
  |> list.contains(#("made-with", "Gleam"))
  |> should.be_true

  response.headers
  |> list.find(fn(header) {
    case header {
      #("set-cookie", _) -> True
      _ -> False
    }
  })
  |> result.map(fn(header) {
    case header {
      #("set-cookie", cookie) -> {
        {
          string.contains(cookie, "SESSION_COOKIE=")
          && string.contains(
            cookie,
            "Max-Age=3599; Path=/; Secure; HttpOnly; SameSite=Lax",
          )
        }
        |> should.be_true
      }
      _ -> Nil
    }
  })
  |> should.be_ok

  response
  |> testing.string_body
  |> should.equal("Hello, Joe!")
}

pub fn post_home_page_test() {
  let request = testing.post("/", [], "a body")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(405)
}

pub fn page_not_found_test() {
  let request = testing.get("/nothing-here", [])
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(404)
}

pub fn get_comments_test() {
  let request = testing.get("/comments", [])
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(200)
}

pub fn post_comments_test() {
  let request = testing.post("/comments", [], "")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(201)
}

pub fn delete_comments_test() {
  let request = testing.delete("/comments", [], "")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(405)
}

pub fn get_comment_test() {
  let request = testing.get("/comments/123", [])
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(200)
  response
  |> testing.string_body
  |> should.equal("Comment with id 123")
}

pub fn delete_comment_test() {
  let request = testing.delete("/comments/123", [], "")
  let response = router.handle_request(request, app_context())
  response.status
  |> should.equal(405)
}
