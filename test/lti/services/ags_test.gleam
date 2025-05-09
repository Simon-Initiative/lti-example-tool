import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response
import gleeunit/should
import lti/providers/http_mock_provider
import lti/services/access_token.{AccessToken}
import lti/services/ags
import lti/services/ags/line_item.{LineItem}
import lti/services/ags/score.{Score}

pub fn post_score_test() {
  let expect_http_post = fn(req: Request(String)) {
    req.path
    |> should.equal("/lineitem/123/scores")

    req.method
    |> should.equal(http.Post)

    response.new(200)
    |> response.set_body("{}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_post)

  let score =
    Score(
      score_given: 1.0,
      score_maximum: 2.0,
      timestamp: "2023-10-01T00:00:00Z",
      user_id: "user123",
      comment: "Great job!",
      activity_progress: "Completed",
      grading_progress: "Graded",
    )

  let line_item =
    LineItem(
      id: "https://example.edu/lineitem/123",
      score_maximum: 2.0,
      label: "Test Line Item",
      resource_id: "resource123",
    )

  let access_token =
    AccessToken(
      access_token: "SOME_ACCESS_TOKEN",
      token_type: "Bearer",
      expires_in: 3600,
      scope: "some scopes",
    )

  ags.post_score(http_provider, score, line_item, access_token)
  |> should.be_ok()
}
