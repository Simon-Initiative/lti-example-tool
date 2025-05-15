import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/list
import gleeunit/should
import lti/providers/http_mock_provider
import lti/services/access_token.{AccessToken}
import lti/services/nrps
import lti/services/nrps/membership.{Membership}

pub fn fetch_memberships_test() {
  let expect_http_post = fn(req: Request(String)) {
    req.scheme
    |> should.equal(http.Https)

    req.host
    |> should.equal("lms.example.com")

    req.path
    |> should.equal("/lti/courses/350/names_and_roles")

    req.method
    |> should.equal(http.Get)

    response.new(200)
    |> response.set_body(
      "{
      \"members\": [
        {
          \"user_id\": \"12345\",
          \"status\": \"active\",
          \"name\": \"John Doe\",
          \"given_name\": \"John\",
          \"family_name\": \"Doe\",
          \"email\": \"john.doe@example.edu\",
          \"roles\": [\"Instructor\"],
          \"picture\": \"https://example.edu/john_doe.jpg\"
        },
        {
          \"user_id\": \"67890\",
          \"status\": \"active\",
          \"name\": \"Jane Smith\",
          \"given_name\": \"Jane\",
          \"family_name\": \"Smith\",
          \"email\": \"jane.smith@example.edu\",
          \"picture\": \"https://example.edu/jane_smith.jpg\",
          \"roles\": [\"Learner\"]
        }
      ]
    }",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_post)

  let context_memberships_url =
    "https://lms.example.com/lti/courses/350/names_and_roles"

  let access_token =
    AccessToken(
      access_token: "SOME_ACCESS_TOKEN",
      token_type: "Bearer",
      expires_in: 3600,
      scope: "some scopes",
    )

  let result =
    nrps.fetch_memberships(http_provider, context_memberships_url, access_token)

  result
  |> should.be_ok()

  let assert Ok(memberships) = result

  memberships
  |> list.find(fn(m) { m.user_id == "12345" })
  |> should.equal(
    Ok(Membership(
      user_id: "12345",
      status: "active",
      name: "John Doe",
      given_name: "John",
      family_name: "Doe",
      email: "john.doe@example.edu",
      roles: ["Instructor"],
      picture: "https://example.edu/john_doe.jpg",
    )),
  )

  memberships
  |> list.find(fn(m) { m.user_id == "67890" })
  |> should.equal(
    Ok(Membership(
      user_id: "67890",
      status: "active",
      name: "Jane Smith",
      given_name: "Jane",
      family_name: "Smith",
      email: "jane.smith@example.edu",
      roles: ["Learner"],
      picture: "https://example.edu/jane_smith.jpg",
    )),
  )
}
