import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import lti/providers/http_provider.{type HttpProvider}
import lti/services/access_token.{type AccessToken, set_authorization_header}
import lti/services/nrps/membership.{type Membership}
import lti/utils.{json_decoder}
import lti_example_tool/utils/logger

pub const nrps_claim_url = "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice"

pub const context_membership_readonly_claim_url = "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"

pub fn fetch_memberships(
  http_provider: HttpProvider,
  context_memberships_url: String,
  access_token: AccessToken,
) -> Result(List(Membership), String) {
  logger.info("Fetching memberships from " <> context_memberships_url)

  use req <- result.try(
    request.to(context_memberships_url <> "?limit=1000")
    |> result.replace_error(
      "Error creating request for URL " <> context_memberships_url,
    ),
  )

  let req =
    req
    |> set_membership_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          let decoder = {
            use members <- decode.field(
              "members",
              decode.list(membership.decoder()),
            )

            decode.success(members)
          }

          use memberships <- result.try(
            json.decode(res.body, json_decoder(decoder))
            |> result.map_error(fn(e) {
              logger.error_meta("Error decoding memberships", e)

              "Error decoding memberships"
            }),
          )

          Ok(memberships)
        }
        _ -> Error("Unexpected status: " <> string.inspect(res))
      }

    e -> Error("Error fetching memberships: " <> string.inspect(e))
  }
}

/// Returns True if the NRPS service is available from the given launch claims.
pub fn nrps_available(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  case get_nrps_claim(lti_launch_claims) {
    Ok(_nrps_claim) -> True
    Error(_) -> False
  }
}

pub fn get_membership_service_url(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(String, String) {
  {
    use nrps_claim <- result.try(get_nrps_claim(lti_launch_claims))

    Ok(nrps_claim.context_memberships_url)
  }
}

type NrpsClaim {
  NrpsClaim(
    context_memberships_url: String,
    errors: Dict(String, Dynamic),
    validation_context: Option(Dynamic),
  )
}

fn get_nrps_claim(claims: Dict(String, Dynamic)) -> Result(NrpsClaim, String) {
  let nrps_claim_decoder = {
    use context_memberships_url <- decode.field(
      "context_memberships_url",
      decode.string,
    )
    use errors <- decode.field(
      "errors",
      decode.dict(decode.string, decode.dynamic),
    )
    use validation_context <- decode.field(
      "validation_context",
      decode.optional(decode.dynamic),
    )

    decode.success(NrpsClaim(
      context_memberships_url: context_memberships_url,
      errors: errors,
      validation_context: validation_context,
    ))
  }

  dict.get(claims, nrps_claim_url)
  |> result.replace_error("Missing LTI NRPS claim")
  |> result.then(fn(c) {
    decode.run(c, nrps_claim_decoder)
    |> result.replace_error("Invalid LTI NRPS claim")
  })
}

fn set_membership_headers(req: Request(String)) -> Request(String) {
  req
  |> request.set_header("Content-Type", "application/json")
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lti-nrps.v2.membershipcontainer+json",
  )
}
